defmodule KNXStack.USBHIDTest do
  use ExUnit.Case, async: true

  alias KNXStack.USBHID

  doctest USBHID

  describe "encode/2" do
    test "encodes a payload with default options" do
      payload = <<0x29, 0x00, 0xBC>>
      encoded = USBHID.encode(payload)

      # Verify it starts with correct report identifier
      <<report_id, _rest::binary>> = encoded
      assert report_id == 0x01

      # Verify structure: report header (3) + USB header (8) + EMI header (3) + payload
      assert byte_size(encoded) == 3 + 8 + 3 + byte_size(payload)
    end

    test "respects custom encoding options" do
      payload = <<0xAB>>

      encoded =
        USBHID.encode(payload,
          sequence_number: 7,
          packet_type: :end_packet,
          protocol_id: :batibus_tunnel,
          emi_id: 0x09
        )

      {:ok, decoded} = USBHID.decode(encoded)

      assert decoded.sequence_number == 7
      assert decoded.packet_type == :end_packet
      assert decoded.protocol_id == :batibus_tunnel
      assert decoded.emi_id == 0x09
      assert decoded.payload == payload
    end
  end

  describe "decode/1" do
    test "decodes a valid USB HID message" do
      # Known-good message from Python implementation
      data =
        <<0x01, 0x13, 0x13, 0x00, 0x08, 0x00, 0x0B, 0x01, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00,
          0x29, 0x00, 0xBC, 0xE0, 0x00, 0x01, 0xAB, 0xCC>>

      {:ok, decoded} = USBHID.decode(data)

      assert decoded.report_id == 0x01
      assert decoded.sequence_number == 1
      assert decoded.packet_type == :all_in_one_packet
      assert decoded.protocol_id == :knx_tunnel
      assert decoded.emi_id == 0x03
      assert decoded.payload == <<0x29, 0x00, 0xBC, 0xE0, 0x00, 0x01, 0xAB, 0xCC>>
    end

    test "returns error for invalid data" do
      assert {:error, :invalid_report_identifier} = USBHID.decode(<<0x02>>)
      assert {:error, :insufficient_data} = USBHID.decode(<<0x01, 0x13>>)
    end
  end

  describe "extract_payload/1" do
    test "extracts just the payload from a message" do
      data =
        <<0x01, 0x13, 0x13, 0x00, 0x08, 0x00, 0x0B, 0x01, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00,
          0x29, 0x00, 0xBC, 0xE0, 0x00, 0x01, 0xAB, 0xCC>>

      assert {:ok, <<0x29, 0x00, 0xBC, 0xE0, 0x00, 0x01, 0xAB, 0xCC>>} =
               USBHID.extract_payload(data)
    end
  end

  describe "round-trip encode/decode" do
    test "payload survives encode/decode round-trip" do
      original_payload = <<0x29, 0x00, 0xBC, 0xE0, 0x00, 0x01, 0xAB, 0xCC>>

      encoded = USBHID.encode(original_payload)
      {:ok, decoded} = USBHID.decode(encoded)

      assert decoded.payload == original_payload
    end

    test "round-trip preserves all options" do
      payload = <<1, 2, 3, 4, 5>>

      opts = [
        sequence_number: 3,
        packet_type: :partial_packet,
        protocol_id: :mbus_tunnel,
        emi_id: 0x07
      ]

      encoded = USBHID.encode(payload, opts)
      {:ok, decoded} = USBHID.decode(encoded)

      assert decoded.sequence_number == 3
      assert decoded.packet_type == :partial_packet
      assert decoded.protocol_id == :mbus_tunnel
      assert decoded.emi_id == 0x07
      assert decoded.payload == payload
    end

    test "round-trip works with empty payload" do
      payload = <<>>

      encoded = USBHID.encode(payload)
      {:ok, decoded} = USBHID.decode(encoded)

      assert decoded.payload == <<>>
    end

    test "round-trip works with large payload" do
      payload = :crypto.strong_rand_bytes(256)

      encoded = USBHID.encode(payload)
      {:ok, decoded} = USBHID.decode(encoded)

      assert decoded.payload == payload
    end

    test "round-trip with all packet types" do
      payload = <<0xAB, 0xCD>>

      for packet_type <- [
            :all_in_one_packet,
            :partial_packet,
            :start_packet,
            :end_packet
          ] do
        encoded = USBHID.encode(payload, packet_type: packet_type)
        {:ok, decoded} = USBHID.decode(encoded)

        assert decoded.packet_type == packet_type
        assert decoded.payload == payload
      end
    end

    test "round-trip with all protocol IDs" do
      payload = <<0x12, 0x34>>

      for protocol_id <- [
            :knx_tunnel,
            :mbus_tunnel,
            :batibus_tunnel,
            :bus_access_server_feature_service
          ] do
        encoded = USBHID.encode(payload, protocol_id: protocol_id)
        {:ok, decoded} = USBHID.decode(encoded)

        assert decoded.protocol_id == protocol_id
        assert decoded.payload == payload
      end
    end

    test "round-trip with various sequence numbers" do
      payload = <<0xFF>>

      for seq <- 0..15 do
        encoded = USBHID.encode(payload, sequence_number: seq)
        {:ok, decoded} = USBHID.decode(encoded)

        assert decoded.sequence_number == seq
        assert decoded.payload == payload
      end
    end
  end

  describe "protocol constants" do
    test "exposes protocol constants" do
      assert USBHID.knx_data_exchange() == 0x01
      assert USBHID.knx_usb_transfer_protocol() == 0x00
      assert USBHID.knx_usb_transfer_protocol_header_length() == 0x08
    end
  end

  describe "compatibility with Python implementation" do
    test "decodes Python-generated message correctly" do
      # This hex string is from the Python implementation doctest:
      # >>> msg = knx_stack.Msg.make_from_str("0113130008000B010300002900BCE00001ABCC010081")
      hex_string = "0113130008000B010300002900BCE00001ABCC010081"
      data = Base.decode16!(hex_string, case: :mixed)

      {:ok, decoded} = USBHID.decode(data)

      assert decoded.sequence_number == 1
      assert decoded.packet_type == :all_in_one_packet
      assert decoded.protocol_id == :knx_tunnel
      assert decoded.emi_id == 0x03

      # The payload should be everything after the headers
      expected_payload = <<0x29, 0x00, 0xBC, 0xE0, 0x00, 0x01, 0xAB, 0xCC>>
      assert decoded.payload == expected_payload
    end

    test "generates message compatible with Python format" do
      payload = <<0x29, 0x00, 0xBC, 0xE0, 0x00, 0x01, 0xAB, 0xCC>>

      encoded = USBHID.encode(payload)

      # Verify structure matches Python implementation
      <<report_id, packet_info, data_length, protocol_version, header_length, body_length::16,
        protocol_id, _reserved::24, emi_id, _emi_reserved::16, actual_payload::binary>> = encoded

      assert report_id == 0x01
      assert packet_info == 0x13
      assert protocol_version == 0x00
      assert header_length == 0x08
      assert protocol_id == 0x01
      assert emi_id == 0x03
      assert actual_payload == payload

      # Body length should equal EMI header (3 bytes) + payload length
      assert body_length == 3 + byte_size(payload)

      # Data length should equal USB header (8 bytes) + body length
      assert data_length == 8 + body_length
    end
  end
end
