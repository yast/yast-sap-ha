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
require_relative 'base_config'

Yast.import 'NtpClient'
Yast.import 'Progress'

module SapHA
  module Configuration
    # Cluster members configuration
    class NTP < BaseConfig
      attr_reader :used_servers

      def initialize(global_config)
        super
        log.debug "--- #{self.class}.#{__callee__} ---"
        @screen_name = "NTP Configuration"
        log.info "--- #{self.class}.#{__callee__} ---"
        read_configuration
      end

      def read_configuration
        log.info "--- #{self.class}.#{__callee__} ---"
        progress = Yast::Progress.set(false)
        Yast::NtpClient.Read
        Yast::Progress.set(progress)
        @config = Yast::NtpClient.Export
        @ntpd_cron = Yast::NtpClient.ReadSynchronization
        @used_servers = Yast::NtpClient.GetUsedNtpServers
      end

      def configured?
        (start_at_boot? || @ntpd_cron) && !@used_servers.empty?
      end

      def validate(verbosity = :verbose)
        if verbosity == :verbose
          return ["Every node has to sync with at least one NTP server."] unless configured?
          return []
        else
          return configured?
        end
      end

      def description
        prepare_description do |dsc|
          dsc.parameter('Synchronize with servers', @used_servers.join(', '))
          dsc.parameter('Start at boot', start_at_boot?)
        end
      end

      def start_at_boot?
        @config["ntp_sync"] == 'systemd'
      end

      def apply(role)
        return false unless configured?
        # Master has the configuration in place already
        @nlog.info('Appying NTP Configuration')
        return true if role == :master
        Yast::NtpClient.Import @config
        stat = Yast::NtpClient.Write
        @nlog.log_status(stat,
          "Wrote NTP configuration",
          "Could not write NTP configuration")
        stat
      end
    end
  end
end
