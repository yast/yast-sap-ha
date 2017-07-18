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
# Summary: SUSE High Availability Setup for SAP Products: HANA configuration page
# Authors: Ilya Manyugin <ilya.manyugin@suse.com>

require 'yast'
require 'sap_ha/helpers'
require 'sap_ha/wizard/base_wizard_page'

module SapHA
  module Wizard
    # NTP configuration page
    class NTPConfigurationPage < BaseWizardPage
      def initialize(model)
        super(model)
        @my_model = model.ntp
        @page_validator = @my_model.method(:validate)
      end

      def set_contents
        super
        Yast::Wizard.SetContents(
          _('NTP Configuration'),
          base_layout_with_label(
            'Configure Network Time Protocol client',
            VBox(
              SelectionBox(Id(:ntp_servers), 'Used servers:', []),
              PushButton(Id(:ntp_configure), 'Reconfigure'),
              HBox(
                Label('Starts at boot:'),
                Label(Id(:ntp_enabled), '')
              )
            )
          ),
          Helpers.load_help('ntp'),
          true,
          true
        )
      end


      def can_go_next?
        return true if @model.no_validators
        return false unless @my_model.configured?
        true
      end

      def handle_user_input(input, event)
        case input
        when :ntp_configure
          if Yast::WFM.ClientExists('ntp-client')
            Yast::WFM.CallFunction('ntp-client', [])
            # NTP Client rewrites the heading
            Yast::Wizard.SetDialogTitle("HA Setup for SAP Products")
          else
            Yast::Popup.Error('Could not find the yast-ntp-client module!')
            continue
          end
          @my_model.read_configuration
          refresh_view
        else
          super
        end
      end

      def refresh_view
        super
        set_value(:ntp_servers, @my_model.used_servers, :Items)
        set_value(:ntp_enabled, @my_model.start_at_boot?.to_s)
        Yast::UI.RecalcLayout
      end
    end
  end
end
