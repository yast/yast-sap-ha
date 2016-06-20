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
    # HANA configuration page
    class HANAConfigurationPage < BaseWizardPage
      def initialize(model)
        super(model)
        @my_model = model.hana
      end

      def set_contents
        super
        Yast::Wizard.SetContents(
          _('HANA Configuration'),
          base_layout_with_label(
            'Set the HANA-specific parameters up',
            VBox(
              HBox(
                # Label('System ID:'),
                # InputField(Id(:hana_sid), '', '')
                InputField(Id(:hana_sid), 'System ID:', '')
                ),
              HBox(
                # Label('Instance number:'),
                # InputField(Id(:hana_inst), '', '')
                InputField(Id(:hana_inst), 'Instance number:', '')
                ),
              HBox(
                # Label(),
                InputField(Id(:hana_vip), 'Virtual IP Address:', '')  # TODO: validators
                ),
              HBox(
                # Label('Prefer Site Takeover:'),
                base_true_false_combo(:site_takover, 'Prefer Site Takeover:')
                # CheckBox(Id(:site_takover), 'Prefer Site Takeover:', true)
                ),
              HBox(
                # Label('Automatic Registration:'),
                base_true_false_combo(:auto_reg, 'Automatic Registration', false)
                # CheckBox(Id(:auto_reg), 'Automatic Registration', false)
                )
              )
          ),
          Helpers.load_help('hana'),
          true,
          true
        )
      end

      def update_model
        @my_model.system_id = value(:hana_sid).upcase
        @my_model.instance = value(:hana_inst)
        @my_model.virtual_ip = value(:hana_vip)
        @my_model.prefer_takeover = value(:site_takover)
        @my_model.auto_register = value(:auto_reg)
      end

      def can_go_next
        return true if @model.no_validators
        @my_model.configured?
      end

      def refresh_view
        super
        set_value(:hana_sid, @my_model.system_id)
        set_value(:hana_inst, @my_model.instance)
        set_value(:hana_vip, @my_model.virtual_ip)
        set_value(:site_takover, @my_model.prefer_takeover)
        set_value(:auto_reg, @my_model.auto_register)
      end
    end
  end
end
