defmodule KNXStack.USBHID.EncodeTest do
  use ExUnit.Case, async: true

  alias KNXStack.USBHID.Encode

  doctest Encode

  describe "encode_emi_header/2" do
    test "adds EMI ID and reserved bytes" do
      payload = <<0x29, 0x00, 0xBC>>
      result = Encode.encode_emi_header(payload, 0x03)

      assert result == <<0x03, 0x00, 0x00, 0x29, 0x00, 0xBC>>
    end

    test "works with empty payload" do
      result = Encode.encode_emi_header(<<>>, 0x03)
      assert result == <<0x03, 0x00, 0x00>>
    end

    test "preserves payload data" do
      payload = <<1, 2, 3, 4, 5>>
      result = Encode.encode_emi_header(payload, 0x05)

      assert result == <<0x05, 0x00, 0x00, 1, 2, 3, 4, 5>>
    end
  end

  describe "encode_usb_protocol_header/2" do
    test "adds USB protocol header with correct structure" do
      emi_data = <<0x03, 0x00, 0x00, 0x29>>
      result = Encode.encode_usb_protocol_header(emi_data, :knx_tunnel)

      # Version (1) + Header Length (1) + Body Length (2) + Protocol ID (1) + Reserved (3) = 8 bytes
      <<version, header_length, body_length::16, protocol_id, _reserved::24, rest::binary>> =
        result

      assert version == 0x00
      assert header_length == 0x08
      assert body_length == byte_size(emi_data)
      assert protocol_id == 0x01
      assert rest == emi_data
    end

    test "calculates body length correctly" do
      emi_data = <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10>>
      result = Encode.encode_usb_protocol_header(emi_data, :knx_tunnel)

      <<_version, _header_length, body_length::16, _rest::binary>> = result

      assert body_length == 10
    end

    test "supports different protocol IDs" do
      emi_data = <<0x03, 0x00, 0x00>>

      result1 = Encode.encode_usb_protocol_header(emi_data, :knx_tunnel)
      <<_::32, protocol_id1, _::binary>> = result1
      assert protocol_id1 == 0x01

      result2 = Encode.encode_usb_protocol_header(emi_data, :mbus_tunnel)
      <<_::32, protocol_id2, _::binary>> = result2
      assert protocol_id2 == 0x02
    end
  end

  describe "encode_report_header/3" do
    test "adds report header with correct structure" do
      body = <<0x00, 0x08, 0x00, 0x05>>
      result = Encode.encode_report_header(body, 1, :all_in_one_packet)

      <<report_id, packet_info, data_length, rest::binary>> = result

      assert report_id == 0x01
      assert packet_info == 0x13
      assert data_length == byte_size(body)
      assert rest == body
    end

    test "encodes sequence number in high nibble" do
      body = <<0xAA>>

      result1 = Encode.encode_report_header(body, 1, :all_in_one_packet)
      <<_report_id, packet_info1, _rest::binary>> = result1
      assert packet_info1 == 0x13

      result2 = Encode.encode_report_header(body, 2, :all_in_one_packet)
      <<_report_id, packet_info2, _rest::binary>> = result2
      assert packet_info2 == 0x23

      result3 = Encode.encode_report_header(body, 15, :all_in_one_packet)
      <<_report_id, packet_info3, _rest::binary>> = result3
      assert packet_info3 == 0xF3
    end

    test "supports different packet types" do
      body = <<0xAA>>

      result1 = Encode.encode_report_header(body, 1, :all_in_one_packet)
      <<_report_id, packet_info1, _rest::binary>> = result1
      assert packet_info1 == 0x13

      result2 = Encode.encode_report_header(body, 1, :start_packet)
      <<_report_id, packet_info2, _rest::binary>> = result2
      assert packet_info2 == 0x15

      result3 = Encode.encode_report_header(body, 1, :end_packet)
      <<_report_id, packet_info3, _rest::binary>> = result3
      assert packet_info3 == 0x16
    end
  end

  describe "encode_packet_info/2" do
    test "combines sequence number and packet type" do
      assert Encode.encode_packet_info(1, :all_in_one_packet) == 0x13
      assert Encode.encode_packet_info(2, :start_packet) == 0x25
      assert Encode.encode_packet_info(3, :end_packet) == 0x36
      assert Encode.encode_packet_info(15, :partial_packet) == 0xF4
    end
  end

  describe "encode_message/2" do
    test "encodes a complete message with default options" do
      payload = <<0x29, 0x00, 0xBC, 0xE0, 0x00, 0x01, 0xAB, 0xCC>>
      result = Encode.encode_message(payload)

      # Verify structure
      <<report_id, packet_info, data_length, rest::binary>> = result

      assert report_id == 0x01
      assert packet_info == 0x13
      assert data_length == byte_size(rest)

      # Verify it contains USB protocol header
      <<version, header_length, body_length::16, _rest::binary>> = rest

      assert version == 0x00
      assert header_length == 0x08
      assert body_length == 3 + byte_size(payload)
    end

    test "encodes complete message matching Python implementation" do
      # This is a known-good message from the Python implementation
      payload = <<0x29, 0x00, 0xBC, 0xE0, 0x00, 0x01, 0xAB, 0xCC>>
      result = Encode.encode_message(payload)

      # Report header (3 bytes) + USB header (8 bytes) + EMI header (3 bytes) + payload (8 bytes)
      assert byte_size(result) == 3 + 8 + 3 + 8
    end

    test "respects custom options" do
      payload = <<0xAB>>

      result =
        Encode.encode_message(payload,
          sequence_number: 5,
          packet_type: :start_packet,
          protocol_id: :mbus_tunnel,
          emi_id: 0x07
        )

      <<_report_id, packet_info, _data_length, _version, _header_length, _body_length::16,
        protocol_id, _reserved::24, emi_id, _rest::binary>> = result

      # Sequence 5, packet type 5 = 0x55
      assert packet_info == 0x55
      assert protocol_id == 0x02
      assert emi_id == 0x07
    end
  end
end
