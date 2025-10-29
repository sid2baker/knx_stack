defmodule KNXStack.USBHID do
  @moduledoc """
  KNX USB HID protocol implementation.

  Provides high-level functions for encoding and decoding KNX messages in USB HID format.
  This module serves as the main entry point for USB HID operations.

  ## Overview

  The USB HID protocol is used for communication with KNX USB devices. Messages are
  structured with multiple layers:

  1. **Report Header** - Contains report identifier, packet information, and data length
  2. **USB Protocol Header** - Protocol version, header/body lengths, protocol ID
  3. **EMI Header** - External Message Interface identifier
  4. **Payload** - The actual KNX message data

  ## Examples

  ### Encoding a message

      iex> payload = <<0x29, 0x00, 0xBC, 0xE0, 0x00, 0x01>>
      iex> encoded = KNXStack.USBHID.encode(payload)
      iex> is_binary(encoded)
      true

  ### Decoding a message

      iex> data = <<0x01, 0x13, 0x13, 0x00, 0x08, 0x00, 0x0B, 0x01, 0x03, 0x00, 0x00, 0x29, 0x00, 0xBC, 0xE0, 0x00, 0x01, 0xAB, 0xCC>>
      iex> {:ok, decoded} = KNXStack.USBHID.decode(data)
      iex> decoded.packet_type
      :all_in_one_packet

  ### Extracting just the payload

      iex> data = <<0x01, 0x13, 0x13, 0x00, 0x08, 0x00, 0x0B, 0x01, 0x03, 0x00, 0x00, 0x29, 0x00, 0xBC, 0xE0, 0x00, 0x01, 0xAB, 0xCC>>
      iex> {:ok, payload} = KNXStack.USBHID.extract_payload(data)
      iex> payload
      <<0x29, 0x00, 0xBC, 0xE0, 0x00, 0x01, 0xAB, 0xCC>>

  ## Protocol Details

  The implementation follows the KNX USB HID specification and supports:

  - Multiple packet types (all-in-one, partial, start, end)
  - Protocol IDs (KNX Tunnel, M-Bus, BatiBus, Bus Access Server Features)
  - Service identifiers for device feature management
  - Feature identifiers for EMI type, device descriptors, connection status, etc.

  ## Future Extensions

  This synchronous API can be easily wrapped in a GenServer for stateful
  communication with USB HID devices, connection management, and supervision trees.
  """

  alias KNXStack.USBHID.{Encode, Decode, Protocol}

  @doc """
  Encodes a KNX payload into USB HID report format.

  Takes a binary payload and wraps it with all necessary USB HID protocol layers.

  ## Parameters

  - `payload` - Raw KNX message data as binary
  - `opts` - Keyword list of options:
    - `:sequence_number` - Packet sequence number (default: 1)
    - `:packet_type` - Packet type atom (default: `:all_in_one_packet`)
    - `:protocol_id` - Protocol identifier atom (default: `:knx_tunnel`)
    - `:emi_id` - EMI type byte (default: 0x03 for commonEmi)

  ## Returns

  Binary containing the complete USB HID report.

  ## Examples

      iex> encoded = KNXStack.USBHID.encode(<<0x29, 0x00>>)
      iex> byte_size(encoded)
      13

      iex> encoded = KNXStack.USBHID.encode(<<0xAB>>, sequence_number: 2, packet_type: :start_packet)
      iex> {:ok, decoded} = KNXStack.USBHID.decode(encoded)
      iex> decoded.payload
      <<0xAB>>
  """
  @spec encode(binary(), keyword()) :: binary()
  defdelegate encode(payload, opts \\ []), to: Encode, as: :encode_message

  @doc """
  Decodes a USB HID report into its constituent parts.

  Parses all layers of the USB HID protocol and returns a map containing:
  - `report_id` - Report identifier byte
  - `sequence_number` - Packet sequence number
  - `packet_type` - Type of packet (atom)
  - `data_length` - Length of data in body
  - `protocol_version` - USB protocol version
  - `header_length` - Protocol header length
  - `body_length` - Body data length
  - `protocol_id` - Protocol identifier (atom)
  - `emi_id` - EMI type identifier
  - `payload` - Raw KNX message payload

  ## Parameters

  - `data` - Binary containing complete USB HID report

  ## Returns

  - `{:ok, decoded_message}` - Successfully decoded message map
  - `{:error, reason}` - Decoding error with reason atom

  ## Examples

      iex> data = <<0x01, 0x13, 0x13, 0x00, 0x08, 0x00, 0x0B, 0x01, 0x03, 0x00, 0x00, 0x29, 0x00, 0xBC, 0xE0, 0x00, 0x01, 0xAB, 0xCC>>
      iex> {:ok, msg} = KNXStack.USBHID.decode(data)
      iex> msg.payload
      <<0x29, 0x00, 0xBC, 0xE0, 0x00, 0x01, 0xAB, 0xCC>>
  """
  @spec decode(binary()) :: {:ok, Decode.decoded_message()} | {:error, atom()}
  defdelegate decode(data), to: Decode, as: :decode_message

  @doc """
  Extracts only the KNX payload from a USB HID report.

  Convenience function that decodes the entire report but returns only
  the raw KNX message payload, stripping all USB HID protocol layers.

  ## Parameters

  - `data` - Binary containing complete USB HID report

  ## Returns

  - `{:ok, payload}` - Extracted payload binary
  - `{:error, reason}` - Extraction error with reason atom

  ## Examples

      iex> data = <<0x01, 0x13, 0x13, 0x00, 0x08, 0x00, 0x0B, 0x01, 0x03, 0x00, 0x00, 0x29, 0x00, 0xBC, 0xE0, 0x00, 0x01, 0xAB, 0xCC>>
      iex> KNXStack.USBHID.extract_payload(data)
      {:ok, <<0x29, 0x00, 0xBC, 0xE0, 0x00, 0x01, 0xAB, 0xCC>>}
  """
  @spec extract_payload(binary()) :: {:ok, binary()} | {:error, atom()}
  defdelegate extract_payload(data), to: Decode

  # Re-export Protocol functions for convenience

  @doc """
  Returns the KNX Data Exchange constant (0x01).

  ## Examples

      iex> KNXStack.USBHID.knx_data_exchange()
      0x01
  """
  defdelegate knx_data_exchange(), to: Protocol

  @doc """
  Returns the KNX USB Transfer Protocol version constant (0x00).

  ## Examples

      iex> KNXStack.USBHID.knx_usb_transfer_protocol()
      0x00
  """
  defdelegate knx_usb_transfer_protocol(), to: Protocol

  @doc "Returns the KNX USB Transfer Protocol header length (0x08)."
  defdelegate knx_usb_transfer_protocol_header_length(), to: Protocol

  # Type re-exports for documentation
  @type packet_type :: Protocol.packet_type()
  @type protocol_id :: Protocol.protocol_id()
  @type service_id :: Protocol.service_id()
  @type feature_id :: Protocol.feature_id()
  @type decoded_message :: Decode.decoded_message()
end
