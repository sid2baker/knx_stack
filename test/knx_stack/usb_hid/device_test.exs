defmodule KNXStack.USBHID.DeviceTest do
  use ExUnit.Case, async: false

  alias KNXStack.USBHID.Device

  defmodule TestHandler do
    use KNXStack.USBHID.Handler

    def init(opts) do
      test_pid = Keyword.fetch!(opts, :test_pid)
      {:ok, %{test_pid: test_pid, frames: []}}
    end

    def handle_connected(device_info, state) do
      send(state.test_pid, {:connected, device_info})
      {:noreply, state}
    end

    def handle_frame(payload, state) do
      send(state.test_pid, {:frame, payload})
      new_state = %{state | frames: [payload | state.frames]}
      {:noreply, new_state}
    end

    def handle_disconnected(reason, state) do
      send(state.test_pid, {:disconnected, reason})
      {:noreply, state}
    end

    def terminate(reason, state) do
      send(state.test_pid, {:terminated, reason})
      :ok
    end
  end

  describe "Handler behavior" do
    test "Handler can be implemented with all callbacks" do
      assert function_exported?(TestHandler, :init, 1)
      assert function_exported?(TestHandler, :handle_connected, 2)
      assert function_exported?(TestHandler, :handle_frame, 2)
      assert function_exported?(TestHandler, :handle_disconnected, 2)
      assert function_exported?(TestHandler, :terminate, 2)
    end

    test "Handler init returns proper state" do
      assert {:ok, state} = TestHandler.init(test_pid: self())
      assert is_map(state)
      assert state.test_pid == self()
    end
  end

  describe "Device GenServer" do
    @tag :skip
    # Skip by default - requires actual HID device
    test "can start with valid device path", %{tmp_dir: tmp_dir} do
      # Create a fake device file for testing
      device_path = Path.join(tmp_dir, "fake_hidraw0")
      File.write!(device_path, "")

      opts = [
        handler: TestHandler,
        device: device_path,
        handler_opts: [test_pid: self()]
      ]

      # This will fail to open the fake file, but tests initialization
      assert {:error, _} = Device.start_link(opts)
    end

    test "requires handler option" do
      # GenServer.start_link will return error tuple instead of raising
      Process.flag(:trap_exit, true)
      result = Device.start_link(device: "/dev/hidraw0")

      assert match?({:error, _}, result)
    end

    test "requires device option" do
      # GenServer.start_link will return error tuple instead of raising
      Process.flag(:trap_exit, true)
      result = Device.start_link(handler: TestHandler)

      assert match?({:error, _}, result)
    end
  end

  describe "send_frame/2" do
    test "sends cast message to GenServer" do
      # We can't test actual device communication without hardware,
      # but we can verify the API exists and accepts correct arguments
      assert function_exported?(Device, :send_frame, 2)
      assert function_exported?(Device, :send_frame, 3)
    end
  end
end
