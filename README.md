# KNXStack

A pure Elixir implementation of the KNX protocol stack with USB HID support for communicating with KNX devices.

## Features

- **USB HID Protocol**: Full encode/decode support for KNX USB HID reports
- **Callback-based API**: Event-driven architecture with GenServer-backed device management
- **Pure Elixir**: No NIFs or ports required - works seamlessly on Nerves and embedded systems
- **Non-blocking I/O**: Separate reader process prevents blocking during device communication
- **Flexible Write API**: Send frames via callback returns or API calls
- **Well-tested**: Comprehensive test coverage with doctests

## Quick Start

### Define a Handler

```elixir
defmodule MyKNXHandler do
  use KNXStack.USBHID.Handler

  @impl true
  def init(_opts) do
    {:ok, %{frame_count: 0}}
  end

  @impl true
  def handle_connected(device_info, state) do
    IO.puts("Connected to KNX device: #{device_info.path}")
    {:noreply, state}
  end

  @impl true
  def handle_frame(payload, state) do
    IO.inspect(payload, label: "KNX Frame")
    {:noreply, %{state | frame_count: state.frame_count + 1}}
  end

  @impl true
  def handle_disconnected(reason, state) do
    IO.puts("Disconnected: #{inspect(reason)}")
    IO.puts("Total frames received: #{state.frame_count}")
    {:noreply, state}
  end
end
```

### Connect to Device

```elixir
# Start listening on the KNX bus
{:ok, pid} = KNXStack.USBHID.Device.start_link(
  handler: MyKNXHandler,
  device: "/dev/hidraw0"
)

# Send a frame to the bus
payload = <<0x29, 0x00, 0xBC, 0xE0, 0x00, 0x01>>
KNXStack.USBHID.Device.send_frame(pid, payload)

# Stop the connection
KNXStack.USBHID.Device.stop(pid)
```

## Architecture

### Protocol Layers

KNXStack implements the full USB HID protocol stack:

```
┌─────────────────────────────────────┐
│  Report Header (3 bytes)            │
│  - report_id, packet_info, length   │
├─────────────────────────────────────┤
│  USB Protocol Header (8 bytes)      │
│  - version, header_length,          │
│    body_length, protocol_id,        │
│    reserved (3 bytes)                │
├─────────────────────────────────────┤
│  EMI Header (3 bytes)                │
│  - emi_id, reserved (2 bytes)        │
├─────────────────────────────────────┤
│  KNX Payload (variable)              │
└─────────────────────────────────────┘
```

### Device Manager

The `KNXStack.USBHID.Device` GenServer manages:
- Device file I/O (`/dev/hidraw0`)
- Non-blocking reader process for continuous frame reception
- Frame encoding/decoding using the protocol stack
- Handler callback invocation
- Connection lifecycle management

## Handler Callbacks

Implement the `KNXStack.USBHID.Handler` behavior to receive events:

| Callback | Purpose |
|----------|---------|
| `init/1` | Initialize handler state before connection |
| `handle_connected/2` | Device connection established |
| `handle_frame/2` | KNX frame received from bus |
| `handle_disconnected/2` | Device connection lost |
| `terminate/2` | Handler cleanup before shutdown |

### Callback Returns

All callbacks support flexible return values:

- `{:noreply, new_state}` - Update state and continue
- `{:reply, payload, new_state}` - Send a frame and update state
- `{:stop, reason, state}` - Stop the device connection

## Sending Frames

Two ways to send frames to the KNX bus:

### 1. Via Callback Return

```elixir
def handle_frame(incoming_payload, state) do
  response = build_response(incoming_payload)
  {:reply, response, state}
end
```

### 2. Via API Call

```elixir
def handle_frame(incoming_payload, state) do
  # Send asynchronously from anywhere
  KNXStack.USBHID.Device.send_frame(device_pid, response)
  {:noreply, state}
end
```

## Low-Level Protocol API

For direct protocol manipulation without device management:

```elixir
# Encode a KNX payload into USB HID format
payload = <<0x29, 0x00, 0xBC, 0xE0>>
encoded = KNXStack.USBHID.encode(payload)

# Decode a USB HID report
{:ok, decoded} = KNXStack.USBHID.decode(data)
IO.inspect(decoded.payload)

# Extract just the payload
{:ok, payload} = KNXStack.USBHID.extract_payload(data)
```

## Examples

See the `examples/` directory for complete implementations:

- **SimpleListener** (`examples/simple_listener.ex`) - Logs all frames from the bus
- **EchoHandler** (`examples/echo_handler.ex`) - Echoes frames back to demonstrate both send patterns

## Supported Devices

Tested with:
- **Hager Electro KNX-USB Data Interface** (VID: 0x135E, PID: 0x0025)

Should work with any KNX USB HID device following the KNX USB HID specification.

## Installation

Add `knx_stack` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:knx_stack, "~> 0.1.0"}
  ]
end
```

## Device Permissions

Ensure your user has access to the HID device:

```bash
# Check device
ls -la /dev/hidraw*

# Add udev rule (create /etc/udev/rules.d/99-knx-usb.rules)
SUBSYSTEM=="hidraw", ATTRS{idVendor}=="135e", ATTRS{idProduct}=="0025", MODE="0666"

# Reload udev rules
sudo udevadm control --reload-rules
sudo udevadm trigger
```

## Documentation

Generate documentation with ExDoc:

```bash
mix docs
```

Documentation can be found at `doc/index.html` after generation.

## Testing

```bash
# Run all tests
mix test

# Run with coverage
mix test --cover

# Run specific test file
mix test test/knx_stack/usb_hid/device_test.exs
```

## Roadmap

- [ ] KNXnet/IP tunneling support
- [ ] Group address management
- [ ] Datapoint type encoding/decoding (DPT)
- [ ] Device discovery and enumeration
- [ ] Telegram routing and filtering
- [ ] Integration with HomeAssistant/Nerves systems

## License

Copyright (c) 2025

Licensed under the MIT License.

