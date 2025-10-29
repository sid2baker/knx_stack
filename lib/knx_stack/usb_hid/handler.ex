defmodule KNXStack.USBHID.Handler do
  @moduledoc """
  Behavior for implementing KNX USB HID event handlers.

  This behavior defines callbacks for handling KNX bus events in a callback-driven
  architecture. Implement this behavior to process incoming frames, handle connection
  lifecycle events, and optionally send responses back to the bus.

  ## Example

      defmodule MyKNXHandler do
        use KNXStack.USBHID.Handler

        @impl true
        def init(opts) do
          state = %{counter: 0}
          {:ok, state}
        end

        @impl true
        def handle_connected(device_info, state) do
          IO.puts("Connected to device: \#{device_info.path}")
          {:noreply, state}
        end

        @impl true
        def handle_frame(payload, state) do
          IO.inspect(payload, label: "Received KNX frame")
          new_state = %{state | counter: state.counter + 1}

          # Option 1: Just update state
          {:noreply, new_state}

          # Option 2: Send a response frame
          # response = build_response(payload)
          # {:reply, response, new_state}
        end

        @impl true
        def handle_disconnected(reason, state) do
          IO.puts("Disconnected: \#{inspect(reason)}")
          {:noreply, state}
        end

        @impl true
        def terminate(reason, state) do
          IO.puts("Terminating: \#{inspect(reason)}")
          :ok
        end
      end

      # Start the handler
      {:ok, pid} = KNXStack.USBHID.Device.start_link(
        handler: MyKNXHandler,
        device: "/dev/hidraw0"
      )

  ## Callbacks

  All callbacks receive the current state and must return a tuple indicating
  the next action:

  - `{:noreply, new_state}` - Continue with updated state
  - `{:reply, payload, new_state}` - Send payload to bus and update state
  - `{:stop, reason, state}` - Stop the device connection

  ## Sending Frames

  You can send frames to the bus in two ways:

  1. **Via callback return**: Return `{:reply, payload, state}` from any callback
  2. **Via API call**: Call `KNXStack.USBHID.Device.send_frame(pid, payload)` from anywhere
  """

  @type device_info :: %{
          path: String.t(),
          vendor_id: integer() | nil,
          product_id: integer() | nil
        }

  @type state :: term()
  @type payload :: binary()
  @type reason :: term()

  @type noreply_return :: {:noreply, state()}
  @type reply_return :: {:reply, payload(), state()}
  @type stop_return :: {:stop, reason(), state()}
  @type handler_return :: noreply_return() | reply_return() | stop_return()

  @doc """
  Invoked when the handler is started.

  This callback is called before the device connection is established.
  Use it to initialize your handler's state.

  ## Parameters

  - `opts` - Options passed to `start_link/1`

  ## Returns

  - `{:ok, state}` - Successfully initialized with initial state
  - `{:stop, reason}` - Initialization failed, won't connect to device
  """
  @callback init(opts :: keyword()) :: {:ok, state()} | {:stop, reason()}

  @doc """
  Invoked when the USB HID device connection is established.

  ## Parameters

  - `device_info` - Map containing device path and optional vendor/product IDs
  - `state` - Current handler state

  ## Returns

  Handler return tuple (`:noreply`, `:reply`, or `:stop`)
  """
  @callback handle_connected(device_info(), state()) :: handler_return()

  @doc """
  Invoked when a KNX frame is received from the bus.

  This is called for every decoded frame read from the USB HID device.
  The payload is the raw KNX message data with USB HID protocol layers stripped.

  ## Parameters

  - `payload` - Raw KNX frame payload (binary)
  - `state` - Current handler state

  ## Returns

  Handler return tuple (`:noreply`, `:reply`, or `:stop`)
  """
  @callback handle_frame(payload(), state()) :: handler_return()

  @doc """
  Invoked when the device connection is lost or closed.

  ## Parameters

  - `reason` - Reason for disconnection (e.g., `:device_removed`, `:read_error`)
  - `state` - Current handler state

  ## Returns

  Handler return tuple (`:noreply`, `:reply`, or `:stop`)
  """
  @callback handle_disconnected(reason(), state()) :: handler_return()

  @doc """
  Invoked when the handler is about to terminate.

  Use this callback to perform cleanup operations.

  ## Parameters

  - `reason` - Termination reason
  - `state` - Current handler state

  ## Returns

  `:ok` or any term (return value is ignored)
  """
  @callback terminate(reason(), state()) :: term()

  @doc false
  defmacro __using__(_opts) do
    quote do
      @behaviour KNXStack.USBHID.Handler

      @doc false
      def init(_opts), do: {:ok, %{}}

      @doc false
      def handle_connected(_device_info, state), do: {:noreply, state}

      @doc false
      def handle_frame(_payload, state), do: {:noreply, state}

      @doc false
      def handle_disconnected(_reason, state), do: {:noreply, state}

      @doc false
      def terminate(_reason, _state), do: :ok

      defoverridable init: 1,
                     handle_connected: 2,
                     handle_frame: 2,
                     handle_disconnected: 2,
                     terminate: 2
    end
  end
end
