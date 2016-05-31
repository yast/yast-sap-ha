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
# Summary: SUSE High Availability Setup for SAP Products: Page for joining an existing cluster
# Authors: Ilya Manyugin <ilya.manyugin@suse.com>

require 'sap_ha_wizard/base_wizard_page'
require 'sap_ha_system/ssh'
require 'sap_ha_system/network'

module Yast
  # Page for joining an existing cluster
  class JoinClusterPage < BaseWizardPage
    def set_contents
      super
      Wizard.SetContents(
        _('Join an Existing Cluster'),
        base_layout_with_label(
          _("Please provide the IP address of the existing cluster"),
          VBox(
            InputField(Id(:ip_address), 'IP Address', ''),
            ComboBox(Id(:interface), 'Local Network Interface', HANetwork.list_all_interfaces),
            PushButton(Id(:join), 'Join Cluster')
          )
        ),
        SAPHAHelpers.instance.load_help('help_join_cluster.html'),
        true,
        true
      )
      refresh_view
    end

    def handle_user_input(input)
      case input
      when :join
        node_ip = value(:ip_address)
        # interface = value(:interface)
        begin
          SSH.instance.check_ssh(node_ip)
        rescue SSHAuthException
          passwd = password_prompt(node_ip)
          return if passwd.nil?
          begin
            SSH.instance.copy_keys(node_ip, true, passwd)
          rescue SSHException => e
            log.error e.message
            Popup.Error(e.message)
          end
        rescue SSHException => e
          Popup.Error(e.message)
        end
      else
        super
      end
    end

    def refresh_view
      super
    end

    def can_go_next
      return true if @model.no_validators
      super
    end
  end
end
