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
# Authors: Peter Varkoly <varkoly@suse.com>

require 'yast'
require "yast/i18n"
require 'sap_ha/helpers'
require 'sap_ha/wizard/base_wizard_page'

module SapHA
  module Wizard
    # Cluster Nodes Configuration Page
    class ClusterNodesConfigurationPage < BaseWizardPage
      def initialize(model)
        super(model)
	textdomain "hana-ha"
        @my_model = @model.cluster
        @page_validator = @my_model.method(:validate_nodes)
        @show_errors = true
      end

      def set_contents
        super
        Yast::Wizard.SetContents(
          _('Cluster nodes'),
          base_layout_with_label(
            _('Define cluster nodes\' configuration'),
            VBox(
              MinHeight(4, nodes_table),
              HBox(
                PushButton(Id(:add_node), _('Add node')),
                PushButton(Id(:edit_node), _('Edit selected')),
                PushButton(Id(:delete_node), _('Delete node'))
              ),
              HBox(
                two_widget_hbox(
                  InputField(Id(:expected_votes), Opt(:hstretch), _('Expected votes:'), ''),
                  VBox(Label(' '), Left(CheckBox(Id(:append_hosts), Opt(:stretch, :notify),
                    _('Append to /etc/hosts'))))
                )
              )
            )
          ),
          Helpers.load_help('cluster_nodes'),
          true,
          true
        )
      end

      def can_go_next?
        return true if @model.no_validators
        return false unless @my_model.configured?
        Yast::Popup.Feedback('Please wait', 'Checking SSH connection') do
          unless check_ssh_connectivity
            @show_errors = false
            return false
          end
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
          set_value(:expected_votes, false, :Enabled)
        end
        set_value(:node_definition_table, @my_model.nodes_table, :Items)
        set_value(:expected_votes, @my_model.expected_votes.to_s)
        set_value(:append_hosts, @my_model.append_hosts)
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
        @my_model.append_hosts = value(:append_hosts)
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
          update_model
          edit_node
        when :node_definition_table
          update_model
          edit_node if event['EventReason'] == 'Activated'
        when :append_hosts
          @my_model.append_hosts = value(:append_hosts)
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
          MinWidth(15, InputField(Id(:host_name), 'Host name:', values[:host_name] || "")),
          MinWidth(15, InputField(Id(:ip_ring1), 'IP in ring #1:', values[:ip_ring1] || "")),
          @my_model.number_of_rings == 2 ? MinWidth(15, InputField(Id(:ip_ring2),
            'IP in ring #2:', values[:ip_ring2] || "")) : Empty(),
          # InputField(Id(:node_id), 'Node ID:', values[:node_id] || "")
        )
      end

      def check_ssh_connectivity
        @my_model.other_nodes.each do |ip|
          begin
            SapHA::System::SSH.instance.check_ssh(ip)
          rescue SSHAuthException => e
            log.error e.message
            # Check if password is already present in the [imported] configuration
            password = @my_model.get_host_password(ip)
            password = password_prompt("Password is required for node #{ip}:") if password.nil?
            return false if password.nil?
            begin
              SapHA::System::SSH.instance.check_ssh_password(ip, password)
            rescue SSHAuthException => e
              # Yast::Popup.Error(e.message)
              show_message(e.message, 'Error')
              return false
            rescue SSHException => e
              # Yast::Popup.Error(e.message)
              show_message(e.message, 'Error')
              return false
            else
              @my_model.set_host_password(ip, password)
              Yast::Popup.Feedback('Please wait', 'Copying SSH keys') do
                SapHA::System::SSH.instance.copy_keys_to(ip, password)
              end
            end
          rescue SSHException => e
            # Yast::Popup.Error(e.message)
            show_message(e.message, 'Error')
            return false
          end
          true
        end
      end
    end
  end
end
