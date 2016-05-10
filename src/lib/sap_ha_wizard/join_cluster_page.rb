require 'sap_ha_wizard/base_wizard_page'
# require_relative 'base_wizard_page'

module Yast
  class JoinClusterPage < BaseWizardPage
    def set_contents
      super
      Wizard.SetContents(
        _('Join an Existing Cluster'),
        base_layout_with_label(
          _('Set the parameters of the cluster you wish to join'),
          VBox(
            InputField('IP Address', ''),
            InputField('Interface', ''),
          )
        ),
        '',
        true,
        true
      )
      refresh_view
    end

    def handle_user_input(input)
      super
    end

    def refresh_view
      super
    end


    def can_go_next
      super
    end
  end
end