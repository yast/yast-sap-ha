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

require 'yast'
require 'sap_ha/helpers'
require 'sap_ha_wizard/base_wizard_page'

module Yast
  # Fencing Mechanism Configuration Page
  class FencingConfigurationPage < BaseWizardPage
    def initialize(model)
      super(model)
      @my_model = model.fencing
      @my_model.read_system
    end

    def set_contents
      super
      Wizard.SetContents(
        _('Fencing Mechanism'),
        base_layout_with_label(
          'Choose the STONITH method',
          VBox(
            VBox(
              HBox(
                Label('STONITH Method:'),
                ComboBox(Id(:stonith_method), '', ['SBD', 'IPMI'])
                )
              ),
            HBox(
              HSpacing(20),
              Table(
                Id(:sbd_dev_list_table),
                Opt(:keepSorting, :immediate),
                Header(_('#'), _('Mount Point'), _('Type'), _('UUID')),
                @model.fencing.table_items
              ),
              HSpacing(20)
            ),
            HBox(
              PushButton(Id(:add_sbd_device), _('Add')),
              PushButton(Id(:remove_sbd_device), _('Remove'))
            ),
            InputField(Id(:sbd_options), 'SBD Options', ''),
            ComboBox(Id(:sbd_delayed_start), 'Delay SBD Start', ['no', 'yes']),
            VSpacing(1),
            Label(_("Note that all the data on the selected devices WILL BE DESTROYED."))
          )
        ),
        SAPHAHelpers.instance.load_help('help_fencing.html'),
        true,
        true
      )
      UI.ChangeWidget(Id(:stonith_method), :Enabled, false)
    end

    def can_go_next
      return true if @model.no_validators
      @my_model.configured?
    end

    def refresh_view
      super
      set_value(:sbd_dev_list_table, @my_model.table_items, :Items)
      set_value(:sbd_options, @my_model.sbd_options)
      set_value(:sbd_delayed_start, @my_model.sbd_delayed_start)
    end

    def update_model
      @my_model.sbd_options = value(:sbd_options)
      @my_model.sbd_delayed_start = value(:sbd_delayed_start)
    end

    def handle_user_input(input, event)
      case input
      when :add_sbd_device
        sbd_dev_configuration
      when :remove_sbd_device
        item_id = UI.QueryWidget(Id(:sbd_dev_list_table), :CurrentItem)
        @my_model.remove_device_by_id(item_id)
        refresh_view
      else
        super
      end
    end

    def sbd_dev_configuration
      log.debug "--- #{self.class}.#{__callee__} --- "
      items = @model.fencing.combo_items
      UI.OpenDialog(
        VBox(
          Label(Opt(:boldFont), 'SBD Device Configuration'),
          Left(
            HBox(
              Label(Opt(:boldFont), 'Device:'),
              ComboBox(Id(:sbd_combo), Opt(:notify), '', items))),
          VBox(
            Left(HBox(Label(Opt(:boldFont), 'Name:'), Label(Id(:sbd_name), ''))),
            Left(HBox(Label(Opt(:boldFont), 'Type:'), Label(Id(:sbd_type), ''))),
            Left(HBox(Label(Opt(:boldFont), 'UUID:'), MinWidth(44, Label(Id(:sbd_uuid), ''))))
          ),
          Wizard.CancelOKButtonBox
        )
      )
      handle_combo
      loop do
        ui = UI.UserInput
        case ui
        when :ok
          v = UI.QueryWidget(Id(:sbd_combo), :Value)
          @my_model.add_device(v)
          UI.CloseDialog
          refresh_view
          break
        when :cancel
          UI.CloseDialog
          break
        when :sbd_combo
          handle_combo
        end
      end
    end

    private

    def handle_combo
      v = UI.QueryWidget(Id(:sbd_combo), :Value)
      log.info "--- combo event: value #{v} ---"
      log.info "--- values: #{@model.fencing.proposals} ---"
      item = @my_model.proposals.find { |e| e[:name] == v }
      UI.ChangeWidget(Id(:sbd_name), :Value, item[:name])
      UI.ChangeWidget(Id(:sbd_type), :Value, item[:type])
      UI.ChangeWidget(Id(:sbd_uuid), :Value, item[:uuid] || "N/A")
      UI.RecalcLayout
    end
  end
end
