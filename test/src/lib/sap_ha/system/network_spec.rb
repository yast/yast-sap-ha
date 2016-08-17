# -*- encoding: utf-8 -*-

require_relative '../../../../test_helper'
require 'sap_ha/system/network'

describe SapHA::System::Network do

  describe '#interfaces' do
    it 'returns the list of network interfaces on the local machine' do
      result = SapHA::System::Network.interfaces
      expect(result).not_to be_nil
      if user_root?
        expect(result).not_to be_empty
      else
        expect(result).to be_empty
      end
    end
  end

  describe '#ip_addresses' do
    it 'returns the list of IP addresses of the local machine' do
      result = SapHA::System::Network.ip_addresses
      expect(result).not_to be_nil
      expect(result).not_to be_empty unless build_service?
    end
  end

  describe '#network_addresses' do
    it 'returns the list of IP addresses of the networks' do
      result = SapHA::System::Network.network_addresses
      expect(result).not_to be_nil
      expect(result).not_to be_empty unless build_service?
    end
  end

  describe '#hostname' do
    it 'returns the host name of the machine' do
      result = SapHA::System::Network.hostname
      expect(result).not_to be_nil
      expect(result).not_to be_empty
    end
  end

end
