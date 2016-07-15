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

module SapHA
  module Wizard
    # Cluster Nodes Configuration Page
    class ClusterNodesConfigurationPage < BaseWizardPage
      def initialize(model)
        super(model)
        @my_model = @model.cluster
        @page_validator = @my_model.method(:validate_nodes)
        @show_errors = true
      end

      def set_contents
        super
        Yast::Wizard.SetContents(
          _('Cluster nodes'),
          base_layout_with_label(
            _('Define the cluster nodes configuration'),
            VBox(
              HBox(
                HSpacing(20),
                MinHeight(4, nodes_table),
                HSpacing(20)
              ),
              HBox(
                PushButton(Id(:add_node), _('Add node')),
                PushButton(Id(:edit_node), _('Edit selected')),
                PushButton(Id(:delete_node), _('Delete node'))
              ),
              InputField(Id(:expected_votes), _('Expected votes:'), '')
            )
          ),
          Helpers.load_help('cluster'),
          true,
          true
        )
      end

      def can_go_next?
        return true if @model.no_validators
        return false unless @my_model.configured?
        unless check_ssh_connectivity
          @show_errors = false
          return false
        end
        true
      end

      def show_errors?
        old = @show_errors
        @show_errors = true
        old
      end

      def refresh_view
        super
        if @my_model.fixed_number_of_nodes
          set_value(:add_node, false, :Enabled)
          set_value(:delete_node, false, :Enabled)
        end
        set_value(:node_definition_table, @my_model.nodes_table, :Items)
        set_value(:expected_votes, @my_model.expected_votes.to_s)
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
        @my_model.expected_votes = value(:expected_votes)
      end

      def nodes_table_header
        if @my_model.number_of_rings == 1
          Header(_('ID'), _('Host name'), _('IP in ring 1'))
        else
          Header(_('ID'), _('Host name'), _('IP in ring 1'), _('IP in ring 2'))
        end
      end

      def handle_user_input(input, event)
        case input
        when :edit_node
          edit_node
        when :node_definition_table
          edit_node if event['EventReason'] == 'Activated'
        else
          super
        end
      end

      def edit_node
        item_id = value(:node_definition_table)
        values = node_configuration_popup(@my_model.nodes[item_id])
        if !values.nil? && !values.empty?
          @my_model.update_node(item_id, values)
          refresh_view
        end
      end

      def node_configuration_popup(values)
        log.debug "--- #{self.class}.#{__callee__} --- "
        base_popup(
          "Configuration for node #{values[:node_id]}",
          @my_model.method(:node_validator),
          InputField(Id(:host_name), 'Host name:', values[:host_name] || ""),
          InputField(Id(:ip_ring1), 'IP in ring #1:', values[:ip_ring1] || ""),
          @my_model.number_of_rings == 2 ? InputField(Id(:ip_ring2),
            'IP in ring #2:', values[:ip_ring2] || "") : Empty(),
          # InputField(Id(:node_id), 'Node ID:', values[:node_id] || "")
        )
      end

      def check_ssh_connectivity
        @my_model.other_nodes.each do |ip|
          begin
            SapHA::System::SSH.instance.check_ssh(ip)
          rescue SSHAuthException => e
            log.error e.message
            password = password_prompt("Password is required for node #{ip}:")
            return false if password.nil?
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
          true
        end
      end
    end
  end
end