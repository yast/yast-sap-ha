require 'yast'
require 'yaml'

require 'sap_ha/sap_ha_dialogs'

module Yast
  class SAPHAClass < Client
    Yast.import 'UI'
    Yast.import 'Wizard'
    Yast.import 'Sequencer'
    include Yast::UIShortcuts
    include Yast::Logger
    
    def initialize
      @scenarios = YAML.load_file('test/scenarios.yaml')
      # stub
      @product_id = 'HANA'
      @scenario_name = ''
      @summary = ''
    end

    def main
      textdomain 'sap-ha'

      @sequence = {
        "ws_start" => "product_check",
        "product_check" => {
          abort:      :abort,
          hana:       "scenario_selection",
          nw:         "scenario_selection",
          unknown:    "product_not_supported",
          next:       "product_not_supported"
          },
        "scenario_selection"    => {
          # auto:       :auto,
          abort:      :abort,
          next:       "general_setup"
          },
        "general_setup" => {
          # auto:     :auto,
          abort:    :abort,
          next:     "scenario_setup",
          config_members: "configure_members",
          config_network: "configure_network",
          config_components: "configure_components"
          },
        "scenario_setup" => {
          abort:      :abort,
          next:       :next
          },
        "summary" => {
          next:       :abort,
          abort:      :abort
          },
        "configure_members" => {
          next:       "general_setup",
          back:       "general_setup",
          abort:      :abort
          },
        "configure_network" => {
          next:       "general_setup",
          back:       "general_setup",
          abort:      :abort
          }
        }
      @aliases = {
        'product_check' => lambda { product_check },
        'scenario_selection' => lambda { scenario_selection },
        'product_not_supported' => lambda { product_not_supported },
        'configure_members' => lambda { configure_members },
        'configure_network' => lambda { configure_network },
        'configure_components' => lambda { configure_components },
        'general_setup' => lambda { general_setup },
        'scenario_setup' => lambda { scenario_setup },
        'summary' => lambda {show_summary}
      }
      
      Wizard.CreateDialog
      begin
        Sequencer.Run(@aliases, @sequence)
      ensure
        Wizard.CloseDialog
      end
    end

    def product_check
      log.debug "--- called #{self.class.to_s}.#{__callee__} ---"
      @product = @scenarios.find {|p| p['product'] && p['product'].fetch('id', '') == @product_id}
      if @product
        @product = @product['product']
        @product_name = @product['string_name']
        return @product.fetch('id', 'abort').downcase.to_sym
      else
        return :unknown
      end
    end

    def scenario_selection
      log.debug "--- called #{self.class.to_s}.#{__callee__} ---"
      scenarios = @product['scenarios'].map {|s| s['name']}
      help = (@product['scenarios'].map {|s| s['description']}).join('<br><br>')
      Wizard.SetContents(
        "Scenario selection for #{@product_name}",
        SAPHADialogs.select_from_list_page(
          'Select a high-avaliability scenario from the list below', 
          scenarios),
        help,
        true,
        true
      )
      selection = UI.UserInput()
      if selection == :next
        @scenario_name = UI.QueryWidget(:selection_box, :Value)
        log.info "Selected scenario is '#{@scenario_name}'"
        @scenario = @product['scenarios'].find {|s| s['name'] == @scenario_name}
        if !@scenario
          log.error("Scenario name '#{@scenario_name}' not found in the scenario list")
        end
      end
      return selection
    end

    def product_not_supported
      log.debug "--- called #{self.class.to_s}.#{__callee__} ---"
      Wizard.SetContents(
          'No HA scenarios found',
          RichText("There were no HA scenarios found for the product #{@product_name}"),
          "The product you are installing is not supported by this module.<br>You can set up a cluster manually using the Cluster YaST module.",
          false,
          false
          )
      log.error("No HA scenarios found for product #{@product_name}")
      UI.UserInput()
      return :abort
    end

    def scenario_setup
      log.debug "--- called #{self.class.to_s}.#{__callee__} ---"
      Wizard.SetContents(
        "HA Setup: #{@product_name} - #{@scenario_name}",
        RichText("Here we install the product #{@product_name} with scenario #{@scenario_name}"),
        'Here is help for the scenario',
        true,
        true
        )
      UI.UserInput()
    end

    def general_setup
      log.debug "--- called #{self.class.to_s}.#{__callee__} ---"
      Wizard.SetContents(
        "General Configuration",
        RichText(general_setup_summary),
        general_setup_help,
        true,
        true
        )
      ret = UI.UserInput()
      return ret.to_sym
    end

    def general_setup_summary
      strings = []
      strings << "<b>Product:</b> #{@product_name}"
      strings << "<b>Scenario:</b> #{@scenario_name}"
      strings << @scenario['description']
      strings << "<hr>"
      strings << "<b>Cluster members:</b> Not configured (<a href=\"config_members\">configure</a>)"
      strings << "<b>Network:</b> Not configured (<a href=\"config_network\">configure</a>)"
      strings << "<b>Components:</b> Not configured (<a href=\"config_components\">configure</a>)"
      strings.join("<br>")
    end

    def general_setup_help
      strings = []
      strings << "<b>Cluster members:</b> configure the number of nodes and their names"
      strings << "<b>Network:</b> configure the corosync communication layer"
      strings << "<b>Components:</b> configure the product components"
      strings.join("<br>")
    end

    def show_summary
      log.debug "--- called #{self.class.to_s}.#{__callee__} ---"
    end

    def configure_members
      log.debug "--- called #{self.class.to_s}.#{__callee__} ---"
      Wizard.SetContents(
        "Cluster Members Configuration",
        # RichText('Here you can configure the members of the cluster'),
        Label('Here you can configure the members of the cluster. Here you can configure the members of the cluster. Here you can configure the members of the cluster. Here you can configure the members of the cluster. Here you can configure the members of the cluster. Here you can configure the members of the cluster. '),
        'Help',
        true,
        true
      )
      UI.UserInput()
    end

    def configure_network
      log.debug "--- called #{self.class.to_s}.#{__callee__} ---"
      Wizard.SetContents(
        "Cluster Network Configuration",
        RichText('Here you can configure the network of the cluster'),
        'Help',
        true,
        true
      )
      UI.UserInput()
    end

  end
  
  SAPHA = SAPHAClass.new
  SAPHA.main
end