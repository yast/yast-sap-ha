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
Yast.import 'IP'
Yast.import 'Hostname'
Yast.import 'Report'

module Yast
  # Fencing Mechanism Configuration Page
  class FencingConfigurationPage < BaseWizardPage
    def initialize(model)
      super(model)
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
                @model.stonith.table_items
              ),
              HSpacing(20)
            ),
            HBox(
              PushButton(Id(:add_sbd_device), _('Add')),
              PushButton(Id(:remove_sbd_device), _('Remove'))
            ),
            VSpacing(3),
            Label(_("Note that all the data on the selected devices WILL BE DESTROYED."))
          )
        ),
        '',
        true,
        true
      )
      UI.ChangeWidget(Id(:stonith_method), :Enabled, false)
    end

    def can_go_next
      return true if @model.debug
      true
    end

    def refresh_view
      super
      UI.ChangeWidget(Id(:sbd_dev_list_table), :Items, @model.stonith.table_items)
      # entries = @model.conf_nodes.table_items.map { |entry| Item(Id(entry[0]), *entry[1..-1]) }
      # log.info "Table items: #{entries.inspect}"
      # UI.ChangeWidget(Id(:ring_definition_table), :Items, entries)
    end

    def handle_user_input(input)
      case input
      when :add_sbd_device
        sbd_dev_configuration
      when :remove_sbd_device
        item_id = UI.QueryWidget(Id(:sbd_dev_list_table), :Value)
        log.debug "--- removing item #{item_id} from the table of SBD devices"
      else
        super
      end
    end

    def sbd_dev_configuration
      log.debug "--- #{self.class}.#{__callee__} --- "
      items = @model.stonith.combo_items
      UI.OpenDialog(
        VBox(
          Left(Label(Opt(:boldFont), 'SBD Device Configuration')),
          Left(
            HBox(
              Label('Device:'),
              ComboBox(Id(:sbd_combo), Opt(:notify), '', items))),
          VBox(
            Left(HBox(Label('Name:'), Label(Id(:sbd_name), ''))),
            Left(HBox(Label('Type:'), Label(Id(:sbd_type), ''))),
            Left(HBox(Label('UUID:'), MinWidth(44, Label(Id(:sbd_uuid), ''))))
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
          @model.stonith.add_to_config(v)
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
      log.info "--- values: #{@model.stonith.proposals} ---"
      item = @model.stonith.proposals.find { |e| e[:name] == v }
      UI.ChangeWidget(Id(:sbd_name), :Value, item[:name])
      UI.ChangeWidget(Id(:sbd_type), :Value, item[:type])
      UI.ChangeWidget(Id(:sbd_uuid), :Value, item[:uuid] || "")
      UI.RecalcLayout
    end
  end
end
