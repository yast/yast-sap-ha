require 'yast'
require 'sap_ha/helpers'
require 'sap_ha_wizard/base_wizard_page'
Yast.import 'IP'
Yast.import 'Hostname'
Yast.import 'Report'

module Yast
  # Communication Layer Configuration Page
  class CommLayerConfigurationPage < BaseWizardPage
    # TODO: upon initialization, simply set as many rings as there are interfaces,
    # putting X.X.0.0 as the bind IP address
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
            Left(PushButton(Id(:join_cluster), 'Join existing cluster')),
            VBox(
              Label('Transport mode:'),
              RadioButtonGroup(
                Id(:transport_mode),
                HBox(
                  RadioButton(Id(:unicast), Opt(:notify), 'Unicast', true),
                  RadioButton(Id(:multicast), Opt(:notify), 'Multicast', false)
                )
              )
            ),

            Frame('',
              VBox(
                ComboBox(Id(:number_of_rings), Opt(:notify), 'Number of rings:', ['1', '2', '3']),
                HBox(
                  HSpacing(25),
                  ReplacePoint(Id(:rp_table), Empty()),
                  HSpacing(25)
                ),
                PushButton(Id(:edit_ring), _('Edit selected'))
              ),
            ),
            HBox(
            InputField(Id(:cluster_name), _('Cluster name:'), ''),
            InputField(Id(:expected_votes), _('Expected votes:'), '')
            )
          )
        ),
        SAPHAHelpers.instance.load_html_help('help_comm_layer.html'),
        true,
        true
      )
      refresh_view
    end

    def can_go_next
      # super
      return true if @model.no_validators
      if !@model.cluster_members.configured?
        @my_model.all_rings.each do |ring_id, ring|
          @model.cluster_members.nodes.each do |node_id, values|
            v = values.dup
            nring_id = ('ip_' + ring_id.to_s).to_sym
            v[nring_id] = (ring[:address].split('.')[0..2] << 'X').join('.')
            @model.cluster_members.update_values(node_id, v)
          end
        end
      end
      true
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
      UI.ChangeWidget(Id(:cluster_name), :Value, @my_model.cluster_name)
      UI.ChangeWidget(Id(:expected_votes), :Value, @my_model.expected_votes.to_s)
    end

    def table_widget
      log.debug "--- #{self.class}.#{__callee__} ---"
        MinSize(
          @my_model.transport_mode == :multicast ? 26 : 21, # Width: ring name 5 + address 15 + port 5
          Integer(@my_model.number_of_rings)*1.5, 
          Table(
            Id(:ring_definition_table),
            Opt(:keepSorting),
            multicast? ? 
              Header(_('Ring'), _('Address'), _('Port'), _('Multicast Address')) 
              : Header(_('Ring'), _('Address'), _('Port')),
            []
          )
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
        @recreate_table = true
        refresh_view
      when :multicast, :unicast
        @my_model.transport_mode = input
        @recreate_table = true
        refresh_view
      when :join_cluster # won't happen ever
        return :join_cluster
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
        MinWidth(15, InputField(Id(:address), 'Address:', ring[:address])),
        MinWidth(5, InputField(Id(:port), 'Port:', ring[:port])),
        multicast? ? 
          MinWidth(15, InputField(Id(:mcast), 'Multicast Address', ring[:mcast]))
          : Empty()
      )
    end
  end
end
