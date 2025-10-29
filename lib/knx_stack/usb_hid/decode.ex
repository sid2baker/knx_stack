defmodule KNXStack.USBHID.Decode do
  @moduledoc """
  USB HID decoding functions for KNX messages.

  Handles decoding of USB HID reports into KNX message components, including:
  - Report headers (report identifier, packet info)
  - Report body (USB protocol header)
  - EMI message data
  """

  import Bitwise

  alias KNXStack.USBHID.Protocol

  @typedoc """
  Decoded USB HID message structure.
  """
  @type decoded_message :: %{
          report_id: byte(),
          sequence_number: integer(),
          packet_type: Protocol.packet_type(),
          data_length: integer(),
          protocol_version: byte(),
          header_length: byte(),
          body_length: integer(),
          protocol_id: Protocol.protocol_id(),
          emi_id: byte(),
          payload: binary()
        }

  @doc """
  Decodes a USB HID report into its constituent parts.

  Parses the complete USB HID report structure and extracts:
  - Report header information
  - USB protocol header
  - EMI header
  - Payload data

  ## Parameters

  - `data` - Binary containing the complete USB HID report

  ## Returns

  - `{:ok, decoded_message}` - Successfully decoded message
  - `{:error, reason}` - Decoding failed

  ## Examples

      iex> data = <<0x01, 0x13, 0x11, 0x00, 0x08, 0x00, 0x0B, 0x01, 0x03, 0x00, 0x00, 0x29, 0x00, 0xBC, 0xE0, 0x00, 0x01, 0xAB, 0xCC>>
      iex> {:ok, msg} = KNXStack.USBHID.Decode.decode_message(data)
      iex> msg.sequence_number
      1
      iex> msg.packet_type
      :all_in_one_packet
      iex> msg.emi_id
      3
  """
  @spec decode_message(binary()) :: {:ok, decoded_message()} | {:error, atom()}
  def decode_message(data) do
    with {:ok, report_id, rest} <- decode_report_identifier(data),
         {:ok, seq_num, pkt_type, data_len, rest} <- decode_packet_info(rest),
         {:ok, protocol_info, emi_data} <- decode_usb_protocol_header(rest),
         {:ok, emi_id, payload} <- decode_emi_header(emi_data) do
      decoded = %{
        report_id: report_id,
        sequence_number: seq_num,
        packet_type: pkt_type,
        data_length: data_len,
        protocol_version: protocol_info.version,
        header_length: protocol_info.header_length,
        body_length: protocol_info.body_length,
        protocol_id: protocol_info.protocol_id,
        emi_id: emi_id,
        payload: payload
      }

      {:ok, decoded}
    end
  end

  @doc """
  Decodes the report identifier from the message header.

  Extracts the first byte which should be KNX_DATA_EXCHANGE (0x01).

  ## Examples

      iex> KNXStack.USBHID.Decode.decode_report_identifier(<<0x01, 0x13, 0x09>>)
      {:ok, 0x01, <<0x13, 0x09>>}

      iex> KNXStack.USBHID.Decode.decode_report_identifier(<<0x02, 0x13>>)
      {:error, :invalid_report_identifier}
  """
  @spec decode_report_identifier(binary()) :: {:ok, byte(), binary()} | {:error, atom()}
  def decode_report_identifier(<<report_id, rest::binary>>) do
    if report_id == Protocol.knx_data_exchange() do
      {:ok, report_id, rest}
    else
      {:error, :invalid_report_identifier}
    end
  end

  def decode_report_identifier(_), do: {:error, :insufficient_data}

  @doc """
  Decodes packet information from the report header.

  Extracts:
  - Sequence number (high nibble of byte 1)
  - Packet type (low nibble of byte 1)
  - Data length (byte 2)

  ## Examples

      iex> KNXStack.USBHID.Decode.decode_packet_info(<<0x13, 0x09, 0xAA, 0xBB>>)
      {:ok, 1, :all_in_one_packet, 9, <<0xAA, 0xBB>>}

      iex> KNXStack.USBHID.Decode.decode_packet_info(<<0x25, 0x10>>)
      {:ok, 2, :start_packet, 16, <<>>}
  """
  @spec decode_packet_info(binary()) ::
          {:ok, integer(), Protocol.packet_type(), integer(), binary()} | {:error, atom()}
  def decode_packet_info(<<packet_info_byte, data_length, rest::binary>>) do
    sequence_number = bsr(packet_info_byte, 4)
    packet_type_byte = packet_info_byte &&& 0x0F

    case Protocol.byte_to_packet_type(packet_type_byte) do
      {:ok, packet_type} ->
        {:ok, sequence_number, packet_type, data_length, rest}

      {:error, _} = error ->
        error
    end
  end

  def decode_packet_info(_), do: {:error, :insufficient_data}

  @doc """
  Decodes the USB protocol header (5 bytes).

  Extracts:
  - Protocol version (1 byte)
  - Header length field (1 byte) - constant value 0x08
  - Body length (2 bytes, big-endian) - length of EMI header + payload
  - Protocol ID (1 byte)

  Returns the remaining data which contains the EMI header and payload.

  ## Examples

      iex> data = <<0x00, 0x08, 0x00, 0x05, 0x01, 0x03, 0x00, 0x00, 0xAA, 0xBB>>
      iex> {:ok, info, rest} = KNXStack.USBHID.Decode.decode_usb_protocol_header(data)
      iex> info.protocol_id
      :knx_tunnel
      iex> info.body_length
      5
      iex> rest
      <<0x03, 0x00, 0x00, 0xAA, 0xBB>>
  """
  @spec decode_usb_protocol_header(binary()) ::
          {:ok,
           %{
             version: byte(),
             header_length: byte(),
             body_length: integer(),
             protocol_id: Protocol.protocol_id()
           }, binary()}
          | {:error, atom()}
  def decode_usb_protocol_header(
        <<version, header_length, body_length::16, protocol_id_byte, rest::binary>>
      ) do
    case Protocol.byte_to_protocol_id(protocol_id_byte) do
      {:ok, protocol_id} ->
        protocol_info = %{
          version: version,
          header_length: header_length,
          body_length: body_length,
          protocol_id: protocol_id
        }

        {:ok, protocol_info, rest}

      {:error, _} = error ->
        error
    end
  end

  def decode_usb_protocol_header(_), do: {:error, :insufficient_data}

  @doc """
  Decodes the EMI header.

  Extracts:
  - EMI ID (1 byte)
  - Reserved bytes (2 bytes)
  - Remaining data as payload

  ## Examples

      iex> KNXStack.USBHID.Decode.decode_emi_header(<<0x03, 0x00, 0x00, 0x29, 0x00, 0xBC>>)
      {:ok, 0x03, <<0x29, 0x00, 0xBC>>}
  """
  @spec decode_emi_header(binary()) :: {:ok, byte(), binary()} | {:error, atom()}
  def decode_emi_header(<<emi_id, _reserved::16, payload::binary>>) do
    {:ok, emi_id, payload}
  end

  def decode_emi_header(_), do: {:error, :insufficient_data}

  @doc """
  Extracts just the payload from a USB HID report.

  Convenience function to skip all headers and return only the KNX message payload.

  ## Examples

      iex> data = <<0x01, 0x13, 0x13, 0x00, 0x08, 0x00, 0x0B, 0x01, 0x03, 0x00, 0x00, 0x29, 0x00, 0xBC, 0xE0, 0x00, 0x01, 0xAB, 0xCC>>
      iex> KNXStack.USBHID.Decode.extract_payload(data)
      {:ok, <<0x29, 0x00, 0xBC, 0xE0, 0x00, 0x01, 0xAB, 0xCC>>}
  """
  @spec extract_payload(binary()) :: {:ok, binary()} | {:error, atom()}
  def extract_payload(data) do
    case decode_message(data) do
      {:ok, %{payload: payload}} -> {:ok, payload}
      {:error, _} = error -> error
    end
  end
end
