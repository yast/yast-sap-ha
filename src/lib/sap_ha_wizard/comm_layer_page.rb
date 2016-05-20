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
      @my_model = model.communication_layer
      @recreate_table = true
    end

    def set_contents
      super
      Wizard.SetContents(
        _('Communication Layer'),
        base_layout_with_label(
          'Define the communication layer',
          VBox(
            HBox(
              Label('Transport mode:'),
              RadioButtonGroup(
                Id(:transport_mode),
                HBox(
                  RadioButton(Id(:unicast), Opt(:notify), 'Unicast', true),
                  RadioButton(Id(:multicast), Opt(:notify), 'Multicast', false)
                )
              )
            ),
            HBox(
              Label('Number of rings:'),
              ComboBox(Id(:number_of_rings), Opt(:notify), '', ['1', '2', '3'])
            ),
            HBox(
              HSpacing(20),
              ReplacePoint(Id(:rp_table), Empty()),
              HSpacing(20)
            ),
            PushButton(Id(:edit_ring), _('Edit selected')),
            InputField(Id(:cluster_name), _('Cluster name:'), ''),
            InputField(Id(:expected_votes), _('Expected votes:'), '')
          )
        ),
        SAPHAHelpers.load_html_help('help_comm_layer.html'),
        true,
        true
      )
      refresh_view
    end

    def can_go_next
      super
    end

    protected

    def refresh_view
      super
      UI.ChangeWidget(Id(@my_model.transport_mode), :Value, true)
      UI.ChangeWidget(Id(:number_of_rings), :Value, @my_model.number_of_rings.to_s)
      if @recreate_table
        @recreate_table = false
      UI.ReplaceWidget(Id(:rp_table), table_widget)
      end
      UI.ChangeWidget(Id(:ring_definition_table), :Items, @my_model.table_items)
      log.warn "--- #{self.class}.#{__callee__}: table items #{@my_model.table_items} ---"
      UI.ChangeWidget(Id(:cluster_name), :Value, @my_model.cluster_name)
      UI.ChangeWidget(Id(:expected_votes), :Value, @my_model.expected_votes.to_s)
    end

    def table_widget
      Table(
        Id(:ring_definition_table),
        Opt(:keepSorting, :immediate),
        multicast? ? 
          Header(_('Ring'), _('Address'), _('Port'), _('Multicast Address')) 
          : Header(_('Ring'), _('Address'), _('Port')),
        []
      )
    end

    def multicast?
      UI.QueryWidget(Id(:multicast), :Value)
    end

    def handle_user_input(input)
      log.debug "--- #{self.class}.#{__callee__}: user input: #{input} ---"
      super
      case input
      when :edit_ring
        item_id = UI.QueryWidget(Id(:ring_definition_table), :Value)
        values = ring_configuration_popup(@my_model.ring_info(item_id))
        if !values.nil? && !values.empty?
          @my_model.update_ring(item_id, values)
          refresh_view
        end
      when :number_of_rings
        number = Integer(UI.QueryWidget(Id(:number_of_rings), :Value))
        log.warn "--- #{self.class}.#{__callee__}: calling @my_model.number_of_rings= ---"
        @my_model.number_of_rings = number
        @model.cluster_members.number_of_rings = number
        refresh_view
      when :multicast, :unicast
        @my_model.transport_mode = input
        @recreate_table = true
        refresh_view
      else
        log.warn "--- #{self.class}.#{__callee__}: Unexpected user input: #{input} ---"
      end
    end

    # Returns the ring configuration parameters
    def ring_configuration_popup(ring)
      # TODO: validate user input here
      log.debug "--- #{self.class}.#{__callee__} --- "
      base_popup(
        "Configuration for Ring #{ring[:id]}",
        nil,
        InputField(Id(:address), 'Address:', ring[:address]),
        InputField(Id(:port), 'Port:', ring[:port]),
        multicast? ? 
          InputField(Id(:mcast), 'Multicast Address', ring[:mcast])
          : Empty()
      )
    end
  end
end
