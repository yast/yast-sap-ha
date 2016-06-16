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
require 'sap_ha/gui'
require 'sap_ha_wizard/cluster_page'
require 'sap_ha_wizard/join_cluster_page'
require 'sap_ha_wizard/fencing_page'
require 'sap_ha_wizard/watchdog_page'
require 'sap_ha_wizard/hana_page'
require 'sap_ha_wizard/ntp_page'
require 'sap_ha_wizard/overview_page'
require 'sap_ha_wizard/summary_page'
require 'sap_ha_wizard/gui_installation_page'
require 'sap_ha/configuration'

# YaST module
module Yast
  # Main client class
  class SAPHAClass < Client
    attr_reader :sequence

    Yast.import 'UI'
    Yast.import 'Wizard'
    Yast.import 'Sequencer'
    include Yast::UIShortcuts
    include Yast::Logger

    def initialize
      log.warn "--- called #{self.class}.#{__callee__}: CLI arguments are #{WFM.Args} ---"
      @config = Configuration.new
      @config.debug = WFM.Args.include? 'debug'
      @config.no_validators = WFM.Args.include?('noval') || WFM.Args.include?('validators')
      @bogus = WFM.Args.include?('bogus')
      Wizard.SetTitleIcon('yast-heartbeat')
      @sequence = {
        "ws_start"              => "product_check",
        "product_check"         =>  {
          abort:             :abort,
          hana:              "scenario_selection",
          nw:                "scenario_selection",
          unknown:           "product_not_supported",
          next:              "product_not_supported"
        },
        "scenario_selection"    => {
          abort:             :abort,
          cancel:            :abort,
          next:              "configure_cluster",
          unknown:           "product_not_supported",
          summary:           "config_overview"
        },
        "config_overview"         => {
          abort:             :abort,
          cancel:            :abort,
          config_cluster:    "configure_cluster",
          join_cluster:      "join_cluster",
          fencing:           "fencing",
          watchdog:          "watchdog",
          hana:              "hana",
          ntp:               "ntp",
          next:              "installation",
          back:              :back
        },
        "scenario_setup"        => {
          abort:             :abort,
          cancel:            :abort,
          next:              :next,
          summary:           "config_overview"
        },
        "configure_cluster"    => {
          next:              "ntp",
          back:              :back,
          abort:             :abort,
          cancel:            :abort,
          summary:           "config_overview"
        },
        "join_cluster"          => {
          next:              "configure_cluster",
          back:              :back,
          abort:             :abort,
          cancel:            :abort,
          summary:           "config_overview"
        },
        "fencing"               => {
          next:              "watchdog",
          back:              :back,
          abort:             :abort,
          cancel:            :abort,
          summary:           "config_overview"
        },
        "watchdog"              => {
          next:              "hana",
          back:              :back,
          abort:             :abort,
          cancel:            :abort,
          summary:           "config_overview"
        },
        "hana"                  => {
          next:              "config_overview",
          back:              :back,
          abort:             :abort,
          cancel:            :abort,
          summary:           "config_overview"
        },
        "ntp"                   => {
          next:              "fencing",
          back:              :back,
          abort:             :abort,
          cancel:            :abort,
          summary:           "config_overview"
        },
        "debug_run"             => {
          config_overview:   "config_overview"
        },
        "installation"          => {
          next:              "summary",
          summary:           "summary",
          abort:             :abort,
          cancel:            :abort,
          back:              :back
        },
        "summary"               => {
          abort:             :abort,
          cancel:            :abort,
          back:              :back,
          next:              :ws_finish
        }
      }
      @aliases = {
        'product_check'         => -> { product_check },
        'scenario_selection'    => -> { scenario_selection },
        'product_not_supported' => -> { product_not_supported },
        'configure_cluster'     => -> { configure_cluster },
        'config_overview'       => -> { configuration_overview },
        'scenario_setup'        => -> { scenario_setup },
        'join_cluster'          => -> { join_existing_cluster },
        'fencing'               => -> { fencing_mechanism },
        'watchdog'              => -> { watchdog },
        'hana'                  => -> { configure_hana },
        'debug_run'             => -> { debug_run },
        'installation'          => -> { run_installation },
        'ntp'                   => -> { configure_ntp },
        'summary'               => -> { show_summary }
      }
    end

    def main
      textdomain 'sap-ha'
      @sequence["ws_start"] = "debug_run" if @config.debug
      Wizard.CreateDialog
      Wizard.SetDialogTitle("HA Setup for SAP Products")
      begin
        ret = Sequencer.Run(@aliases, @sequence)
        log.error "Sequencer finished with #{ret}"
      ensure
        Wizard.CloseDialog
      end
    end

    # Check the product ID. If it is unknown, show the bye-bye message.
    def product_check
      log.debug "--- called #{self.class}.#{__callee__} ---"
      # TODO: here we need to know what product we are installing
      # SAPProducts.Read
      # SAPProducts.Installed [{productID: 'HANA'...}...]
      begin
        @config.set_product_id "HANA"
      rescue ProductNotFoundException => e
        log.error e.message
        return :unknown
      end
      # TODO: here we should check if the symbol can be handled by the Sequencer
      @config.product.fetch('id', 'abort').downcase.to_sym
    end

    def scenario_selection
      log.debug "--- called #{self.class}.#{__callee__} ---"
      scenarios = @config.all_scenarios
      help = @config.scenarios_help
      SAPHAGUI.list_selection(
        "Scenario selection for #{@config.product_name}",
        "An #{@config.product_name} installation was detected. Select one of the high-avaliability "\
        "scenarios from the list below:",
        scenarios,
        help,
        false,
        true
      )
      selection = UI.UserInput()
      case selection
      when :next
        begin
          @config.set_scenario_name(UI.QueryWidget(:selection_box, :Value))
        rescue ScenarioNotFoundException
          return :unknown
        end
      when :abort
        return :abort
      end
      set_bogus_values if @bogus
      selection
    end

    def product_not_supported
      log.debug "--- called #{self.class}.#{__callee__} ---"
      SAPHAGUI.richt_text(
        'Product not supported',
        SAPHAHelpers.instance.load_help('product_not_found'),
        SAPHAHelpers.instance.load_help('product_not_found'),
        false,
        false
      )
      log.error("No HA scenarios found for product #{@product_name}")
      UI.UserInput()
      :abort
    end

    def scenarios_not_found
      log.debug "--- called #{self.class}.#{__callee__} ---"
      SAPHAGUI.richt_text(
        'Scenarios not found',
        "There were no HA scenarios found for the product #{@product_name}",
        "The product you are installing is not supported by this module.<br>You can set up a cluster manually using the Cluster YaST module.",
        false,
        false
      )
      log.error("No HA scenarios found for product #{@product_name}")
      UI.UserInput()
      :abort
    end    

    def scenario_setup
      log.debug "--- called #{self.class}.#{__callee__} ---"
      SAPHAGUI.richt_text(
        "HA Setup: #{@product_name} - #{@scenario_name}",
        "Here we install the product #{@product_name} with scenario #{@scenario_name}",
        'Here is help for the scenario',
        true,
        true
      )
      UI.UserInput()
    end

    def configuration_overview
      log.debug "--- called #{self.class}.#{__callee__} ---"
      ret = ConfigurationOverviewPage.new(@config).run
      log.error "--- #{self.class}.#{__callee__}: return=#{ret.inspect} ---"
      return :abort if ret == :back # TODO: find out why it returns "back"
      ret
    end

    def configure_cluster
      log.debug "--- called #{self.class}.#{__callee__} ---"
      ClusterConfigurationPage.new(@config).run
    end

    def join_existing_cluster
      log.debug "--- called #{self.class}.#{__callee__} ---"
      JoinClusterPage.new(@config).run
    end

    def fencing_mechanism
      log.debug "--- called #{self.class}.#{__callee__} ---"
      FencingConfigurationPage.new(@config).run
    end

    def watchdog
      log.debug "--- called #{self.class}.#{__callee__} ---"
      WatchdogConfigurationPage.new(@config).run
    end

    def configure_hana
      log.debug "--- called #{self.class}.#{__callee__} ---"
      HANAConfigurationPage.new(@config).run
    end

    def configure_ntp
      log.debug "--- called #{self.class}.#{__callee__} ---"
      return NTPConfigurationPage.new(@config).run
    end

    def run_installation
      log.debug "--- called #{self.class}.#{__callee__} ---"
      return :next if WFM.Args.include? 'noinst'
      ui = GUIInstallationPage.new
      SAPHAInstallation.new(@config, ui).run
    end

    def show_summary
      log.debug "--- called #{self.class}.#{__callee__} ---"
      if WFM.Args.include? 'noinst'
        @config.logs = [
          '[hana01] 2016-06-15 14:51:14 INFO: Starting setup process on node hana01',
          '[hana01] 2016-06-15 14:51:14 INFO: Applying Cluster Configuration',
          '[hana01] 2016-06-15 14:51:20 INFO: Wrote cluster settings',
          '[hana01] 2016-06-15 14:51:20 INFO: Enabled service csync2',
          '[hana01] 2016-06-15 14:51:20 INFO: Enabled service pacemaker',
          '[hana01] 2016-06-15 14:51:21 INFO: Started service pacemaker',
          '[hana01] 2016-06-15 14:51:21 INFO: Enabled service hawk',
          '[hana01] 2016-06-15 14:51:22 INFO: Started service hawk',
          '[hana01] 2016-06-15 14:51:23 ERROR: Have done something stupid. The log is:',
          '[hana01] 2016-06-15 14:51:23 OUTPUT: Log line 1',
          '[hana01] 2016-06-15 14:51:23 OUTPUT: Log line 2',
          '[hana01] 2016-06-15 14:51:23 OUTPUT: Log line 3',
          '[hana01] 2016-06-15 14:51:22 WARN: Finished with errors'
        ].join("\n")
      end
      SetupSummaryPage.new(@config).run
    end

    def debug_run
      @config.set_product_id "HANA"
      @config.set_scenario_name 'Performance-optimized'
      set_bogus_values if @bogus
      :config_overview
    end

    def set_bogus_values
      # @config.set_product_id "HANA"
      # @config.set_scenario_name 'Performance-optimized'
      @config.cluster.import(
        number_of_rings: 2,
        transport_mode: :unicast,
        cluster_name: 'hana_sysrep',
        expected_votes: 2,
        rings: {
          ring1: {
            address:  '192.168.101.0',
            port:     '5405',
            id:       1,
            mcast:    ''
          },
          ring2: {
            address:  '192.168.103.0',
            port:     '5405',
            id:       2,
            mcast:    ''
          }
        }
      )
      @config.cluster.import(
        number_of_rings: 2,
        number_of_nodes: 2,
        nodes: {
          node1: {
            host_name:  "hana01",
            ip_ring1:   "192.168.101.21",
            ip_ring2:   "192.168.103.21",
            ip_ring3:   "",
            node_id:    '1'
          },
          node2: {
            host_name:  "hana02",
            ip_ring1:   "192.168.101.22",
            ip_ring2:   "192.168.103.23",
            ip_ring3:   "",
            node_id:    '2'
          }
        }
      )
    @config.fencing.import(devices: [{name: '/dev/vdb', type: 'disk', uuid: ''}])
    @config.watchdog.import(to_install: ['softdog'])
    @config.hana.import(
      system_id: 'XXX',
      instance:  '05',
      virtual_ip: '192.168.101.100'
    )
    ntp_cfg = {"synchronize_time"=>false,
       "sync_interval"=>5,
       "start_at_boot"=>true,
       "start_in_chroot"=>false,
       "ntp_policy"=>"auto",
       "peers"=>
        [{"type"=>"server",
          "address"=>"ntp.local",
          "options"=>" iburst",
          "comment"=>"# key (6) for accessing server variables\n"}],
       "restricts"=>[]}
    Yast.import 'NtpClient'
    NtpClient.Import ntp_cfg
    NtpClient.Write
    @config.ntp.read_configuration
    end
  end

  SAPHA = SAPHAClass.new
  SAPHA.main

end
