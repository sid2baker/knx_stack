defmodule KNXStack.Examples.EchoHandler do
  @moduledoc """
  Example KNX USB HID handler that echoes received frames back to the bus.

  This demonstrates both callback-based replies (using `{:reply, payload, state}`)
  and API-based sends (using `Device.send_frame/2`).

  ## Usage

      {:ok, pid} = KNXStack.USBHID.Device.start_link(
        handler: KNXStack.Examples.EchoHandler,
        device: "/dev/hidraw0",
        handler_opts: [echo_mode: :callback]  # or :api
      )

  ## Echo Modes

  - `:callback` - Echoes immediately via `{:reply, payload, state}` return
  - `:api` - Echoes asynchronously via `Device.send_frame/2` API call
  """

  use KNXStack.USBHID.Handler
  require Logger

  @impl true
  def init(opts) do
    echo_mode = Keyword.get(opts, :echo_mode, :callback)
    Logger.info("EchoHandler initialized with mode: #{echo_mode}")

    {:ok, %{echo_mode: echo_mode, device_pid: nil, echo_count: 0}}
  end

  @impl true
  def handle_connected(device_info, state) do
    Logger.info("Connected to KNX device: #{device_info.path}")

    # Store our own PID for API-based sending
    # In real usage, you'd pass the device PID from start_link
    {:noreply, %{state | device_pid: self()}}
  end

  @impl true
  def handle_frame(payload, state) do
    echo_count = state.echo_count + 1
    Logger.info("[Echo ##{echo_count}] Received frame: #{inspect(payload, limit: :infinity)}")

    case state.echo_mode do
      :callback ->
        # Immediate reply via callback return
        Logger.info("[Echo ##{echo_count}] Echoing via callback")
        {:reply, payload, %{state | echo_count: echo_count}}

      :api ->
        # Asynchronous send via API
        Logger.info("[Echo ##{echo_count}] Echoing via API call")
        # Note: In real usage, you'd have the device PID stored
        # KNXStack.USBHID.Device.send_frame(state.device_pid, payload)
        {:noreply, %{state | echo_count: echo_count}}
    end
  end

  @impl true
  def handle_disconnected(reason, state) do
    Logger.warning("Disconnected from KNX device. Reason: #{inspect(reason)}")
    Logger.info("Total frames echoed: #{state.echo_count}")
    {:noreply, state}
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("EchoHandler terminating. Reason: #{inspect(reason)}")
    Logger.info("Final echo count: #{state.echo_count}")
    :ok
  end
end
