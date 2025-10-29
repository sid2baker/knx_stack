defmodule KNXStack.USBHID.Protocol do
  @moduledoc """
  KNX USB HID protocol definitions, constants, and types.

  Defines the core protocol elements used in USB HID communication with KNX devices,
  including packet types, protocol identifiers, service identifiers, and feature identifiers.
  """

  # Report Header Constants
  @knx_data_exchange 0x01

  # Protocol Header Constants
  @knx_usb_transfer_protocol 0x00
  @knx_usb_transfer_protocol_header_length 0x08

  # Packet Types (report_header/packet_info)
  @type packet_type ::
          :reserved
          | :all_in_one_packet
          | :partial_packet
          | :start_packet
          | :end_packet

  # Protocol IDs (report_body/usb_protocol_header)
  @type protocol_id ::
          :reserved
          | :knx_tunnel
          | :mbus_tunnel
          | :batibus_tunnel
          | :bus_access_server_feature_service

  # Service IDs (bus_access_server_feature)
  @type service_id ::
          :reserved
          | :device_feature_get
          | :device_feature_response
          | :device_feature_set
          | :device_feature_info

  # Feature IDs (bus_access_server_feature)
  @type feature_id ::
          :supported_emi_type
          | :host_device_descriptor_type
          | :bus_connection_status
          | :knx_manufacturer_code
          | :active_emi_type

  @doc "KNX Data Exchange report identifier constant"
  def knx_data_exchange, do: @knx_data_exchange

  @doc "KNX USB Transfer Protocol version"
  def knx_usb_transfer_protocol, do: @knx_usb_transfer_protocol

  @doc "KNX USB Transfer Protocol header length"
  def knx_usb_transfer_protocol_header_length, do: @knx_usb_transfer_protocol_header_length

  @doc """
  Converts a packet type atom to its byte value.

  ## Examples

      iex> KNXStack.USBHID.Protocol.packet_type_to_byte(:all_in_one_packet)
      0x03

      iex> KNXStack.USBHID.Protocol.packet_type_to_byte(:start_packet)
      0x05
  """
  @spec packet_type_to_byte(packet_type()) :: byte()
  def packet_type_to_byte(:reserved), do: 0x00
  def packet_type_to_byte(:all_in_one_packet), do: 0x03
  def packet_type_to_byte(:partial_packet), do: 0x04
  def packet_type_to_byte(:start_packet), do: 0x05
  def packet_type_to_byte(:end_packet), do: 0x06

  @doc """
  Converts a byte value to its packet type atom.

  ## Examples

      iex> KNXStack.USBHID.Protocol.byte_to_packet_type(0x03)
      {:ok, :all_in_one_packet}

      iex> KNXStack.USBHID.Protocol.byte_to_packet_type(0xFF)
      {:error, :unknown_packet_type}
  """
  @spec byte_to_packet_type(byte()) :: {:ok, packet_type()} | {:error, :unknown_packet_type}
  def byte_to_packet_type(0x00), do: {:ok, :reserved}
  def byte_to_packet_type(0x03), do: {:ok, :all_in_one_packet}
  def byte_to_packet_type(0x04), do: {:ok, :partial_packet}
  def byte_to_packet_type(0x05), do: {:ok, :start_packet}
  def byte_to_packet_type(0x06), do: {:ok, :end_packet}
  def byte_to_packet_type(_), do: {:error, :unknown_packet_type}

  @doc """
  Converts a protocol ID atom to its byte value.

  ## Examples

      iex> KNXStack.USBHID.Protocol.protocol_id_to_byte(:knx_tunnel)
      0x01
  """
  @spec protocol_id_to_byte(protocol_id()) :: byte()
  def protocol_id_to_byte(:reserved), do: 0x00
  def protocol_id_to_byte(:knx_tunnel), do: 0x01
  def protocol_id_to_byte(:mbus_tunnel), do: 0x02
  def protocol_id_to_byte(:batibus_tunnel), do: 0x03
  def protocol_id_to_byte(:bus_access_server_feature_service), do: 0x0F

  @doc """
  Converts a byte value to its protocol ID atom.

  ## Examples

      iex> KNXStack.USBHID.Protocol.byte_to_protocol_id(0x01)
      {:ok, :knx_tunnel}
  """
  @spec byte_to_protocol_id(byte()) :: {:ok, protocol_id()} | {:error, :unknown_protocol_id}
  def byte_to_protocol_id(0x00), do: {:ok, :reserved}
  def byte_to_protocol_id(0x01), do: {:ok, :knx_tunnel}
  def byte_to_protocol_id(0x02), do: {:ok, :mbus_tunnel}
  def byte_to_protocol_id(0x03), do: {:ok, :batibus_tunnel}
  def byte_to_protocol_id(0x0F), do: {:ok, :bus_access_server_feature_service}
  def byte_to_protocol_id(_), do: {:error, :unknown_protocol_id}

  @doc """
  Converts a service ID atom to its byte value.

  ## Examples

      iex> KNXStack.USBHID.Protocol.service_id_to_byte(:device_feature_get)
      0x01
  """
  @spec service_id_to_byte(service_id()) :: byte()
  def service_id_to_byte(:reserved), do: 0x00
  def service_id_to_byte(:device_feature_get), do: 0x01
  def service_id_to_byte(:device_feature_response), do: 0x02
  def service_id_to_byte(:device_feature_set), do: 0x03
  def service_id_to_byte(:device_feature_info), do: 0x04

  @doc """
  Converts a byte value to its service ID atom.

  ## Examples

      iex> KNXStack.USBHID.Protocol.byte_to_service_id(0x01)
      {:ok, :device_feature_get}
  """
  @spec byte_to_service_id(byte()) :: {:ok, service_id()} | {:error, :unknown_service_id}
  def byte_to_service_id(0x00), do: {:ok, :reserved}
  def byte_to_service_id(0x01), do: {:ok, :device_feature_get}
  def byte_to_service_id(0x02), do: {:ok, :device_feature_response}
  def byte_to_service_id(0x03), do: {:ok, :device_feature_set}
  def byte_to_service_id(0x04), do: {:ok, :device_feature_info}
  def byte_to_service_id(_), do: {:error, :unknown_service_id}

  @doc """
  Converts a feature ID atom to its byte value.

  ## Examples

      iex> KNXStack.USBHID.Protocol.feature_id_to_byte(:active_emi_type)
      0x05
  """
  @spec feature_id_to_byte(feature_id()) :: byte()
  def feature_id_to_byte(:supported_emi_type), do: 0x01
  def feature_id_to_byte(:host_device_descriptor_type), do: 0x02
  def feature_id_to_byte(:bus_connection_status), do: 0x03
  def feature_id_to_byte(:knx_manufacturer_code), do: 0x04
  def feature_id_to_byte(:active_emi_type), do: 0x05

  @doc """
  Converts a byte value to its feature ID atom.

  ## Examples

      iex> KNXStack.USBHID.Protocol.byte_to_feature_id(0x05)
      {:ok, :active_emi_type}
  """
  @spec byte_to_feature_id(byte()) :: {:ok, feature_id()} | {:error, :unknown_feature_id}
  def byte_to_feature_id(0x01), do: {:ok, :supported_emi_type}
  def byte_to_feature_id(0x02), do: {:ok, :host_device_descriptor_type}
  def byte_to_feature_id(0x03), do: {:ok, :bus_connection_status}
  def byte_to_feature_id(0x04), do: {:ok, :knx_manufacturer_code}
  def byte_to_feature_id(0x05), do: {:ok, :active_emi_type}
  def byte_to_feature_id(_), do: {:error, :unknown_feature_id}
end
