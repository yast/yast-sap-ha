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
# Authors: Peter Varkoly <varkoly@suse.com>

require "yast/i18n"
require 'sap_ha/wizard/base_wizard_page'
require 'sap_ha/system/ssh'
require 'sap_ha/system/local'
require 'sap_ha/system/network'

module SapHA
  module Wizard
    # Page for joining an existing cluster
    class JoinClusterPage < BaseWizardPage

      def initialize
           texdomain "hana-ha"
      end	      

      def set_contents
        super
        Yast::Wizard.SetContents(
          _('Join an Existing Cluster'),
          base_layout_with_label(
            _("Please provide the IP address of the existing cluster"),
            VBox(
              InputField(Id(:ip_address), 'IP Address', ''),
              ComboBox(Id(:interface), 'Local Network Interface',
                SapHA::System::Network.interfaces),
              PushButton(Id(:join), 'Join Cluster')
            )
          ),
          SapHA::Helpers.load_help('join_cluster'),
          true,
          true
        )
        refresh_view
      end

      def handle_user_input(input, event)
        case input
        when :join
          node_ip = value(:ip_address)
          # interface = value(:interface)
          begin
            SapHA::System::SSH.instance.check_ssh(node_ip)
          rescue SSHAuthException
            passwd = password_prompt(node_ip)
            return if passwd.nil?
            begin
              SapHA::System::SSH.instance.copy_keys(node_ip, true, passwd)
            rescue SSHException => e
              log.error e.message
              Yast::Popup.Error(e.message)
            end
          rescue SSHException => e
            Yast::Popup.Error(e.message)
          end
        else
          super
        end
      end

      def refresh_view
        super
      end

      def can_go_next?
        return true if @model.no_validators
        super
      end
    end
  end
end
