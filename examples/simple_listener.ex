defmodule KNXStack.Examples.SimpleListener do
  @moduledoc """
  Example KNX USB HID handler that logs all frames from the bus.

  ## Usage

  Start the listener:

      {:ok, pid} = KNXStack.USBHID.Device.start_link(
        handler: KNXStack.Examples.SimpleListener,
        device: "/dev/hidraw0"
      )

  Send a frame to the bus:

      payload = <<0x29, 0x00, 0xBC, 0xE0, 0x00, 0x01>>
      KNXStack.USBHID.Device.send_frame(pid, payload)

  Stop the listener:

      KNXStack.USBHID.Device.stop(pid)

  ## Running in IEx

      iex> {:ok, pid} = KNXStack.USBHID.Device.start_link(
      ...>   handler: KNXStack.Examples.SimpleListener,
      ...>   device: "/dev/hidraw0"
      ...> )
      Connected to KNX device: /dev/hidraw0
      {:ok, #PID<0.123.0>}

      # Frames will be logged as they arrive from the bus
      [SimpleListener] Frame received (6 bytes): <<0x29, 0x00, 0xBC, 0xE0, 0x00, 0x01>>
  """

  use KNXStack.USBHID.Handler
  require Logger

  @impl true
  def init(_opts) do
    Logger.info("SimpleListener initialized")
    {:ok, %{frame_count: 0}}
  end

  @impl true
  def handle_connected(device_info, state) do
    Logger.info("Connected to KNX device: #{device_info.path}")
    {:noreply, state}
  end

  @impl true
  def handle_frame(payload, state) do
    frame_count = state.frame_count + 1

    Logger.info(
      "[SimpleListener] Frame ##{frame_count} received (#{byte_size(payload)} bytes): #{inspect(payload, limit: :infinity)}"
    )

    {:noreply, %{state | frame_count: frame_count}}
  end

  @impl true
  def handle_disconnected(reason, state) do
    Logger.warning("Disconnected from KNX device. Reason: #{inspect(reason)}")
    Logger.info("Total frames received: #{state.frame_count}")
    {:noreply, state}
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("SimpleListener terminating. Reason: #{inspect(reason)}")
    Logger.info("Final frame count: #{state.frame_count}")
    :ok
  end
end
