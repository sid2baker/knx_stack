defmodule KNXStack.USBHID.Encode do
  @moduledoc """
  USB HID encoding functions for KNX messages.

  Handles encoding of KNX messages into USB HID report format, including:
  - Report headers (report identifier, packet info)
  - Report body (USB protocol header)
  - EMI message data
  """

  import Bitwise

  alias KNXStack.USBHID.Protocol

  @doc """
  Encodes a KNX message into USB HID format.

  Takes a binary payload and encodes it with the full USB HID report structure:
  - Report header (report ID, packet info, data length)
  - USB protocol header (version, header length, body length, protocol ID)
  - EMI header (EMI ID bytes)
  - Payload data

  ## Parameters

  - `payload` - The raw KNX message data as binary
  - `opts` - Optional configuration:
    - `:sequence_number` - Packet sequence number (default: 1)
    - `:packet_type` - Type of packet (default: :all_in_one_packet)
    - `:protocol_id` - Protocol identifier (default: :knx_tunnel)
    - `:emi_id` - EMI type identifier (default: 0x03 for commonEmi)

  ## Returns

  Binary containing the complete USB HID report.

  ## Examples

      iex> payload = <<0x29, 0x00, 0xBC, 0xE0, 0x00, 0x01, 0xAB, 0xCC, 0x01, 0x00, 0x81>>
      iex> encoded = KNXStack.USBHID.Encode.encode_message(payload)
      iex> byte_size(encoded)
      25
  """
  @spec encode_message(binary(), keyword()) :: binary()
  def encode_message(payload, opts \\ []) do
    sequence_number = Keyword.get(opts, :sequence_number, 1)
    packet_type = Keyword.get(opts, :packet_type, :all_in_one_packet)
    protocol_id = Keyword.get(opts, :protocol_id, :knx_tunnel)
    emi_id = Keyword.get(opts, :emi_id, 0x03)

    # Build the message from innermost to outermost layer
    payload
    |> encode_emi_header(emi_id)
    |> encode_usb_protocol_header(protocol_id)
    |> encode_report_header(sequence_number, packet_type)
  end

  @doc """
  Encodes the report header (outermost layer).

  Adds:
  - Report identifier (1 byte): KNX_DATA_EXCHANGE (0x01)
  - Packet info (1 byte): sequence number (high nibble) + packet type (low nibble)
  - Data length (1 byte): length of the body

  ## Examples

      iex> body = <<0x00, 0x08, 0x0E, 0x01, 0x03, 0x00, 0x00, 0x29, 0x00>>
      iex> KNXStack.USBHID.Encode.encode_report_header(body, 1, :all_in_one_packet)
      <<0x01, 0x13, 0x09, 0x00, 0x08, 0x0E, 0x01, 0x03, 0x00, 0x00, 0x29, 0x00>>
  """
  @spec encode_report_header(binary(), integer(), Protocol.packet_type()) :: binary()
  def encode_report_header(body, sequence_number, packet_type) do
    report_id = Protocol.knx_data_exchange()
    packet_type_byte = Protocol.packet_type_to_byte(packet_type)

    # Pack sequence number (high nibble) and packet type (low nibble) into one byte
    packet_info = bsl(sequence_number, 4) ||| packet_type_byte

    data_length = byte_size(body)

    <<report_id, packet_info, data_length>> <> body
  end

  @doc """
  Encodes the USB protocol header (5 bytes).

  Adds:
  - Protocol version (1 byte): KNX_USB_TRANSFER_PROTOCOL (0x00)
  - Header length field (1 byte): KNX_USB_TRANSFER_PROTOCOL_HEADER_LENGTH (0x08) - constant value
  - Body length (2 bytes): length of the emi_data (EMI header + payload)
  - Protocol ID (1 byte): protocol identifier

  The emi_data parameter should already include the EMI header (3 bytes) + payload.

  ## Examples

      iex> emi_data = <<0x03, 0x00, 0x00, 0x29, 0x00>>
      iex> result = KNXStack.USBHID.Encode.encode_usb_protocol_header(emi_data, :knx_tunnel)
      iex> byte_size(result)
      10
  """
  @spec encode_usb_protocol_header(binary(), Protocol.protocol_id()) :: binary()
  def encode_usb_protocol_header(emi_data, protocol_id) do
    protocol_version = Protocol.knx_usb_transfer_protocol()
    header_length = Protocol.knx_usb_transfer_protocol_header_length()
    body_length = byte_size(emi_data)
    protocol_id_byte = Protocol.protocol_id_to_byte(protocol_id)

    # USB protocol header is 5 bytes, followed by the EMI data
    <<protocol_version, header_length, body_length::16, protocol_id_byte>> <> emi_data
  end

  @doc """
  Encodes the EMI header.

  Adds 3 bytes before the payload:
  - EMI ID (1 byte): typically 0x03 for commonEmi
  - Reserved (2 bytes): 0x00, 0x00

  ## Examples

      iex> payload = <<0x29, 0x00, 0xBC>>
      iex> KNXStack.USBHID.Encode.encode_emi_header(payload, 0x03)
      <<0x03, 0x00, 0x00, 0x29, 0x00, 0xBC>>
  """
  @spec encode_emi_header(binary(), byte()) :: binary()
  def encode_emi_header(payload, emi_id) do
    <<emi_id, 0x00, 0x00>> <> payload
  end

  @doc """
  Encodes packet info byte from sequence number and packet type.

  Combines a 4-bit sequence number (high nibble) with a 4-bit packet type (low nibble).

  ## Examples

      iex> KNXStack.USBHID.Encode.encode_packet_info(1, :all_in_one_packet)
      0x13

      iex> KNXStack.USBHID.Encode.encode_packet_info(2, :start_packet)
      0x25
  """
  @spec encode_packet_info(integer(), Protocol.packet_type()) :: byte()
  def encode_packet_info(sequence_number, packet_type) do
    packet_type_byte = Protocol.packet_type_to_byte(packet_type)
    bsl(sequence_number, 4) ||| packet_type_byte
  end
end
