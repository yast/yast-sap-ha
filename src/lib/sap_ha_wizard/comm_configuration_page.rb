require 'yast'
require 'sap_ha/helpers'
require 'sap_ha_wizard/base_wizard_page'
Yast.import 'IP'
Yast.import 'Hostname'
Yast.import 'Report'

module Yast
  # Communication Layer Configuration Page
  class CommLayerConfigurationPage < BaseWizardPage
    def initialize(model)
      super(model)
    end

    def set_contents
      super
      Wizard.SetContents(
        _('Cluster Definition'),
        base_layout_with_label(
          'Define the communication layer',
          VBox(
            HBox(
              Label('Transport mode:'),
              RadioButtonGroup(
                Id(:transport_mode),
                HBox(
                  RadioButton('Unicast', true),
                  RadioButton('Multicast', false)
                )
              )
            ),
            HBox(
              Label('Number of rings:'),
              ComboBox('', ['1', '2'])
            ),
            HBox(
              HSpacing(10),
              Table(
                Id(:ring_definition_table),
                Opt(:keepSorting, :immediate),
                Header(_('Ring'), _('Address'), _('Port')),
                [Item(Id(:ring1), '1', '192.168.10.0', '5490'),
                 Item(Id(:ring2), '2', '192.168.11.0', '5495')]
              ),
              HSpacing(10)
            ),
            PushButton(Id(:edit_ring), _('Edit selected')),
            InputField(_('Cluster name:'), ''),
            InputField(_('Expected votes:'), '')
          )
        ),
        '',
        true,
        true
      )
      refresh_view
    end

    def can_go_next
    end

    def refresh_view
      super
      entries = @model.conf_nodes.table_items.map { |entry| Item(Id(entry[0]), *entry[1..-1]) }
      log.info "Table items: #{entries.inspect}"
      UI.ChangeWidget(Id(:ring_definition_table), :Items, entries)
    end

    def handle_user_input(input)
      super
      case input
      when :edit_ring
        item_id = UI.QueryWidget(Id(:ring_definition_table), :Value)
        values = ring_configuration_popup(@model.conf_nodes.node_parameters(item_id))
        Report.ClearErrors
        log.info "Return from ring_configuration_popup: #{values}"
        if !values.nil? && !values.empty?
          @model.conf_nodes.update_values(item_id, values)
          refresh_view
        end
      else
        log.warn "--- #{self.class}.#{__callee__}: Unexpected user input: #{input} ---"
      end
    end

    # Returns the ring configuration parameters
    def ring_configuration_popup(ring_number=0)
      log.debug "--- #{self.class}.#{__callee__} --- "
      base_popup(
        "Configuration for Ring \##{ring_number}",
        nil,
        InputField(Id(:address), 'Address:', ''),
        InputField(Id(:port), 'Port:', '')
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
