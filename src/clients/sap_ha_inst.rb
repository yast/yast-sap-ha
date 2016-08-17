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
# Summary: SUSE High Availability Setup for SAP Products: main GUI Wizard class
# Authors: Ilya Manyugin <ilya.manyugin@suse.com>

require 'yast'
require 'sap_ha/helpers'
require 'sap_ha/node_logger'
require 'sap_ha/wizard/gui_installation_page'
require 'sap_ha/configuration'

# YaST module
module Yast
  # Main client class
  class SAPHAClass < Client
    attr_reader :sequence

    Yast.import 'UI'
    Yast.import 'Wizard'
    Yast.import 'Sequencer'
    Yast.import 'Popup'
    include Yast::UIShortcuts
    include Yast::Logger
    include SapHA::Exceptions

    def initialize
      log.warn "--- called #{self.class}.#{__callee__}: CLI arguments are #{WFM.Args} ---"
      @config = SapHA::HAConfiguration.new
      @config.debug = WFM.Args.include? 'over'
      @config.no_validators = WFM.Args.include?('noval') || WFM.Args.include?('validators')
      @test = WFM.Args.include?('tst')
      Wizard.SetTitleIcon('yast-heartbeat')
    end

    def main
      Wizard.CreateDialog
      Wizard.SetDialogTitle("HA Setup for SAP Products")
      begin
        set_test_values
        ui = SapHA::Wizard::GUIInstallationPage.new(@config)
        external_interrupt(ui)
        ui.run
      ensure
        Wizard.CloseDialog
      end
    end

    def external_interrupt(ui)
      Thread.new do 
        sleep(3)
        
      end
    end

    def set_test_values
      @config.cluster.import(
        number_of_rings: 2,
        transport_mode:  :unicast,
        cluster_name:    'hana_sysrep',
        expected_votes:  2,
        rings:           {
          ring1: {
            address:         '192.168.101.0/24',
            port:            '5405',
            id:              1,
            mcast:           '',
            address_no_mask: '192.168.101.0'
          },
          ring2: {
            address:         '192.168.103.0/24',
            port:            '5405',
            id:              2,
            mcast:           '',
            address_no_mask: '192.168.103.0'
          }
        }
      )
      @config.cluster.import(
        number_of_rings: 2,
        number_of_nodes: 2,
        nodes:           {
          node1: {
            host_name: "hana01",
            ip_ring1:  "192.168.101.21",
            ip_ring2:  "192.168.103.21",
            node_id:   '1'
          },
          node2: {
            host_name: "hana02",
            ip_ring1:  "192.168.101.22",
            ip_ring2:  "192.168.103.22",
            node_id:   '2'
          }
        }
      )
      @config.fencing.import(devices: [{ name: '/dev/vdb', type: 'disk', uuid: '' }])
      @config.watchdog.import(to_install: ['softdog'])
      @config.hana.import(
        system_id:   'XXX',
        instance:    '00',
        virtual_ip:  '192.168.101.100',
        backup_user: 'xxxadm'
      )
      ntp_cfg = {
        "synchronize_time" => false,
        "sync_interval"    => 5,
        "start_at_boot"    => true,
        "start_in_chroot"  => false,
        "ntp_policy"       => "auto",
        "restricts"        => [],
        "peers"            => [
          { "type"    => "server",
            "address" => "ntp.local",
            "options" => " iburst",
            "comment" => "# key (6) for accessing server variables\n"
          }
        ]
      }
      # Yast.import 'NtpClient'
      # NtpClient.Import ntp_cfg
      # NtpClient.Write
      @config.ntp.read_configuration
    end
    SAPHA = SAPHAClass.new
    SAPHA.main
  end
end
