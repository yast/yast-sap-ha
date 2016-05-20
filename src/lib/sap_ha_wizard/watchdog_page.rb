require 'yast'
require 'sap_ha/helpers'
require 'sap_ha_wizard/base_wizard_page'
Yast.import 'IP'
Yast.import 'Hostname'
Yast.import 'Report'

module Yast
  # Communication Layer Configuration Page
  class WatchdogConfigurationPage < BaseWizardPage
    def initialize(model)
      super(model)
    end

    def set_contents
      super
      Wizard.SetContents(
        _('Watchdog Setup'),
        base_layout_with_label(
          'Select the appropriate watchdog modules to load at system startup',
          VBox(
            SelectionBox(Id(:configured_wd), 'Configured watchdogs:',
              []),
            HBox(
              PushButton(Id(:add_wd), 'Add'),
              PushButton(Id(:remove_wd), 'Remove')
              ),
            SelectionBox(Id(:loaded_wd), 'Loaded watchdogs:',
              [])
          )
        ),
        '',
        true,
        true
      )
      refresh_view
    end

    def can_go_next
      true
    end

    def refresh_view
      super
      UI.ChangeWidget(Id(:configured_wd), :Items, @model.watchdog.installed)
      UI.ChangeWidget(Id(:loaded_wd), :Items, @model.watchdog.loaded)
    end

    def handle_user_input(input)
      super
      case input
      when :add_wd
        to_add = wd_selection_popup
        return if to_add.nil?
        @model.watchdog.add_to_config(to_add[:selected])
        refresh_view
      else
        log.warn "--- #{self.class}.#{__callee__}: Unexpected user input: #{input} ---"
      end
    end

    def wd_selection_popup()
      log.debug "--- #{self.class}.#{__callee__} --- "
      base_popup(
        "Select a module to configure",
        nil,
        SelectionBox(Id(:selected), 'Available modules:', @model.watchdog.proposals)
      )
    end

    # def node_configuration_validators(values, report = true)
    #   if !IP.Check4(values[:ip_ring1])
    #     Report.Error("Invalid entry for IP Ring 1: #{IP.Valid4}") if report
    #     return false
    #   end
    #   if !IP.Check4(values[:ip_ring2])
    #     Report.Error("Invalid entry for IP Ring 2: #{IP.Valid4}") if report
    #     return false
    #   end
    #   if !Hostname.Check(values[:host_name])
    #     Report.Error("Invalid entry for Hostname: #{Hostname.ValidHost}") if report
    #     return false
    #   end
    #   true
    # end
  end
end
