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
require 'sap_ha_wizard/base_wizard_page'
require 'sap_ha/semantic_checks'

module Yast
  # Cluster Nodes Configuration Page
  class ClusterMembersConfigurationPage < BaseWizardPage
    def initialize(model)
      super(model)
      @my_model = @model.cluster_members
    end

    def set_contents
      # TODO: NW allow adding nodes if !@my_model.fixed_number_of_nodes?
      super
      Wizard.SetContents(
        _('Cluster Members'),
        base_layout_with_label(
          _('Define cluster member nodes'),
          VBox(
            HBox(
              HSpacing(20),
              table_widget,
              HSpacing(20)
            ),
            HBox(
              PushButton(Id(:add_node), _('Add node')),
              PushButton(Id(:edit_node), _('Edit selected')),
              PushButton(Id(:delete_node), _('Delete node'))
            )
          )
        ),
        SAPHAHelpers.instance.load_help('help_cluster_members.html'),
        true,
        true
      )
    end

    def can_go_next
      return true if @model.no_validators
      flag = @my_model.nodes.all? { |_, v| node_configuration_validators(v, false) }
      # check SSH connectivity
      ips = @my_model.other_nodes
      ips.each do |ip|
        begin
          SSH.instance.check_ssh(ip)
        rescue SSHAuthException => e
          log.error e.message
          password = password_prompt("Password is required for node #{ip}:")
          begin
            SSH.instance.check_ssh_password(ip, password)
          rescue SSHAuthException => e
            Popup.Error(e.message)
            return false
          rescue SSHException => e
            Popup.Error(e.message)
            return false
          else
            SSH.instance.copy_keys_to(ip, password)
          end
        rescue SSHException => e
          Popup.Error(e.message)
          return false
        end
      end
      dialog_cannot_continue unless flag
      flag
    end

    def refresh_view
      super
      if @my_model.fixed_number_of_nodes?
        UI.ChangeWidget(Id(:add_node), :Enabled, false)
        UI.ChangeWidget(Id(:delete_node), :Enabled, false)
      end
      UI.ChangeWidget(Id(:node_definition_table), :Items, @my_model.table_items)
    end

    def table_widget
      Table(
        Id(:node_definition_table),
        Opt(:keepSorting),
        header,
        []
      )
    end

    def header
      case @my_model.number_of_rings
      when 1
        Header(_('Host name'), _('IP Ring 1'), _('Node ID'))
      when 2
        Header(_('Host name'), _('IP Ring 1'), _('IP Ring 2'), _('Node ID'))
      when 3
        Header(_('Host name'), _('IP Ring 1'), _('IP Ring 3'), _('IP Ring 3'), _('Node ID'))
      end
    end

    def handle_user_input(input)
      case input
      when :edit_node
        item_id = UI.QueryWidget(Id(:node_definition_table), :Value)
        values = node_configuration_popup(@my_model.node_parameters(item_id))
        Report.ClearErrors
        log.info "Return from ring_configuration_popup: #{values}"
        if !values.nil? && !values.empty?
          @my_model.update_values(item_id, values)
          refresh_view
        end
      else
        super
      end
    end

    def node_configuration_popup(values)
      log.debug "--- #{self.class}.#{__callee__} --- "
      base_popup(
        "Configuration for Node #{values[:node_id]}",
        -> (args) { node_configuration_validators(args) },
        InputField(Id(:host_name), 'Host name:', values[:host_name] || ""),
        InputField(Id(:ip_ring1), 'IP Ring 1:', values[:ip_ring1] || ""),
        @my_model.number_of_rings > 1 ? InputField(Id(:ip_ring2), 'IP Ring 2:', values[:ip_ring2] || "") : Empty(),
        @my_model.number_of_rings > 2 ? InputField(Id(:ip_ring3), 'IP Ring 3:', values[:ip_ring3] || "") : Empty(),
        InputField(Id(:node_id), 'Node ID:', values[:node_id] || "")
      )
    end

    def node_configuration_validators(values, report = true)
      return true unless report
      errors = SemanticChecks.instance.verbose_check do |check|
        check.ipv4(values[:ip_ring1], 'IP Ring 1')
        check.ipv4(values[:ip_ring2], 'IP Ring 2') if @my_model.number_of_rings > 1
        check.ipv4(values[:ip_ring3], 'IP Ring 3') if @my_model.number_of_rings > 2
        check.hostname(values[:host_name], 'Hostname')
      end
      return true if errors.empty?
      show_dialog_errors(errors)
      false
    end
  end
end
