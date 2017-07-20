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
require 'sap_ha/wizard/cluster_nodes_page'
require 'sap_ha/wizard/comm_layer_page'
require 'sap_ha/wizard/join_cluster_page'
require 'sap_ha/wizard/fencing_page'
require 'sap_ha/wizard/watchdog_page'
require 'sap_ha/wizard/hana_page'
require 'sap_ha/wizard/ntp_page'
require 'sap_ha/wizard/overview_page'
require 'sap_ha/wizard/summary_page'
require 'sap_ha/wizard/gui_installation_page'
require 'sap_ha/wizard/list_selection'
require 'sap_ha/wizard/rich_text'
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
      if WFM.Args.include?('readconfig')
        ix = WFM.Args.index('readconfig') + 1
        @config = YAML.load(File.read(WFM.Args[ix]))
        @config.imported = true
      else
        @config = SapHA::HAConfiguration.new
      end
      @config.debug = WFM.Args.include? 'over'
      @config.no_validators = WFM.Args.include?('noval') || WFM.Args.include?('validators')
      @test = WFM.Args.include?('tst')
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
          next:              "prereqs_notice",
          unknown:           "product_not_supported",
          summary:           "config_overview"
        },
        "prereqs_notice"        => {
          abort:             :abort,
          cancel:            :abort,
          next:              "configure_comm_layer",
          summary:           "config_overview"
        },
        "config_overview"       => {
          abort:             :abort,
          cancel:            :abort,
          comm_layer:        "configure_comm_layer",
          config_cluster:    "configure_cluster",
          join_cluster:      "join_cluster",
          fencing:           "fencing",
          watchdog:          "watchdog",
          hana:              "hana",
          ntp:               "ntp",
          next:              "installation",
          back:              :back
        },
        "configure_cluster"    => {
          next:              "ntp",
          back:              :back,
          abort:             :abort,
          cancel:            :abort,
          summary:           "config_overview"
        },
        "configure_comm_layer" => {
          next:              "configure_cluster",
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
        # 'prereqs_notice'        => [-> () { show_prerequisites }, true],
        'prereqs_notice'        => -> { show_prerequisites },
        'configure_cluster'     => -> { configure_cluster },
        'configure_comm_layer'  => -> { configure_comm_layer },
        'join_cluster'          => -> { join_existing_cluster },
        'fencing'               => -> { fencing_mechanism },
        'watchdog'              => -> { watchdog },
        'hana'                  => -> { configure_hana },
        'debug_run'             => -> { debug_run },
        'installation'          => -> { run_installation },
        'ntp'                   => -> { configure_ntp },
        'config_overview'       => -> { configuration_overview },
        'summary'               => -> { show_summary }
      }
    end

    def main
      textdomain 'sap-ha'
      @sequence["ws_start"] = "debug_run" if @config.debug
      Wizard.CreateDialog
      Wizard.SetDialogTitle("HA Setup for SAP Products")
      begin
        Sequencer.Run(@aliases, @sequence)
      ensure
        Wizard.CloseDialog
      end
    end

    # Check the product ID. If it is unknown, show the bye-bye message.
    def product_check
      log.debug "--- called #{self.class}.#{__callee__} ---"
      # TODO: here we need to know what product we are installing
      # Yast.import 'SAPProduct'
      # SAPProduct.Read
      # SAPProduct.installedProducts [{productID: 'HANA'...}...]
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
      selection = SapHA::Wizard::ListSelection.new.run(
        "Scenario selection for #{@config.product_name}",
        "An #{@config.product_name} installation was detected. "\
        "Select one of the high-avaliability scenarios from the list below:",
        scenarios,
        help,
        false,
        true
      )
      case selection
      when :next
        begin
          @config.set_scenario_name(UI.QueryWidget(:selection_box, :Value))
        rescue ScenarioNotFoundException
          return :unknown
        rescue GUIFatal => e
          Popup.Error(e.message)
          return :abort
        end
      when :abort
        return :abort
      end
      set_test_values if @test
      selection
    end

    def product_not_supported
      log.debug "--- called #{self.class}.#{__callee__} ---"
      SapHA::Wizard::RichText.new.run(
        'Product not supported',
        SapHA::Helpers.load_help('product_not_found'),
        SapHA::Helpers.load_help('product_not_found'),
        false,
        false
      )
      log.error("No HA scenarios found for product #{@product_name}")
      :abort
    end

    def show_prerequisites
      log.error "--- called #{self.class}.#{__callee__} ---"
      notice = @config.scenario['prerequisites_notice']
      return :next unless notice
      SapHA::Wizard::RichText.new.run(
        'Prerequisites',
        SapHA::Helpers.load_help(notice),
        '',
        true,
        true
      )
    end

    def scenarios_not_found
      log.debug "--- called #{self.class}.#{__callee__} ---"
      log.error("No HA scenarios found for product #{@product_name}")
      SapHA::Wizard::RichText.new.run(
        'Scenarios not found',
        "There were no HA scenarios found for the product #{@product_name}",
        "The product you are installing is not supported by this module.<br>
        You can set up a cluster manually using the Cluster YaST module.",
        false,
        false
      )
      :abort
    end

    def configuration_overview
      log.debug "--- called #{self.class}.#{__callee__} ---"
      ret = SapHA::Wizard::ConfigurationOverviewPage.new(@config).run
      return :abort if ret == :back # TODO: find out why it returns "back"
      ret
    end

    def configure_cluster
      log.debug "--- called #{self.class}.#{__callee__} ---"
      SapHA::Wizard::ClusterNodesConfigurationPage.new(@config).run
    end

    def configure_comm_layer
      log.debug "--- called #{self.class}.#{__callee__} ---"
      SapHA::Wizard::CommLayerConfigurationPage.new(@config).run
    end

    def join_existing_cluster
      log.debug "--- called #{self.class}.#{__callee__} ---"
      SapHA::Wizard::JoinClusterPage.new(@config).run
    end

    def fencing_mechanism
      log.debug "--- called #{self.class}.#{__callee__} ---"
      SapHA::Wizard::FencingConfigurationPage.new(@config).run
    end

    def watchdog
      log.debug "--- called #{self.class}.#{__callee__} ---"
      SapHA::Wizard::WatchdogConfigurationPage.new(@config).run
    end

    def configure_hana
      log.debug "--- called #{self.class}.#{__callee__} ---"
      SapHA::Wizard::HANAConfigurationPage.new(@config).run
    end

    def configure_ntp
      log.debug "--- called #{self.class}.#{__callee__} ---"
      SapHA::Wizard::NTPConfigurationPage.new(@config).run
    end

    def run_installation
      log.debug "--- called #{self.class}.#{__callee__} ---"
      return :next if WFM.Args.include? 'noinst'
      ui = SapHA::Wizard::GUIInstallationPage.new
      begin
        SapHA::SAPHAInstallation.new(@config, ui).run
      rescue StandardError => e
        log.error "An error occured during the installation"
        log.error e.message
        log.error e.backtrace.to_s
        # Let Yast handle the exception
        raise e
      end
    end

    def show_summary
      log.debug "--- called #{self.class}.#{__callee__} ---"
      if WFM.Args.include? 'noinst'
        SapHA::NodeLogger.import [
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
      SapHA::Wizard::SetupSummaryPage.new(@config).run
    end

    def debug_run
      @config.set_product_id "HANA"
      if WFM.Args.include? 'cost'
        @config.set_scenario_name 'Scale Up: Cost-optimized'
      else
        @config.set_scenario_name 'Scale Up: Performance-optimized'
      end
      set_test_values if @test
      :config_overview
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
      @config.fencing.import(devices: ['/dev/vdb'])
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
      unless WFM.Args.include? 'nontp'
        Yast.import 'NtpClient'
        NtpClient.Import ntp_cfg
        NtpClient.Write
      end
      @config.ntp.read_configuration
    end
  end

  SAPHA = SAPHAClass.new
  SAPHA.main
end
