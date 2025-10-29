defmodule KNXStack do
  @moduledoc """
  KNX protocol stack implementation in Elixir.

  This library provides a native Elixir implementation of the KNX protocol,
  including support for USB HID communication with KNX devices.

  ## Modules

  - `KNXStack.USBHID` - USB HID protocol encoding and decoding
  - `KNXStack.USBHID.Protocol` - Protocol definitions and constants
  - `KNXStack.USBHID.Encode` - Message encoding functions
  - `KNXStack.USBHID.Decode` - Message decoding functions

  ## Quick Start

  ### Encoding a KNX message for USB HID

      payload = <<0x29, 0x00, 0xBC, 0xE0, 0x00, 0x01>>
      encoded = KNXStack.USBHID.encode(payload)

  ### Decoding a USB HID message

      {:ok, decoded} = KNXStack.USBHID.decode(data)
      IO.inspect(decoded.payload)

  ## Architecture

  The library is designed with a synchronous API that can be easily extended
  with GenServer/OTP patterns for stateful communication:

  - **Current**: Synchronous encode/decode functions
  - **Future**: GenServer-based client for managing USB HID connections
  - **Future**: Supervision trees for fault-tolerant KNX communication

  ## Protocol Support

  Currently implemented:
  - USB HID report encoding/decoding
  - Multiple packet types (all-in-one, partial, start, end)
  - Protocol identifiers (KNX Tunnel, M-Bus, BatiBus, Bus Access Server)
  - EMI (External Message Interface) support

  Future additions:
  - KNXnet/IP tunneling
  - Group address management
  - Datapoint types
  - Address and association tables
  """

  @doc """
  Returns the library version.

  ## Examples

      iex> KNXStack.version()
      "0.1.0"
  """
  @spec version() :: String.t()
  def version do
    "0.1.0"
  end
end
