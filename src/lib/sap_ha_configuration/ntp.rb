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
# Summary: SUSE High Availability Setup for SAP Products: Cluster members configuration
# Authors: Ilya Manyugin <ilya.manyugin@suse.com>

require 'yast'
require 'erb'
require 'socket'
require_relative 'base_component_configuration.rb'

Yast.import 'NtpClient'


module Yast
  # Cluster members configuration
  class NTPConfiguration < BaseComponentConfiguration
    attr_reader :used_servers
    def initialize
      log.info "--- #{self.class}.#{__callee__} ---"
      read_configuration
    end

    def read_configuration
      log.info "--- #{self.class}.#{__callee__} ---"
      NtpClient.Read
      @config = NtpClient.Export
      @ntpd_cron = NtpClient.ReadSynchronization
      @used_servers = NtpClient.GetUsedNtpServers
    end

    def configured?
      (start_at_boot? || @ntpd_cron) && !@used_servers.empty?
    end

    def description
      s = @used_servers.join(', ')
      "&nbsp;Synchronize with servers: #{s}.<br>&nbsp;Start at boot: #{start_at_boot?}."
    end

    def start_at_boot?
      @config["start_at_boot"]
    end
  end
end


# require 'yast'; Yast.import 'NtpClient'; Yast::NtpClient.Read; Yast::NtpClient.GetUsedNtpServers
