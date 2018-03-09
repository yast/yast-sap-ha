# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2016 SUSE Linux GmbH, Nuernberg, Germany.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact SUSE Linux GmbH.
#
# ------------------------------------------------------------------------------
#
# Summary: SUSE High Availability Setup for SAP Products
# Authors: Ilya Manyugin <ilya.manyugin@suse.com>

require_relative '../../../../test_helper'
require 'sap_ha/system/network'

describe SapHA::System::Network do

  describe '#interfaces' do
    it 'returns the list of network interfaces on the local machine' do
      # It can happen that files under /etc/sysconfig/network are only accessible for root
      # Accept an empty list of interfaces for non-root user
      result = SapHA::System::Network.interfaces
      expect(result).not_to be_nil
      expect(result).not_to be_empty if user_root?
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
