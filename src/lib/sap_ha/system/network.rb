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
# Summary: SUSE High Availability Setup for SAP Products: Network configuration
# Authors: Ilya Manyugin <ilya.manyugin@suse.com>

require 'yast'
require 'socket'
require 'ipaddr'

Yast.import 'NetworkInterfaces'
Yast.import 'Netmask'

module SapHA
  module System
    # Network configuration
    class NetworkClass
      include Singleton

      # Get a list of all interfaces on the current node
      def interfaces
        Yast::NetworkInterfaces.Read
        Yast::NetworkInterfaces.List("")
      end

      # Get local machine's IPv4 addresses excluding the loopback iface
      def ip_addresses
        interfaces = Socket.getifaddrs.select do |iface|
          iface.addr && iface.addr.ipv4? && !iface.addr.ipv4_loopback?
        end
        interfaces.map { |iface| iface.addr.ip_address }
      end

      # Get a list of network addresses on the local node's interface
      def network_addresses
        interfaces = Socket.getifaddrs.select do |iface|
	  iface.addr && iface.addr.ipv4? && !iface.addr.ipv4_loopback?
        end
        interfaces.map do |iface|
          IPAddr.new(iface.addr.ip_address).mask(iface.netmask.ip_address).to_s
        end
      end

      # Get a list of network addresses along with the CIDR mask
      def network_addresses_cidr
        interfaces = Socket.getifaddrs.select do |iface|
          iface.addr && iface.addr.ipv4? && !iface.addr.ipv4_loopback?
        end
        interfaces.map do |iface|
          IPAddr.new(iface.addr.ip_address).mask(iface.netmask.ip_address).to_s + '/' +
            IPAddr.new(iface.netmask.ip_address).to_i.to_s(2).count('1').to_s
        end
      end

      def hostname
        Socket.gethostname
      end

      def netmask_to_cidr(mask)
        Yast::Netmask.ToBits(mask)
      end

      def cidr_to_netmask(cidr)
        # IPAddr.new('255.255.255.255').mask(cidr).to_s
        Yast::Netmask.FromBits(cidr)
      end
    end

    Network = NetworkClass.instance
  end
end
