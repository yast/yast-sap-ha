require 'yast'
require 'yaml'
require 'sap_ha/sap_ha_dialogs'
require 'sap_ha/helpers'
require 'sap_ha/gui'
require 'sap_ha_wizard/cluster_members_page'
require 'sap_ha_wizard/comm_layer_page'
require 'sap_ha_wizard/join_cluster_page'
require 'sap_ha_wizard/fencing_page'
require 'sap_ha_wizard/watchdog_page'
require 'sap_ha_wizard/hana_page'
require 'sap_ha/configuration'

# YaST module
module Yast
  # Main client class
  class SAPHAClass < Client
    Yast.import 'UI'
    Yast.import 'Wizard'
    Yast.import 'Sequencer'
    include Yast::UIShortcuts
    include Yast::Logger

    def initialize
      @config = ScenarioConfiguration.new
    end

    def main
      textdomain 'sap-ha'

      # @sequence = {
      #   # "ws_start"              => "product_check",
      #   "ws_start"              => "debug_run", # TODO: debug
      #   "product_check"         =>  {
      #     abort:             :abort,
      #     hana:              "scenario_selection",
      #     nw:                "scenario_selection",
      #     unknown:           "product_not_supported",
      #     next:              "product_not_supported"
      #     },
      #   "scenario_selection"    => {
      #     abort:             :abort,
      #     next:              "general_setup", # TODO: here be magic that restructures this
      #     unknown:           "product_not_supported"
      #     },
      #   "general_setup"         => {
      #     abort:             :abort,
      #     next:              "scenario_setup",
      #     config_members:    "configure_members",
      #     config_network:    "configure_network",
      #     config_components: "configure_components",
      #     join_cluster:      "join_cluster",
      #     fencing:           "fencing",
      #     watchdog:          "watchdog",
      #     hana:              "hana"
      #     },
      #   "scenario_setup"        => {
      #     abort:             :abort,
      #     next:              :next
      #     },
      #   "summary"               => {
      #     next:              :abort,
      #     abort:             :abort
      #     },
      #   "configure_members"     => {
      #     next:              "general_setup",
      #     back:              "general_setup",
      #     abort:             :abort
      #     },
      #   "configure_network"     => {
      #     next:              "general_setup",
      #     back:              "general_setup",
      #     abort:             :abort
      #     },
      #   "configure_components"  => {
      #     next:              "general_setup",
      #     back:              "general_setup",
      #     abort:             :abort
      #     },
      #   "join_cluster"          => {
      #     next:              "general_setup",
      #     back:              "general_setup",
      #     abort:             :abort
      #     },
      #   "fencing"               => {
      #     next:              "general_setup",
      #     back:              "general_setup",
      #     abort:             :abort
      #     },
      #   "watchdog"              => {
      #     next:              "general_setup",
      #     back:              "general_setup",
      #     abort:             :abort
      #     },
      #   "hana"                  => {
      #     next:              "general_setup",
      #     back:              "general_setup",
      #     abort:             :abort
      #     },
      #   "debug_run"             => {
      #     general_setup:     "general_setup"
      #     }
      #   }

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
          next:              "configure_network", # TODO: here be magic that restructures this
          unknown:           "product_not_supported"
          },
        "general_setup"         => {
          abort:             :abort,
          next:              "scenario_setup",
          config_members:    "configure_members",
          config_network:    "configure_network",
          config_components: "configure_components",
          join_cluster:      "join_cluster",
          fencing:           "fencing",
          watchdog:          "watchdog",
          hana:              "hana"
          },
        "scenario_setup"        => {
          abort:             :abort,
          next:              :next
          },
        "summary"               => {
          next:              :abort,
          abort:             :abort
          },
        "configure_members"     => {
          next:              "fencing",
          back:              "configure_network",
          abort:             :abort
          },
        "configure_network"     => {
          next:              "configure_members",
          back:              "scenario_selection",
          abort:             :abort
          },
        "configure_components"  => {
          next:              "general_setup",
          back:              "general_setup",
          abort:             :abort
          },
        "join_cluster"          => {
          next:              "general_setup",
          back:              "general_setup",
          abort:             :abort
          },
        "fencing"               => {
          next:              "watchdog",
          back:              "configure_members",
          abort:             :abort
          },
        "watchdog"              => {
          next:              "hana",
          back:              "fencing",
          abort:             :abort
          },
        "hana"                  => {
          next:              "general_setup",
          back:              "watchdog",
          abort:             :abort
          },
        "debug_run"             => {
          general_setup:     "general_setup"
          }
        }

      @aliases = {
        'product_check'         => -> { product_check },
        'scenario_selection'    => -> { scenario_selection },
        'product_not_supported' => -> { product_not_supported },
        'configure_members'     => -> { configure_members },
        'configure_network'     => -> { configure_comm_layer },
        'configure_components'  => -> { configure_components },
        'general_setup'         => -> { general_setup },
        'scenario_setup'        => -> { scenario_setup },
        'summary'               => -> { show_summary },
        'join_cluster'          => -> { join_existing_cluster },
        'fencing'               => -> { fencing_mechanism },
        'watchdog'              => -> { watchdog },
        'hana'                  => -> { hana_configuration },
        'debug_run'             => -> { debug_run }
      }

      Wizard.CreateDialog
      begin
        Sequencer.Run(@aliases, @sequence)
      ensure
        Wizard.CloseDialog
      end
    end

    def product_check
      log.debug "--- called #{self.class}.#{__callee__} ---"
      # TODO: here we need to know what product we are installing
      begin
        @config.product_id = "HANA"
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
        "An #{@config.product_name} installation was detected. Select one of the high-avaliability scenarios from the list below:",
        scenarios,
        help,
        false,
        true
        )
      selection = UI.UserInput()
      if selection == :next
        begin
          @config.scenario_name = UI.QueryWidget(:selection_box, :Value)
        rescue ScenarioNotFoundException => e
          return :unknown
        end
      end
      selection
    end

    def product_not_supported
      log.debug "--- called #{self.class}.#{__callee__} ---"
      SAPHAGUI.richt_text(
        'No HA scenarios found',
        "There were no HA scenarios found for the product #{@product_name}",
        "The product you are installing is not supported by this module.<br>You can set up a cluster manually using the Cluster YaST module.",
        false,
        false
      )
      log.error("No HA scenarios found for product #{@product_name}")
      UI.UserInput()
      return :abort
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

    def general_setup
      SAPHAGUI.richt_text(
        "High-Availability Setup Summary",
        UI.TextMode ? SAPHAHelpers.render_template('setup_summary_ncurses.erb', binding) :
        SAPHAHelpers.render_template('setup_summary_gui.erb', binding),
        SAPHAHelpers.load_html_help('setup_summary_help.html'),
        true,
        true
      )
      ret = UI.UserInput()
      return ret.to_sym
    end

    def show_summary
      log.debug "--- called #{self.class}.#{__callee__} ---"
    end

    def configure_components
      log.debug "--- called #{self.class}.#{__callee__} ---"
      SAPHAGUI.stub(
        "Components Configuration",
        'Here you can configure the components of the installation.',
      )
      UI.UserInput()
    end

    def configure_members
      log.debug "--- called #{self.class}.#{__callee__} ---"
      ClusterMembersConfigurationPage.new(@config).run
    end

    def configure_comm_layer
      log.debug "--- called #{self.class}.#{__callee__} ---"
      CommLayerConfigurationPage.new(@config).run
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

    def hana_configuration
      log.debug "--- called #{self.class}.#{__callee__} ---"
      HANAConfigurationPage.new(@config).run
    end


    def debug_run
      @config.product_id = "HANA"
      @config.scenario_name = 'Performance-optimized'
      :general_setup
    end
  end

  SAPHA = SAPHAClass.new
  SAPHA.main

end
