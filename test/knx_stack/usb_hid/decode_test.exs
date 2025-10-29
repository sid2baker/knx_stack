defmodule KNXStack.USBHID.DecodeTest do
  use ExUnit.Case, async: true

  alias KNXStack.USBHID.Decode

  doctest Decode

  describe "decode_report_identifier/1" do
    test "decodes valid report identifier" do
      data = <<0x01, 0x13, 0x09>>
      assert {:ok, 0x01, <<0x13, 0x09>>} = Decode.decode_report_identifier(data)
    end

    test "rejects invalid report identifier" do
      data = <<0x02, 0x13, 0x09>>
      assert {:error, :invalid_report_identifier} = Decode.decode_report_identifier(data)
    end

    test "returns error for empty data" do
      assert {:error, :insufficient_data} = Decode.decode_report_identifier(<<>>)
    end
  end

  describe "decode_packet_info/1" do
    test "decodes packet info correctly" do
      # 0x13 = 0001 0011 -> sequence=1, type=3 (all_in_one_packet)
      data = <<0x13, 0x09, 0xAA, 0xBB>>
      assert {:ok, 1, :all_in_one_packet, 9, <<0xAA, 0xBB>>} = Decode.decode_packet_info(data)
    end

    test "extracts sequence number from high nibble" do
      data1 = <<0x13, 0x00>>
      {:ok, seq1, _, _, _} = Decode.decode_packet_info(data1)
      assert seq1 == 1

      data2 = <<0x23, 0x00>>
      {:ok, seq2, _, _, _} = Decode.decode_packet_info(data2)
      assert seq2 == 2

      data3 = <<0xF5, 0x00>>
      {:ok, seq3, _, _, _} = Decode.decode_packet_info(data3)
      assert seq3 == 15
    end

    test "extracts packet type from low nibble" do
      data1 = <<0x13, 0x00>>
      {:ok, _, type1, _, _} = Decode.decode_packet_info(data1)
      assert type1 == :all_in_one_packet

      data2 = <<0x15, 0x00>>
      {:ok, _, type2, _, _} = Decode.decode_packet_info(data2)
      assert type2 == :start_packet

      data3 = <<0x16, 0x00>>
      {:ok, _, type3, _, _} = Decode.decode_packet_info(data3)
      assert type3 == :end_packet
    end

    test "extracts data length" do
      data = <<0x13, 0x19, 0xAA>>
      {:ok, _, _, length, _} = Decode.decode_packet_info(data)
      assert length == 25
    end

    test "returns error for insufficient data" do
      assert {:error, :insufficient_data} = Decode.decode_packet_info(<<0x13>>)
      assert {:error, :insufficient_data} = Decode.decode_packet_info(<<>>)
    end

    test "returns error for unknown packet type" do
      data = <<0x1F, 0x09>>
      assert {:error, :unknown_packet_type} = Decode.decode_packet_info(data)
    end
  end

  describe "decode_usb_protocol_header/1" do
    test "decodes USB protocol header correctly" do
      data = <<0x00, 0x08, 0x00, 0x0B, 0x01, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00>>

      {:ok, info, rest} = Decode.decode_usb_protocol_header(data)

      assert info.version == 0x00
      assert info.header_length == 0x08
      assert info.body_length == 11
      assert info.protocol_id == :knx_tunnel
      assert rest == <<0x03, 0x00, 0x00>>
    end

    test "handles different protocol IDs" do
      data1 = <<0x00, 0x08, 0x00, 0x05, 0x01, 0x00, 0x00, 0x00, 0xAA>>
      {:ok, info1, _} = Decode.decode_usb_protocol_header(data1)
      assert info1.protocol_id == :knx_tunnel

      data2 = <<0x00, 0x08, 0x00, 0x05, 0x02, 0x00, 0x00, 0x00, 0xAA>>
      {:ok, info2, _} = Decode.decode_usb_protocol_header(data2)
      assert info2.protocol_id == :mbus_tunnel

      data3 = <<0x00, 0x08, 0x00, 0x05, 0x0F, 0x00, 0x00, 0x00, 0xAA>>
      {:ok, info3, _} = Decode.decode_usb_protocol_header(data3)
      assert info3.protocol_id == :bus_access_server_feature_service
    end

    test "parses body length as 16-bit value" do
      # Body length = 0x0123 = 291 bytes
      data = <<0x00, 0x08, 0x01, 0x23, 0x01, 0x00, 0x00, 0x00>>
      {:ok, info, _} = Decode.decode_usb_protocol_header(data)
      assert info.body_length == 291
    end

    test "returns error for insufficient data" do
      data = <<0x00, 0x08, 0x00, 0x05>>
      assert {:error, :insufficient_data} = Decode.decode_usb_protocol_header(data)
    end

    test "returns error for unknown protocol ID" do
      data = <<0x00, 0x08, 0x00, 0x05, 0xFF, 0x00, 0x00, 0x00>>
      assert {:error, :unknown_protocol_id} = Decode.decode_usb_protocol_header(data)
    end
  end

  describe "decode_emi_header/1" do
    test "decodes EMI header correctly" do
      data = <<0x03, 0x00, 0x00, 0x29, 0x00, 0xBC>>
      assert {:ok, 0x03, <<0x29, 0x00, 0xBC>>} = Decode.decode_emi_header(data)
    end

    test "handles different EMI IDs" do
      data1 = <<0x01, 0x00, 0x00, 0xAA>>
      {:ok, emi_id1, _} = Decode.decode_emi_header(data1)
      assert emi_id1 == 0x01

      data2 = <<0xFF, 0x00, 0x00, 0xBB>>
      {:ok, emi_id2, _} = Decode.decode_emi_header(data2)
      assert emi_id2 == 0xFF
    end

    test "returns error for insufficient data" do
      assert {:error, :insufficient_data} = Decode.decode_emi_header(<<0x03, 0x00>>)
      assert {:error, :insufficient_data} = Decode.decode_emi_header(<<>>)
    end
  end

  describe "decode_message/1" do
    test "decodes complete USB HID message" do
      # Real message from Python implementation
      data =
        <<0x01, 0x13, 0x13, 0x00, 0x08, 0x00, 0x0B, 0x01, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00,
          0x29, 0x00, 0xBC, 0xE0, 0x00, 0x01, 0xAB, 0xCC>>

      {:ok, decoded} = Decode.decode_message(data)

      assert decoded.report_id == 0x01
      assert decoded.sequence_number == 1
      assert decoded.packet_type == :all_in_one_packet
      assert decoded.data_length == 19
      assert decoded.protocol_version == 0x00
      assert decoded.header_length == 0x08
      assert decoded.body_length == 11
      assert decoded.protocol_id == :knx_tunnel
      assert decoded.emi_id == 0x03
      assert decoded.payload == <<0x29, 0x00, 0xBC, 0xE0, 0x00, 0x01, 0xAB, 0xCC>>
    end

    test "decodes message with different parameters" do
      # Sequence 2, start packet, M-Bus tunnel
      data =
        <<0x01, 0x25, 0x0C, 0x00, 0x08, 0x00, 0x04, 0x02, 0x00, 0x00, 0x00, 0x05, 0x00, 0x00,
          0xAA>>

      {:ok, decoded} = Decode.decode_message(data)

      assert decoded.sequence_number == 2
      assert decoded.packet_type == :start_packet
      assert decoded.protocol_id == :mbus_tunnel
      assert decoded.emi_id == 0x05
      assert decoded.payload == <<0xAA>>
    end

    test "returns error for invalid report identifier" do
      data = <<0x02, 0x13, 0x09, 0x00, 0x08>>
      assert {:error, :invalid_report_identifier} = Decode.decode_message(data)
    end

    test "returns error for insufficient data" do
      data = <<0x01, 0x13>>
      assert {:error, :insufficient_data} = Decode.decode_message(data)
    end
  end

  describe "extract_payload/1" do
    test "extracts payload from complete message" do
      data =
        <<0x01, 0x13, 0x13, 0x00, 0x08, 0x00, 0x0B, 0x01, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00,
          0x29, 0x00, 0xBC, 0xE0, 0x00, 0x01, 0xAB, 0xCC>>

      assert {:ok, <<0x29, 0x00, 0xBC, 0xE0, 0x00, 0x01, 0xAB, 0xCC>>} =
               Decode.extract_payload(data)
    end

    test "extracts empty payload" do
      data = <<0x01, 0x13, 0x0B, 0x00, 0x08, 0x00, 0x03, 0x01, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00>>
      assert {:ok, <<>>} = Decode.extract_payload(data)
    end

    test "propagates decoding errors" do
      data = <<0x02, 0x13, 0x09>>
      assert {:error, :invalid_report_identifier} = Decode.extract_payload(data)
    end
  end
end
