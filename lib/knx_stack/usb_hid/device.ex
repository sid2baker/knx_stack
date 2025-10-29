defmodule KNXStack.USBHID.Device do
  @moduledoc """
  GenServer for managing KNX USB HID device connections.

  This module handles the lifecycle of a KNX USB HID device connection, including:
  - Opening and closing the HID device file
  - Continuously reading frames from the device
  - Decoding frames and dispatching to handler callbacks
  - Writing frames to the device

  ## Usage

      defmodule MyHandler do
        use KNXStack.USBHID.Handler

        def handle_frame(payload, state) do
          IO.inspect(payload, label: "KNX Frame")
          {:noreply, state}
        end
      end

      # Start the device connection
      {:ok, pid} = KNXStack.USBHID.Device.start_link(
        handler: MyHandler,
        device: "/dev/hidraw0"
      )

      # Send a frame (from anywhere)
      KNXStack.USBHID.Device.send_frame(pid, <<0x29, 0x00, 0xBC>>)

      # Stop the connection
      KNXStack.USBHID.Device.stop(pid)

  ## Options

  - `:handler` (required) - Module implementing the `KNXStack.USBHID.Handler` behavior
  - `:device` (required) - Path to HID device (e.g., "/dev/hidraw0")
  - `:handler_opts` - Keyword list passed to handler's `init/1` callback
  - `:name` - Registered name for the GenServer (optional)
  - `:read_size` - Number of bytes to read per HID report (default: 64)

  ## Architecture

  The Device GenServer spawns a separate reader process to avoid blocking on I/O.
  The reader continuously reads from the device file and sends messages back to
  the GenServer, which then decodes frames and invokes handler callbacks.

  This design ensures the GenServer remains responsive for send operations and
  other messages while waiting for incoming data.
  """

  use GenServer
  require Logger
  alias KNXStack.USBHID

  @default_read_size 64

  defmodule State do
    @moduledoc false
    defstruct [
      :device_path,
      :device_file,
      :handler_module,
      :handler_state,
      :reader_pid,
      :reader_ref,
      :read_size
    ]

    @type t :: %__MODULE__{
            device_path: String.t(),
            device_file: IO.device() | nil,
            handler_module: module(),
            handler_state: term(),
            reader_pid: pid() | nil,
            reader_ref: reference() | nil,
            read_size: pos_integer()
          }
  end

  # Client API

  @doc """
  Starts a KNX USB HID device connection.

  ## Options

  - `:handler` (required) - Handler module implementing `KNXStack.USBHID.Handler`
  - `:device` (required) - Path to HID device file
  - `:handler_opts` - Options passed to handler's `init/1` (default: `[]`)
  - `:name` - Registered name for the GenServer
  - `:read_size` - Bytes per HID report (default: 64)

  ## Examples

      {:ok, pid} = KNXStack.USBHID.Device.start_link(
        handler: MyHandler,
        device: "/dev/hidraw0"
      )

      {:ok, pid} = KNXStack.USBHID.Device.start_link(
        handler: MyHandler,
        device: "/dev/hidraw0",
        handler_opts: [log_frames: true],
        name: MyKNXDevice
      )
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    {gen_opts, device_opts} = Keyword.split(opts, [:name])
    GenServer.start_link(__MODULE__, device_opts, gen_opts)
  end

  @doc """
  Sends a KNX frame to the bus.

  The payload is encoded using the USB HID protocol and written to the device.

  ## Parameters

  - `device` - Device GenServer pid or registered name
  - `payload` - Raw KNX message payload (binary)
  - `opts` - Encoding options (passed to `KNXStack.USBHID.encode/2`)

  ## Examples

      KNXStack.USBHID.Device.send_frame(pid, <<0x29, 0x00, 0xBC, 0xE0>>)
  """
  @spec send_frame(GenServer.server(), binary()) :: :ok
  def send_frame(device, payload) do
    send_frame(device, payload, [])
  end

  @spec send_frame(GenServer.server(), binary(), keyword()) :: :ok
  def send_frame(device, payload, opts) do
    GenServer.cast(device, {:send_frame, payload, opts})
  end

  @doc """
  Stops the device connection gracefully.

  ## Examples

      KNXStack.USBHID.Device.stop(pid)
  """
  @spec stop(GenServer.server()) :: :ok
  def stop(device) do
    GenServer.stop(device, :normal)
  end

  # Server callbacks

  @impl true
  def init(opts) do
    handler_module = Keyword.fetch!(opts, :handler)
    device_path = Keyword.fetch!(opts, :device)
    handler_opts = Keyword.get(opts, :handler_opts, [])
    read_size = Keyword.get(opts, :read_size, @default_read_size)

    # Initialize handler state
    case handler_module.init(handler_opts) do
      {:ok, handler_state} ->
        state = %State{
          device_path: device_path,
          handler_module: handler_module,
          handler_state: handler_state,
          read_size: read_size
        }

        # Open device and start reader in init to catch early errors
        {:ok, state, {:continue, :connect}}

      {:stop, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_continue(:connect, state) do
    case open_device(state.device_path) do
      {:ok, device_file} ->
        # Notify handler of connection
        device_info = %{
          path: state.device_path,
          vendor_id: nil,
          product_id: nil
        }

        state = %{state | device_file: device_file}

        case invoke_handler(:handle_connected, [device_info, state.handler_state], state) do
          {:ok, new_state} ->
            # Start reader process
            reader_pid = spawn_reader(self(), device_file, state.read_size)
            reader_ref = Process.monitor(reader_pid)

            new_state = %{new_state | reader_pid: reader_pid, reader_ref: reader_ref}
            {:noreply, new_state}

          {:stop, reason, new_state} ->
            close_device(device_file)
            {:stop, reason, new_state}
        end

      {:error, reason} ->
        Logger.error("Failed to open device #{state.device_path}: #{inspect(reason)}")
        {:stop, {:device_open_failed, reason}, state}
    end
  end

  @impl true
  def handle_cast({:send_frame, payload, opts}, state) do
    case write_frame(state.device_file, payload, opts) do
      :ok ->
        {:noreply, state}

      {:error, reason} ->
        Logger.error("Failed to write frame: #{inspect(reason)}")
        handle_disconnection(reason, state)
    end
  end

  @impl true
  def handle_info({:frame_data, data}, state) do
    case USBHID.extract_payload(data) do
      {:ok, payload} ->
        case invoke_handler(:handle_frame, [payload, state.handler_state], state) do
          {:ok, new_state} ->
            {:noreply, new_state}

          {:reply, reply_payload, new_state} ->
            write_frame(new_state.device_file, reply_payload, [])
            {:noreply, new_state}

          {:stop, reason, new_state} ->
            {:stop, reason, new_state}
        end

      {:error, reason} ->
        Logger.warning("Failed to decode frame: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:reader_error, reason}, state) do
    Logger.error("Reader process error: #{inspect(reason)}")
    handle_disconnection(reason, state)
  end

  @impl true
  def handle_info({:DOWN, ref, :process, pid, reason}, %State{reader_ref: ref, reader_pid: pid} = state) do
    Logger.error("Reader process died: #{inspect(reason)}")
    handle_disconnection({:reader_died, reason}, state)
  end

  @impl true
  def terminate(reason, state) do
    # Stop reader if running
    if state.reader_pid do
      Process.exit(state.reader_pid, :shutdown)
    end

    # Close device file
    if state.device_file do
      close_device(state.device_file)
    end

    # Notify handler
    state.handler_module.terminate(reason, state.handler_state)
  end

  # Private functions

  defp open_device(device_path) do
    File.open(device_path, [:read, :write, :binary, :raw])
  end

  defp close_device(device_file) do
    File.close(device_file)
  end

  defp spawn_reader(parent_pid, device_file, read_size) do
    spawn_link(fn -> reader_loop(parent_pid, device_file, read_size) end)
  end

  defp reader_loop(parent_pid, device_file, read_size) do
    case IO.binread(device_file, read_size) do
      {:error, reason} ->
        send(parent_pid, {:reader_error, reason})

      :eof ->
        send(parent_pid, {:reader_error, :eof})

      data when is_binary(data) ->
        send(parent_pid, {:frame_data, data})
        reader_loop(parent_pid, device_file, read_size)
    end
  end

  defp write_frame(device_file, payload, opts) do
    encoded = USBHID.encode(payload, opts)

    case IO.binwrite(device_file, encoded) do
      :ok -> :ok
      {:error, _} = error -> error
    end
  end

  defp invoke_handler(callback, args, state) do
    case apply(state.handler_module, callback, args) do
      {:noreply, new_handler_state} ->
        {:ok, %{state | handler_state: new_handler_state}}

      {:reply, payload, new_handler_state} ->
        # Return reply tuple with updated state
        {:reply, payload, %{state | handler_state: new_handler_state}}

      {:stop, reason, new_handler_state} ->
        {:stop, reason, %{state | handler_state: new_handler_state}}
    end
  end

  defp handle_disconnection(reason, state) do
    # Close device
    if state.device_file do
      close_device(state.device_file)
    end

    # Clear reader references
    state = %{state | device_file: nil, reader_pid: nil, reader_ref: nil}

    # Notify handler
    case invoke_handler(:handle_disconnected, [reason, state.handler_state], state) do
      {:ok, new_state} ->
        {:stop, {:disconnected, reason}, new_state}

      {:stop, stop_reason, new_state} ->
        {:stop, stop_reason, new_state}
    end
  end
end
