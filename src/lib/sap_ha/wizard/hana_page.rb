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
# Authors: Peter Varkoly <varkoly@suse.com>

require "yast"
require "yast/i18n"
require "sap_ha/helpers"
require "sap_ha/wizard/base_wizard_page"

module SapHA
  module Wizard
    # HANA configuration page
    class HANAConfigurationPage < BaseWizardPage
      def initialize(model)
        super(model)
        textdomain "hana-ha"
        @my_model = model.hana
        @my_config = model
        @page_validator = @my_model.method(:validate)
        prepare_contents
      end

      def set_contents
        super
        help_file = @my_model.additional_instance ? "hana_cost_optimized" : "hana"
        Yast::Wizard.SetContents(
          _("HANA Configuration"),
          base_layout_with_label(
            "Set HANA-specific parameters",
            @contents
          ),
          # Helpers.load_help(help_file, @my_config.platform),
          # The HANA Page instructions are generic for all the platforms.
          Helpers.load_help(help_file),
          true,
          true
        )
      end

      def update_model
        @my_model.system_id = value(:hana_sid).upcase
        @my_model.instance = value(:hana_inst)
        @my_model.replication_mode = value(:hana_replication_mode)
        @my_model.operation_mode = value(:hana_operation_mode)
        @my_model.virtual_ip = value(:hana_vip)
        @my_model.prefer_takeover = value(:site_takover) == :true
        @my_model.auto_register = value(:auto_reg) == :true
        @my_model.site_name_1 = value(:site_name_1).upcase
        @my_model.site_name_2 = value(:site_name_2).upcase
        @my_model.perform_backup = value(:create_backup)
        @my_model.virtual_ip_mask = value(:hana_vip_mask)
        if @my_model.additional_instance
          @my_model.np_system_id = value(:np_hana_sid).upcase
          @my_model.np_instance = value(:np_hana_inst)
        end
      end

      def can_go_next?
        return true if @model.no_validators
        @my_model.configured?
      end

      def refresh_view
        super
        set_value(:hana_sid, @my_model.system_id)
        set_value(:hana_inst, @my_model.instance)
        set_value(:hana_replication_mode, @my_model.replication_mode)
        set_value(:hana_operation_mode, @my_model.operation_mode)
        set_value(:hana_vip, @my_model.virtual_ip)
        set_value(:site_takover, @my_model.prefer_takeover.to_s.to_sym)
        set_value(:auto_reg, @my_model.auto_register.to_s.to_sym)
        set_value(:site_name_1, @my_model.site_name_1)
        set_value(:site_name_2, @my_model.site_name_2)
        set_value(:create_backup, @my_model.perform_backup)
        set_value(:configure_backup, @my_model.perform_backup, :Enabled)
        set_value(:hana_vip_mask, @my_model.virtual_ip_mask)
        if @my_model.additional_instance
          set_value(:np_hana_sid, @my_model.np_system_id)
          set_value(:np_hana_inst, @my_model.np_instance)
        end
      end

      def handle_user_input(input, event)
        case input
        when :configure_backup
          update_model
          values = hana_backup_popup
          @my_model.import(values)
          refresh_view
        when :create_backup
          update_model
          refresh_view
        when :hana_replication_mode
          update_model
          refresh_view
        when :production_constraints
          update_model
          production_constraints = hana_production_constraints_popup(
            @my_model.production_constraints
          )
          return unless production_constraints
          @my_model.production_constraints = production_constraints
        when :hook_script_params
          update_model
          unless @my_model.hook_generated?
            hook_parameters = hook_script_popup(@my_model.hook_script_parameters)
            return unless hook_parameters
            @my_model.hook_script_parameters = hook_parameters
          end
          ret = generate_and_show_hook
          return unless ret
          @my_model.hook_script = ret[:hook_script]
        else
          super
        end
      end

      def hana_backup_popup
        log.debug "--- #{self.class}.#{__callee__} --- "
        base_popup_new(
          "Initial HANA Backup Settings",
          @my_model.method(:hana_backup_validator),
          { create_key: method(:secure_store_key_popup) },
          InputField(Id(:backup_file), "Backup file name:", @my_model.backup_file),
          InputField(Id(:backup_user), "Secure store key:", @my_model.backup_user)
        )
      end

      # Set up constraints for the production SAP HANA system
      def hana_production_constraints_popup(values)
        log.debug "--- #{self.class}.#{__callee__} --- "
        base_popup(
          "Production system constraints",
          @my_model.method(:production_constraints_validation),
          MinWidth(20, InputField(Id(:global_alloc_limit), "Global &allocation limit (in MB):",
            values[:global_alloc_limit] || "")),
          MinWidth(20, InputField(Id(:preload_column_tables), "&Preload column tables:",
            values[:preload_column_tables] || ""))
        )
      end

      def hook_script_popup(values)
        log.debug "--- #{self.class}.#{__callee__} --- "
        base_popup(
          "Hook script parameters",
          # TODO: write validators for the popups
          @my_model.method(:hook_script_validation),
          MinWidth(15, InputField(Id(:hook_execution_order), "&Execution order:",
            values[:hook_execution_order] || "")),
          InputField(Id(:hook_db_user_name), Opt(:hstretch), "DB &user name:",
            values[:hook_db_user_name] || ""),
          Password(Id(:hook_db_password), Opt(:hstretch), "DB &password:",
            values[:hook_db_password] || ""),
          InputField(Id(:hook_port_number), Opt(:hstretch), "&Port number:",
            values[:hook_port_number] || "")
        )
      end

      def generate_and_show_hook
        txt = @my_model.hook_script
        base_popup(
          "Please review the script",
          nil,
          MinSize(75, 20, MultiLineEdit(Id(:hook_script), "Hook script (Python):", txt))
        )
      end

      def prepare_contents
        # Production HANA
        @contents = VBox(
          two_widget_hbox(
            InputField(Id(:hana_sid), Opt(:hstretch), "System ID:", ""),
            InputField(Id(:hana_inst), Opt(:hstretch), "Instance number:", "")
          ),
          two_widget_hbox(
            ComboBox(Id(:hana_replication_mode), Opt(:hstretch, :notify),
              "Replication mode:", @my_model.class::HANA_REPLICATION_MODES),
            ComboBox(Id(:hana_operation_mode), Opt(:hstretch, :notify),
              "Operation mode:", @my_model.class::HANA_OPERATION_MODES)
          ),
          two_widget_hbox(
            InputField(Id(:hana_vip), Opt(:hstretch), "Virtual IP address:", ""),
            InputField(Id(:hana_vip_mask), Opt(:hstretch), "Virtual IP mask:", "")
          ),
          two_widget_hbox(
            base_true_false_combo(:site_takover, "Prefer site takeover:"),
            base_true_false_combo(:auto_reg, "Automatic registration:")
          ),
          two_widget_hbox(
            InputField(Id(:site_name_1), Opt(:hstretch), "Site name 1", ""),
            InputField(Id(:site_name_2), Opt(:hstretch), "Site name 2", "")
          ),
          two_widget_hbox(
            @my_model.additional_instance ?
            PushButton(Id(:production_constraints), Opt(:hstretch),
              "Production system constraints...") : CheckBox(Id(:create_backup),
                Opt(:hstretch, :notify), "Create initial backup"),
            PushButton(Id(:configure_backup), Opt(:hstretch), "Backup settings...")
          )
        )
        # Non-Production HANA
        if @my_model.additional_instance
          @contents << two_widget_hbox(
            Empty(),
            CheckBox(Id(:create_backup), Opt(:hstretch, :notify), "Create initial backup"),
            2.49
          )
          @contents = VBox(
            Frame("Production instance", Yast.deep_copy(@contents)),
            Frame("Non-production instance",
              VBox(
                two_widget_hbox(
                  InputField(Id(:np_hana_sid), Opt(:hstretch), "System ID:", ""),
                  InputField(Id(:np_hana_inst), Opt(:hstretch), "Instance number:", "")
                ),
                two_widget_hbox(
                  Empty(),
                  PushButton(Id(:hook_script_params), Opt(:hstretch), "Hook script...")
                )
              ))
          )
        end
      end

      def secure_store_key_popup
        log.debug "--- #{self.class}.#{__callee__} --- "
        base_popup(
          "Create a secure store key",
          nil,
          InputField(Id(:hook_db_user_name), Opt(:hstretch), "DB &user name:", "")
        )
      end
    end
  end
end
