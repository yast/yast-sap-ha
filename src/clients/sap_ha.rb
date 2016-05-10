require 'yast'
require 'yaml'
require 'sap_ha/sap_ha_dialogs'
require 'sap_ha/helpers'
require 'sap_ha/gui'
require 'sap_ha_wizard/node_configuration_page'
require 'sap_ha_wizard/comm_configuration_page'
require 'sap_ha/scenario_configuration'

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
      # TODO: stub
      @config = ScenarioConfiguration.new
    end

    def main
      textdomain 'sap-ha'

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
          next:              "general_setup",
          unknown:           "product_not_supported"
          },
        "general_setup"         => {
          abort:             :abort,
          next:              "scenario_setup",
          config_members:    "configure_members",
          config_network:    "configure_network",
          config_components: "configure_components"
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
          next:              "general_setup",
          back:              "general_setup",
          abort:             :abort
          },
        "configure_network"     => {
          next:              "general_setup",
          back:              "general_setup",
          abort:             :abort
          },
        "configure_components"  => {
          next:              "general_setup",
          back:              "general_setup",
          abort:             :abort
          }
        }

      @aliases = {
        'product_check'         => -> { product_check },
        'scenario_selection'    => -> { scenario_selection },
        'product_not_supported' => -> { product_not_supported },
        'configure_members'     => -> { configure_members },
        'configure_network'     => -> { configure_network },
        'configure_components'  => -> { configure_components },
        'general_setup'         => -> { general_setup },
        'scenario_setup'        => -> { scenario_setup },
        'summary'               => -> { show_summary }
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
      log.debug "--- called #{self.class}.#{__callee__} ---"
      SAPHAGUI.richt_text(
        "General Configuration",
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
      # SAPHAGUI.node_definition_page()
      NodeConfigurationPage.new(@config).run
    end

    def configure_network
      log.debug "--- called #{self.class}.#{__callee__} ---"
      # SAPHAGUI.network_definition_page
      CommLayerConfigurationPage.new(@config).run
    end

  end

  SAPHA = SAPHAClass.new
  SAPHA.main
end
