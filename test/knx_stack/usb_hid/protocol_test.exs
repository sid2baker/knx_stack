defmodule KNXStack.USBHID.ProtocolTest do
  use ExUnit.Case, async: true

  alias KNXStack.USBHID.Protocol

  doctest Protocol

  describe "packet_type conversions" do
    test "converts packet type atoms to bytes" do
      assert Protocol.packet_type_to_byte(:reserved) == 0x00
      assert Protocol.packet_type_to_byte(:all_in_one_packet) == 0x03
      assert Protocol.packet_type_to_byte(:partial_packet) == 0x04
      assert Protocol.packet_type_to_byte(:start_packet) == 0x05
      assert Protocol.packet_type_to_byte(:end_packet) == 0x06
    end

    test "converts bytes to packet type atoms" do
      assert Protocol.byte_to_packet_type(0x00) == {:ok, :reserved}
      assert Protocol.byte_to_packet_type(0x03) == {:ok, :all_in_one_packet}
      assert Protocol.byte_to_packet_type(0x04) == {:ok, :partial_packet}
      assert Protocol.byte_to_packet_type(0x05) == {:ok, :start_packet}
      assert Protocol.byte_to_packet_type(0x06) == {:ok, :end_packet}
    end

    test "returns error for unknown packet type" do
      assert Protocol.byte_to_packet_type(0xFF) == {:error, :unknown_packet_type}
      assert Protocol.byte_to_packet_type(0x01) == {:error, :unknown_packet_type}
    end
  end

  describe "protocol_id conversions" do
    test "converts protocol ID atoms to bytes" do
      assert Protocol.protocol_id_to_byte(:reserved) == 0x00
      assert Protocol.protocol_id_to_byte(:knx_tunnel) == 0x01
      assert Protocol.protocol_id_to_byte(:mbus_tunnel) == 0x02
      assert Protocol.protocol_id_to_byte(:batibus_tunnel) == 0x03
      assert Protocol.protocol_id_to_byte(:bus_access_server_feature_service) == 0x0F
    end

    test "converts bytes to protocol ID atoms" do
      assert Protocol.byte_to_protocol_id(0x00) == {:ok, :reserved}
      assert Protocol.byte_to_protocol_id(0x01) == {:ok, :knx_tunnel}
      assert Protocol.byte_to_protocol_id(0x02) == {:ok, :mbus_tunnel}
      assert Protocol.byte_to_protocol_id(0x03) == {:ok, :batibus_tunnel}
      assert Protocol.byte_to_protocol_id(0x0F) == {:ok, :bus_access_server_feature_service}
    end

    test "returns error for unknown protocol ID" do
      assert Protocol.byte_to_protocol_id(0xFF) == {:error, :unknown_protocol_id}
    end
  end

  describe "service_id conversions" do
    test "converts service ID atoms to bytes" do
      assert Protocol.service_id_to_byte(:reserved) == 0x00
      assert Protocol.service_id_to_byte(:device_feature_get) == 0x01
      assert Protocol.service_id_to_byte(:device_feature_response) == 0x02
      assert Protocol.service_id_to_byte(:device_feature_set) == 0x03
      assert Protocol.service_id_to_byte(:device_feature_info) == 0x04
    end

    test "converts bytes to service ID atoms" do
      assert Protocol.byte_to_service_id(0x00) == {:ok, :reserved}
      assert Protocol.byte_to_service_id(0x01) == {:ok, :device_feature_get}
      assert Protocol.byte_to_service_id(0x02) == {:ok, :device_feature_response}
      assert Protocol.byte_to_service_id(0x03) == {:ok, :device_feature_set}
      assert Protocol.byte_to_service_id(0x04) == {:ok, :device_feature_info}
    end

    test "returns error for unknown service ID" do
      assert Protocol.byte_to_service_id(0xFF) == {:error, :unknown_service_id}
    end
  end

  describe "feature_id conversions" do
    test "converts feature ID atoms to bytes" do
      assert Protocol.feature_id_to_byte(:supported_emi_type) == 0x01
      assert Protocol.feature_id_to_byte(:host_device_descriptor_type) == 0x02
      assert Protocol.feature_id_to_byte(:bus_connection_status) == 0x03
      assert Protocol.feature_id_to_byte(:knx_manufacturer_code) == 0x04
      assert Protocol.feature_id_to_byte(:active_emi_type) == 0x05
    end

    test "converts bytes to feature ID atoms" do
      assert Protocol.byte_to_feature_id(0x01) == {:ok, :supported_emi_type}
      assert Protocol.byte_to_feature_id(0x02) == {:ok, :host_device_descriptor_type}
      assert Protocol.byte_to_feature_id(0x03) == {:ok, :bus_connection_status}
      assert Protocol.byte_to_feature_id(0x04) == {:ok, :knx_manufacturer_code}
      assert Protocol.byte_to_feature_id(0x05) == {:ok, :active_emi_type}
    end

    test "returns error for unknown feature ID" do
      assert Protocol.byte_to_feature_id(0xFF) == {:error, :unknown_feature_id}
    end
  end

  describe "constants" do
    test "returns correct constant values" do
      assert Protocol.knx_data_exchange() == 0x01
      assert Protocol.knx_usb_transfer_protocol() == 0x00
      assert Protocol.knx_usb_transfer_protocol_header_length() == 0x08
    end
  end
end
