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
        @page_validator = @my_model.method(:validate)
      end

      def set_contents
        super
        Yast::Wizard.SetContents(
          _('HANA Configuration'),
          base_layout_with_label(
            'Set the HANA-specific parameters up',
            VBox(
              HBox(
                InputField(Id(:hana_sid), 'System ID:', ''),
                InputField(Id(:hana_inst), 'Instance number:', '')
              ),
              InputField(Id(:hana_vip), 'Virtual IP address:', ''), # TODO: validators
              HBox(
                base_true_false_combo(:site_takover, 'Prefer site takeover:'),
                base_true_false_combo(:auto_reg, 'Automatic registration')
              ),
              HBox(
                InputField(Id(:site_name_1), 'Site name 1', ''),
                InputField(Id(:site_name_2), 'Site name 2', '')
              ),
              PushButton(Id(:configure_backup), 'Backup settings...')
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
        @my_model.prefer_takeover = value(:site_takover) == :true
        @my_model.auto_register = value(:auto_reg) == :true
        @my_model.site_name_1 = value(:site_name_1).upcase
        @my_model.site_name_2 = value(:site_name_2).upcase
      end

      def can_go_next?
        return true if @model.no_validators
        @my_model.configured?
      end

      def refresh_view
        super
        set_value(:hana_sid, @my_model.system_id)
        set_value(:hana_inst, @my_model.instance)
        set_value(:hana_vip, @my_model.virtual_ip)
        set_value(:site_takover, @my_model.prefer_takeover.to_s.to_sym)
        set_value(:auto_reg, @my_model.auto_register.to_s.to_sym)
        set_value(:site_name_1, @my_model.site_name_1)
        set_value(:site_name_2, @my_model.site_name_2)
      end

      def handle_user_input(input, event)
        case input
        when :configure_backup
          values = hana_backup_popup
          log.error "--- #{self.class}.#{__callee__} backup settings: #{values} --- "
          @my_model.import(values)
        else
          super
        end
      end

      def hana_backup_popup
        log.debug "--- #{self.class}.#{__callee__} --- "
        base_popup(
          "Initial HANA Backup Settings",
          @my_model.method(:hana_backup_validator),
          Left(CheckBox(Id(:perform_backup), 'Perform backup', @my_model.perform_backup)),
          InputField(Id(:backup_file), 'Backup file name:', @my_model.backup_file),
          InputField(Id(:backup_user), 'Backup user:', @my_model.backup_user)
        )
      end
    end
  end
end
