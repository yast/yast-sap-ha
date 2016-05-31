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
# Summary: SUSE High Availability Setup for SAP Products: Cluster configuration
# Authors: Ilya Manyugin <ilya.manyugin@suse.com>

require 'yast'
require 'open3'
require_relative 'watchdog'

Yast.import 'Service'

module Yast
  class SAPHAClusterGUIWarningException < Exception
  end

  class SAPHAClusterGUIErrorException < Exception
  end

  class SAPHAClusterGUIFatalErrorException < SAPHAClusterGUIErrorException
  end

  # Class for cluster configuration
  class SAPHACluster
    include Singleton
    include Yast::Logger

    def initialize
    end

    # join an existing cluster
    def join_cluster(ip_address)
    end

    def check_status
      puts "NTP configured #{ntp_configured?}"
      puts "Watchdog configured #{watchdog_configured?}"
      puts "SSH configured #{configure_sshd}"
    end

    # private

    # Check prerequisites before procceeding
    def prereq
      configured = true
      unless ntp_configured?
        log.error "NTP is not configured on the system"
        configured &= false
      end
      unless watchdog_configured?
        log.error "Watchdog is not configured on the system"
        configured &= false
      end
      configured &= configure_sshd
      configured
    end

    def ntp_configured?
      ntp_service = SystemdService.find('ntpd')
      configured &= ntp_service.running? && ntp_service.enabled?
      unless configured
        log.warn "The NTP service is not running"
        if !WFM.ClientExists('ntp-client')
          raise SAPHAClusterGUIFatalErrorException,
            _('Could not find the ntp-client YaST module.
              Please configure the NTP service manually and rerun the module.')
        else
          WFM.CallFunction('ntp-client')
        end
        configured &= ntp_service.running? && ntp_service.enabled?
      end
      configured
    end

    def watchdog_configured?
      Watchdog.instance.any_loaded?
    end

    def configure_firewall
      # TODO: firewall configuration
      true
    end

    def configure_sshd
      ssh_service = SystemdService.find('sshd')
      unless ssh_service.enabled?
        log.info "Enabling the sshd service..."
        rc = ssh_service.enable
        unless rc
          log.error "Could not enable the sshd service"
          raise SAPHAClusterGUIFatalErrorException,
            "Could not enable the sshd service.\n
             Please check your configuration and/or reinstall the package."
        end
        rc = ssh_service.start
        unless rc
          log.error "Could not start the sshd service"
          raise SAPHAClusterGUIFatalErrorException,
            "Could not start the sshd service.\n
             Please  check your configuration and/or reinstall the package."
        end
      end
      true
    end
  end
end
