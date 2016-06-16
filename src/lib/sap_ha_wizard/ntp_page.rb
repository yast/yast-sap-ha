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
require 'sap_ha_wizard/base_wizard_page'

Yast.import 'Progress'

module Yast
  # NTP configuration page
  class NTPConfigurationPage < BaseWizardPage
    def initialize(model)
      super(model)
      @my_model = model.ntp
    end

    def set_contents
      super
      Wizard.SetContents(
        _('NTP Configuration'),
        base_layout_with_label(
          'Configure the Network Time Protocol settings',
          VBox(
              Label('Used servers:'),
              HBox(
                HSpacing(20),
                SelectionBox(Id(:ntp_servers), '', []),
                HSpacing(20)
              ),
              VSpacing(),
              HBox(Label('Starts at boot:'),
                Label(Id(:ntp_enabled), '')),
              VSpacing(),
              PushButton(Id(:ntp_configure), 'Reconfigure')
          )
        ),
        SAPHAHelpers.instance.load_help('ntp'),
        true,
        true
      )
    end


    def can_go_next
      return true if @model.no_validators
      return false unless @my_model.configured?
      true
    end

    def handle_user_input(input, event)
      case input
      when :ntp_configure
        if WFM.ClientExists('ntp-client')
          WFM.CallFunction('ntp-client', [])
          # NTP Client rewrites the heading
          Wizard.SetDialogTitle("SAP High-Availability")
        else
          Popup.Error('Could not find the yast-ntp-client module!')
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
      UI.ChangeWidget(Id(:ntp_servers), :Items, @my_model.used_servers)
      UI.ChangeWidget(Id(:ntp_enabled), :Value, @my_model.start_at_boot?.to_s)
      UI.RecalcLayout
    end
  end
end
