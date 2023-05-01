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
# Summary: SUSE High Availability Setup for SAP Products: Fencing Mechanism Configuration Page
# Authors: Ilya Manyugin <ilya.manyugin@suse.com>
# Authors: Peter Varkoly <varkoly@suse.com>

require 'yast'
require "yast/i18n"
require 'sap_ha/helpers'
require 'sap_ha/wizard/base_wizard_page'

module SapHA
  module Wizard
    # Fencing Mechanism Configuration Page
    class FencingConfigurationPage < BaseWizardPage
      def initialize(model)
        super(model)
        textdomain "hana-ha"
        @my_model = model.fencing
        @page_validator = @my_model.method(:validate)
      end

      def set_contents
        super
        Yast::Wizard.SetContents(
          _('Fencing Mechanism'),
          base_layout_with_label(
            'Choose STONITH method',
            VBox(
              ComboBox(Id(:stonith_method), Opt(:hstretch), 'STONITH method:', ['SBD', 'IPMI']),
              HBox(
                MinHeight(5,
                  Table(
                    Id(:sbd_dev_list_table),
                    Opt(:keepSorting, :immediate),
                    Header(_('#'), _('Device path')),
                    @model.fencing.table_items
                  )
                )
              ),
              HBox(
                PushButton(Id(:add_sbd_device), _('Add')),
                PushButton(Id(:remove_sbd_device), _('Remove'))
              ),
              VSpacing(1),
              InputField(Id(:sbd_options), Opt(:hstretch), 'SBD options:', ''),
              VSpacing(1),
              CheckBox(Id(:sbd_delayed_start), Opt(:hstretch), 'Delay SBD start'),
              VSpacing(1),
              Label(_("Note that all data on the selected devices will be destroyed."))
            )
          ),
          Helpers.load_help('fencing'),
          true,
          true
        )
      end

      def can_go_next?
        return true if @model.no_validators
        @my_model.configured?
      end

      def refresh_view
        super
        set_value(:stonith_method, false, :Enabled)
        set_value(:sbd_dev_list_table, @my_model.table_items, :Items)
        set_value(:sbd_options, @my_model.sbd_options)
        set_value(:sbd_delayed_start, @my_model.sbd_delayed_start == 'yes' ? true : false)
      end

      def update_model
        @my_model.sbd_options = value(:sbd_options)
        @my_model.sbd_delayed_start = value(:sbd_delayed_start) ? 'yes' : 'no'
      end

      def handle_user_input(input, event)
        case input
        when :add_sbd_device
          update_model
          sbd_dev_configuration
        when :remove_sbd_device
          update_model
          @my_model.remove_device_by_id(value(:sbd_dev_list_table, :CurrentItem))
          refresh_view
        else
          super
        end
      end

      def sbd_dev_configuration
        log.debug "--- #{self.class}.#{__callee__} --- "
        items = @model.fencing.combo_items
        Yast::UI.OpenDialog(
          VBox(
            Label(Opt(:boldFont), 'SBD Device Configuration'),
            ComboBox(Id(:sbd_combo), Opt(:notify, :hstretch), 'Type:', items),
            MinSize(55, 11,
              SelectionBox(Id(:sbd_ids), Opt(:notify, :immediate), 'Identifiers:', [])),
            TextEntry(Id(:dev_path), Opt(:hstretch), 'Device path:', ''),
            Yast::Wizard.CancelOKButtonBox
          )
        )
        handle_combo
        loop do
          ui = Yast::UI.UserInput
          case ui
          when :ok
            dev_path = value(:dev_path)
            ret = SapHA::SemanticChecks.instance.check_popup(
              @my_model.method(:popup_validator), dev_path
            )
            unless ret.empty?
              show_dialog_errors(ret)
              next
            end
            @my_model.add_device(dev_path)
            Yast::UI.CloseDialog
            refresh_view
            break
          when :cancel
            Yast::UI.CloseDialog
            break
          when :sbd_combo
            handle_combo
          when :sbd_ids
            handle_id
          end
        end
      end

      private

      def handle_combo
        dev_type = value(:sbd_combo)
        dev_ids = @my_model.list_items(dev_type)
        set_value(:sbd_ids, dev_ids, :Items)
        handle_id
        # Yast::UI.RecalcLayout
      end

      def handle_id
        dev_type = value(:sbd_combo)
        dev_id = value(:sbd_ids)
        path = @my_model.proposals[dev_type][dev_id]
        set_value(:dev_path, path)
      end
    end
  end
end
