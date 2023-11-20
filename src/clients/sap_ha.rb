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

require "yast"
require "psych"
require "sap_ha/configuration"
require "sap_ha/helpers"
require "sap_ha/node_logger"
require "sap_ha/wizard/cluster_nodes_page"
require "sap_ha/wizard/comm_layer_page"
require "sap_ha/wizard/join_cluster_page"
require "sap_ha/wizard/fencing_page"
require "sap_ha/wizard/watchdog_page"
require "sap_ha/wizard/hana_page"
require "sap_ha/wizard/ntp_page"
require "sap_ha/wizard/overview_page"
require "sap_ha/wizard/summary_page"
require "sap_ha/wizard/gui_installation_page"
require "sap_ha/wizard/list_selection"
require "sap_ha/wizard/rich_text"
require "sap_ha/wizard/scenario_selection_page"

# YaST module
module Yast
  # Main client class
  class SAPHAClass < Client
    attr_reader :sequence

    Yast.import "UI"
    Yast.import "Wizard"
    Yast.import "Sequencer"
    Yast.import "Service"
    Yast.import "Popup"
    include Yast::UIShortcuts
    include Yast::Logger
    include SapHA::Exceptions

    def initialize
      log.warn "--- called #{self.class}.#{__callee__}: CLI arguments are #{WFM.Args} ---"
      begin
        if WFM.Args.include?("readconfig")
          ix = WFM.Args.index("readconfig") + 1
          begin
            @config = Psych.unsafe_load(File.read(WFM.Args[ix]))
          rescue NoMethodError
            @config = Psych.load(File.read(WFM.Args[ix]))
          end
          @config.imported = true
          if WFM.Args.include?("unattended")
            @config.unattended = true
          end
        else
          @config = SapHA::HAConfiguration.new
        end
      rescue Psych::SyntaxError => e
        log.error "Syntax Error on the Config File: #{e.message}"
        @config = SapHA::HAConfiguration.new
        Popup.TimedError("The configuration file could not be loaded because of a Syntax Error. Switching to the manual configuration. Details: #{e.message}", 10)
      rescue StandardError => e
        log.error "Unexpected Error reading the config file: #{e.message}"
        @config = SapHA::HAConfiguration.new
        Popup.TimedError("The configuration file could not be loaded because of a unexpected error. Switching to the manual configuration. Details: #{e.message}", 10)
      ensure
        @config.debug = WFM.Args.include? "over"
        @config.no_validators = WFM.Args.include?("noval") || WFM.Args.include?("validators")
        Wizard.SetTitleIcon("yast-heartbeat")
        @sequence = {
          "ws_start"              => "product_check",
          "product_check"         =>  {
            abort:             :abort,
            hana:              "scenario_selection",
            nw:                "scenario_selection",
            unknown:           "product_not_supported",
            next:              "product_not_supported"
          },
          "file_import_check"    =>  {
            abort:             :abort,
            cancel:            :abort,
            next:              "config_overview",
            unknown:           "summary",
            back:              "config_overview"
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

        @unattended_sequence = {
          "ws_start"              => "product_check",
          "product_check"         =>  {
            abort:             :abort,
            hana:              "file_import_check",
            nw:                "file_import_check",
            unknown:           :ws_finish,
            next:              :ws_finish
          },
          "file_import_check"    =>  {
            abort:             :abort,
            cancel:            :abort,
            next:              "unattended_install",
            unknown:           :ws_finish
          },
          "unattended_install"   =>  {
            abort:             :abort,
            cancel:            :abort,
            next:              :ws_finish,
            unknown:           :ws_finish,
            summary:           :ws_finish
          }
        }

        @aliases = {
          "product_check"         => -> { product_check },
          "file_import_check"    => -> { file_import_check },
          "scenario_selection"    => -> { scenario_selection },
          "product_not_supported" => -> { product_not_supported },
          # "prereqs_notice"        => [-> () { show_prerequisites }, true],
          "prereqs_notice"        => -> { show_prerequisites },
          "configure_cluster"     => -> { configure_cluster },
          "configure_comm_layer"  => -> { configure_comm_layer },
          "join_cluster"          => -> { join_existing_cluster },
          "fencing"               => -> { fencing_mechanism },
          "watchdog"              => -> { watchdog },
          "hana"                  => -> { configure_hana },
          "debug_run"             => -> { debug_run },
          "installation"          => -> { run_installation },
          "unattended_install"    => -> { run_unattended_install },
          "ntp"                   => -> { configure_ntp },
          "config_overview"       => -> { configuration_overview },
          "summary"               => -> { show_summary }
        }
      end
    end

    def main
      textdomain "hana-ha"
      @sequence["ws_start"] = "debug_run" if @config.debug
      @sequence["product_check"][:hana] = "file_import_check" if @config.imported
      Wizard.CreateDialog
      Wizard.SetDialogTitle("HA Setup for SAP Products")
      begin
        if @config.unattended
          Sequencer.Run(@aliases, @unattended_sequence)
        else
          Sequencer.Run(@aliases, @sequence)
        end
      rescue StandardError => e
        # FIXME: y2start overrides the return code, therefore exit prematurely without
        # shutting down Yast properly, see bsc#1099871
        # If the error was not catched until here, we know that is a unattended installation.
        # exit!(1)
        @unattended_error = "Error occurred during the unattended installation: #{e.message}"
        log.error @unattended_error
        puts @unattended_error
        Popup.TimedError(@unattended_error, 10)
      ensure
        Wizard.CloseDialog
        if @config.unattended
          if @unattended_error.nil?
            SapHA::Helpers.write_file("/var/log/YaST2/sap_ha_unattended_install_log.txt", SapHA::NodeLogger.text)
            log.info "Execution Finished: Please, verify the log /var/log/YaST2/sap_ha_unattended_install_log.txt"
            # FIXME: yast redirects stdout, therefore the usage of the CommanlineClass is needed to write on the stdout, but as the
            # the dependent modules we have (cluster, firewall, ntp) demands UI existence, we cannot call the module without creating the UI object.
            # The best option is to presente a Timed Popup to the user.
            Popup.TimedMessage("Execution Finished: Please, verify the log /var/log/YaST2/sap_ha_unattended_install_log.txt", 10)
          end
        end
      end
    end

    # Check the product ID. If it is unknown, show the bye-bye message.
    def product_check
      log.debug "--- called #{self.class}.#{__callee__} ---"
      # TODO: here we need to know what product we are installing
      # Yast.import "SAPProduct"
      # SAPProduct.Read
      # SAPProduct.installedProducts [{productID: "HANA"...}...]
      begin
        @config.set_product_id "HANA"
      rescue ProductNotFoundException => e
        log.error e.message
        return :unknown
      end
      # TODO: here we should check if the symbol can be handled by th
      # stat = Yast::Cluster.LoadClusterConfig
      # Yast::Cluster.load_csync2_confe Sequencer
      @config.product.fetch("id", "abort").downcase.to_sym
    end

    def file_import_check
      log.debug "--- called #{self.class}.#{__callee__} ---"
      SapHA::SAPHAUnattendedInstall.new(@config).check_config
    rescue StandardError => e
      if @config.unattended
        # Will be trated by the caller to collect the log.
        raise e
      else
        # Adjust the WF to show the Summary with the problems.
        return :unknown
      end
    end

    def scenario_selection
      log.debug "--- called #{self.class}.#{__callee__} ---"
      selection = SapHA::Wizard::ScenarioSelectionPage.new(@config).run
      log.debug "--- called #{self.class}.#{__callee__}:: ret is #{selection.class} ---"
      if selection.is_a?(SapHA::HAConfiguration)
        @config = selection
        @config.refresh_all_proposals
        return :next
      end
      selection
    end

    def product_not_supported
      log.debug "--- called #{self.class}.#{__callee__} ---"
      SapHA::Wizard::RichText.new.run(
        "Product not supported",
        SapHA::Helpers.load_help("product_not_found"),
        SapHA::Helpers.load_help("product_not_found"),
        false,
        false
      )
      log.error("No HA scenarios found for product #{@product_name}")
      :abort
    end

    def show_prerequisites
      log.error "--- called #{self.class}.#{__callee__} ---"
      notice = @config.scenario["prerequisites_notice"]
      return :next unless notice
      SapHA::Wizard::RichText.new.run(
        "Prerequisites",
        SapHA::Helpers.load_help(notice, @config.platform),
        "",
        true,
        true
      )
    end

    def scenarios_not_found
      log.debug "--- called #{self.class}.#{__callee__} ---"
      log.error("No HA scenarios found for product #{@product_name}")
      SapHA::Wizard::RichText.new.run(
        "Scenarios not found",
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
      SapHA::Wizard::ConfigurationOverviewPage.new(@config).run
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
      return :next if WFM.Args.include? "noinst"
      ui = SapHA::Wizard::GUIInstallationPage.new
      begin
        SapHA::SAPHAInstallation.new(@config, ui).run
      rescue StandardError => e
        log.error "An error occurred during the installation"
        log.error e.message
        log.error e.backtrace.to_s
        # Let Yast handle the exception
        raise e
      end
    end

    def run_unattended_install
      log.debug "--- called #{self.class}.#{__callee__} ---"
      return :next if WFM.Args.include? "noinst"
      ui = SapHA::Wizard::GUIInstallationPage.new
      begin
        # FIXME: We cannot use the unattended install as the other YaST Modules need
        # a UI to show the progress bar. Keeping it in separated method to facilitate
        # the adjustment in the future, if needed.
        # SapHA::SAPHAUnattendedInstall.new(@config).run
        SapHA::SAPHAInstallation.new(@config, ui).run
      rescue StandardError => e
        log.error "An error occurred during the unattended installation"
        log.error e.message
        log.error e.backtrace.to_s
        # Let the Caller handle the exception
        raise e
      end
    end

    def show_summary
      log.debug "--- called #{self.class}.#{__callee__} ---"
      if File.exist?(SapHA::Helpers.var_file_path("need_to_start_firewalld"))
        Service.Start("firewalld")
      end
      SapHA::Wizard::SetupSummaryPage.new(@config).run
    end

    def debug_run
      @config.set_product_id "HANA"
      if WFM.Args.include? "cost"
        @config.set_scenario_name "Scale Up: Cost-optimized"
      else
        @config.set_scenario_name "Scale Up: Performance-optimized"
      end
      :config_overview
    end
  end

  SAPHA = SAPHAClass.new
  SAPHA.main
end
