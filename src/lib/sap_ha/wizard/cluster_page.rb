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
# Summary: SUSE High Availability Setup for SAP Products: Cluster Nodes Configuration Page
# Authors: Ilya Manyugin <ilya.manyugin@suse.com>

require 'yast'
require 'sap_ha/helpers'
require 'sap_ha/wizard/base_wizard_page'
require 'sap_ha/semantic_checks'

module SapHA
  module Wizard
    # Cluster Nodes Configuration Page
    class ClusterConfigurationPage < BaseWizardPage
      def initialize(model)
        super(model)
        @my_model = @model.cluster
        @recreate_table = true
      end

      def set_contents
        super
        Yast::Wizard.SetContents(
          _('Cluster'),
          base_layout_with_label(
            _('Define the cluster configuration'),
            VBox(
              VBox(
                HBox(
                  ComboBox(Id(:transport_mode), Opt(:notify), 'Transport mode:', ['Unicast', 'Multicast']),
                  HSpacing(3),
                  ComboBox(Id(:number_of_rings), Opt(:notify), 'Number of rings:', ['1', '2', '3'])
                ),
                HBox(
                  InputField(Id(:cluster_name), _('Cluster name:'), ''),
                  HSpacing(3),
                  InputField(Id(:expected_votes), _('Expected votes:'), '')
                ),
                VBox(
                  HBox(
                    HSpacing(20),
                    MinHeight(4,
                      ReplacePoint(Id(:rp_table), Empty())
                    ),
                    HSpacing(20)
                  ),
                  PushButton(Id(:edit_ring), _('Edit selected'))
                )
              ),
            # PushButton(Id(:join_cluster), 'Join existing cluster'),
              HBox(
                HSpacing(20),
                MinHeight(4,
                  nodes_table
                ),
                HSpacing(20)
              ),
              HBox(
                PushButton(Id(:add_node), _('Add node')),
                PushButton(Id(:edit_node), _('Edit selected')),
                PushButton(Id(:delete_node), _('Delete node'))
              ),
            )
          ),
          Helpers.load_help('cluster'),
          true,
          true
        )
      end

      def can_go_next
        return true if @model.no_validators
        return false unless @my_model.configured?
        # check SSH connectivity
        for ip in @my_model.other_nodes
          begin
            SapHA::System::SSH.instance.check_ssh(ip)
          rescue SSHAuthException => e
            log.error e.message
            password = password_prompt("Password is required for node #{ip}:")
            begin
              SapHA::System::SSH.instance.check_ssh_password(ip, password)
            rescue SSHAuthException => e
              Yast::Popup.Error(e.message)
              return false
            rescue SSHException => e
              Yast::Popup.Error(e.message)
              return false
            else
              SapHA::System::SSH.instance.copy_keys_to(ip, password)
            end
          rescue SSHException => e
            Yast::Popup.Error(e.message)
            return false
          end
        end
        true
      end

      def refresh_view
        super
        if @my_model.fixed_number_of_nodes
          set_value(:add_node, false, :Enabled)
          set_value(:delete_node, false, :Enabled)
        end
        # set_value(:join_cluster, false, :Enabled)
        # set_value(@my_model.transport_mode, true)
        set_value(:transport_mode, @my_model.transport_mode.to_s.capitalize)
        set_value(:number_of_rings, @my_model.number_of_rings.to_s)
        if @recreate_table
          @recreate_table = false
          Yast::UI.ReplaceWidget(Id(:rp_table), ring_table_widget)
        end
        set_value(:ring_definition_table, @my_model.rings_table_cont, :Items)
        set_value(:cluster_name, @my_model.cluster_name)
        set_value(:expected_votes, @my_model.expected_votes.to_s)
        set_value(:node_definition_table, @my_model.nodes_table_cont, :Items)
      end

      def nodes_table
        Table(
          Id(:node_definition_table),
          Opt(:keepSorting, :notify, :immediate),
          nodes_table_header,
          []
        )
      end

      def update_model
        @my_model.cluster_name = value(:cluster_name)
        @my_model.expected_votes = value(:expected_votes)
      end

      def ring_table_widget
        log.debug "--- #{self.class}.#{__callee__} ---"
        MinSize(
          # Width: ring name 5 + address 15 + port 5
          multicast? ? 26 : 21,
          Integer(@my_model.number_of_rings) * 1.7,
          Table(
            Id(:ring_definition_table),
            Opt(:keepSorting, :notify, :immediate),
            multicast? ?
              Header(_('Ring'), _('Address'), _('Port'), _('Multicast Address'))
              : Header(_('Ring'), _('Address'), _('Port')),
            []
          )
        )
      end

      def multicast?
        @my_model.transport_mode == :multicast
      end

      def nodes_table_header
        case @my_model.number_of_rings
        when 1
          Header(_('ID'), _('Host name'), _('IP Ring 1'))
        when 2
          Header(_('ID'), _('Host name'), _('IP Ring 1'), _('IP Ring 2'))
        when 3
          Header(_('ID'), _('Host name'), _('IP Ring 1'), _('IP Ring 3'), _('IP Ring 3'))
        end
      end

      def handle_user_input(input, event)
        case input
        when :edit_node
          edit_node
        when :edit_ring
          edit_ring
        when :number_of_rings
          number = Integer(value(:number_of_rings))
          log.warn "--- #{self.class}.#{__callee__}: calling @my_model.number_of_rings= ---"
          @my_model.number_of_rings = number
          @recreate_table = true
          refresh_view
        when :transport_mode
          @my_model.transport_mode = value(:transport_mode).downcase.to_sym
          @recreate_table = true
          refresh_view
        when :join_cluster # won't happen ever
          return :join_cluster
        when :ring_definition_table
          edit_ring if event['EventReason'] == 'Activated'
        when :node_definition_table
          edit_node if event['EventReason'] == 'Activated'
        else
          super
        end
      end

      def edit_ring
        item_id = value(:ring_definition_table)
        values = ring_configuration_popup(@my_model.ring_info(item_id))
        if !values.nil? && !values.empty?
          @my_model.update_ring(item_id, values)
          refresh_view
        end
      end

      def edit_node
        item_id = value(:node_definition_table)
        values = node_configuration_popup(@my_model.node_parameters(item_id))
        log.info "Return from ring_configuration_popup: #{values}"
        if !values.nil? && !values.empty?
          @my_model.update_values(item_id, values)
          refresh_view
        end
      end

      def node_configuration_popup(values)
        log.debug "--- #{self.class}.#{__callee__} --- "
        base_popup(
          "Configuration for node #{values[:node_id]}",
          -> (args) { @my_model.validate_node(args, :verbose) },
          InputField(Id(:host_name), 'Host name:', values[:host_name] || ""),
          InputField(Id(:ip_ring1), 'IP Ring 1:', values[:ip_ring1] || ""),
          @my_model.number_of_rings > 1 ? InputField(Id(:ip_ring2), 'IP Ring 2:', values[:ip_ring2] || "") : Empty(),
          @my_model.number_of_rings > 2 ? InputField(Id(:ip_ring3), 'IP Ring 3:', values[:ip_ring3] || "") : Empty(),
          InputField(Id(:node_id), 'Node ID:', values[:node_id] || "")
        )
      end

      # Returns the ring configuration parameters
      def ring_configuration_popup(ring)
        # TODO: validate user input here
        log.debug "--- #{self.class}.#{__callee__} --- "
        base_popup(
          "Configuration for ring #{ring[:id]}",
          -> (args) { @my_model.validate_ring(args, :verbose) },
          MinWidth(15, InputField(Id(:address), 'IP Address:', ring[:address])),
          MinWidth(5, InputField(Id(:port), 'Port Number:', ring[:port].to_s)),
          multicast? ?
            MinWidth(15, InputField(Id(:mcast), 'Multicast Address', ring[:mcast]))
            : Empty()
        )
      end

    end
  end
end
