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

require 'yast'
require 'sap_ha_system/cluster'

module Yast
  class SAPHAClusterClass < Client
    Yast.import 'Wizard'
    Yast.import 'Progress'

    def main
      cluster = SAPHACluster.instance
      Wizard.CreateDialog
      Progress.New(
        'SAP HA Configuration',
        '',
        4,
        [
          'SSH Server',
          'SUSEFirewall',
          'NTP Service',
          'Watchdog'
        ],
        [
          _('Starting SSH Server'),
          _('Adjusting SUSEFirewall rules'),
          _('Checking the Network Time Protocol Service'),
          _('Checking the Watchdog configuration')
        ],
        ""
      )
      sleep(2)
      Progress.NextStage
      # SSH Server
      sleep(2)
      Progress.NextStage if cluster.configure_sshd
      # Firewall
      sleep(2)
      Progress.NextStage if cluster.configure_firewall
      # NTP
      sleep(2)
      Progress.NextStage if cluster.ntp_configured?
      # Watchdog
      sleep(2)
      Progress.NextStage if cluster.watchdog_configured?
      # Finish
      sleep(2)
      Wizard.CloseDialog
    end
  end

  SAPHACluster = SAPHAClusterClass.new.main
end
