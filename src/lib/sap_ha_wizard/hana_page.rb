require 'yast'
require 'sap_ha/helpers'
require 'sap_ha_wizard/base_wizard_page'
Yast.import 'IP'
Yast.import 'Hostname'
Yast.import 'Report'

module Yast
  # Communication Layer Configuration Page
  class HANAConfigurationPage < BaseWizardPage
    def initialize(model)
      super(model)
      @my_model = model.hana
    end

    def set_contents
      super
      Wizard.SetContents(
        _('HANA Configuration'),
        base_layout_with_label(
          'Set the HANA-specific parameters up',
          VBox(
            HBox(
              # Label('System ID:'),
              # InputField(Id(:hana_sid), '', '')
              InputField(Id(:hana_sid), 'System ID:', '')
              ),
            HBox(
              # Label('Instance number:'),
              # InputField(Id(:hana_inst), '', '')
              InputField(Id(:hana_inst), 'Instance number:', '')
              ),
            HBox(
              # Label(),
              InputField(Id(:hana_vip), 'Virtual IP Address:', '')  # TODO: validators
              ),
            HBox(
              # Label('Prefer Site Takeover:'),
              base_true_false_combo(:site_takover, 'Prefer Site Takeover:')
              # CheckBox(Id(:site_takover), 'Prefer Site Takeover:', true)
              ),
            HBox(
              # Label('Automatic Registration:'),
              base_true_false_combo(:auto_reg, 'Automatic Registration', false)
              # CheckBox(Id(:auto_reg), 'Automatic Registration', false)
              )
            )
        ),
        '',   # TODO: load help
        true,
        true
      )
      refresh_view
    end

    def can_go_next
      # TODO: validators
      @my_model.system_id = UI.QueryWidget(Id(:hana_sid), :Value)
      @my_model.instance = UI.QueryWidget(Id(:hana_inst), :Value)
      @my_model.virtual_ip = UI.QueryWidget(Id(:hana_vip), :Value)
      @my_model.prefer_takeover = UI.QueryWidget(Id(:site_takover), :Value)
      @my_model.auto_register = UI.QueryWidget(Id(:auto_reg), :Value)

    end

    def refresh_view
      super
      UI.ChangeWidget(Id(:hana_sid), :Value, @my_model.system_id)
      UI.ChangeWidget(Id(:hana_inst), :Value, @my_model.instance)
      UI.ChangeWidget(Id(:hana_vip), :Value, @my_model.virtual_ip)
      UI.ChangeWidget(Id(:site_takover), :Value, @my_model.prefer_takeover)
      UI.ChangeWidget(Id(:auto_reg), :Value, @my_model.auto_register)
    end
  end
end
