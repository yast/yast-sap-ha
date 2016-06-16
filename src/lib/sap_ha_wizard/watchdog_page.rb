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
# Summary: SUSE High Availability Setup for SAP Products: Watchdog Configuration Page
# Authors: Ilya Manyugin <ilya.manyugin@suse.com>

require 'yast'
require 'sap_ha/helpers'
require 'sap_ha_wizard/base_wizard_page'

module Yast
  # Watchdog Configuration Page
  class WatchdogConfigurationPage < BaseWizardPage
    def initialize(model)
      super(model)
      @my_model = model.watchdog
    end

    def set_contents
      super
      Wizard.SetContents(
        _('Watchdog Setup'),
        base_layout_with_label(
          'Select the appropriate watchdog modules to load at system startup',
          VBox(
            HBox(
              HSpacing(20),
              SelectionBox(Id(:configured_wd), Opt(:notify, :immediate), 'Watchdogs to configure:', []),
              HSpacing(20)
              ),
            HBox(
              PushButton(Id(:add_wd), 'Add'),
              PushButton(Id(:remove_wd), 'Remove')
            ),
            HBox(
              HSpacing(20),
              SelectionBox(Id(:loaded_wd), 'Automatically loaded watchdogs:', []),
              HSpacing(20)
            )
          )
        ),
        SAPHAHelpers.instance.load_help('watchdog'),
        true,
        true
      )
    end

    def can_go_next
      return true if @model.no_validators
      true
    end

    def refresh_view
      super
      UI.ChangeWidget(Id(:configured_wd), :Items, @my_model.installed)
      UI.ChangeWidget(Id(:loaded_wd), :Items, @my_model.loaded)
    end

    def handle_user_input(input, event)
      case input
      when :add_wd
        to_add = wd_selection_popup
        return if to_add.nil?
        @my_model.add_to_config(to_add[:selected])
        refresh_view
      when :remove_wd
        to_remove = UI.QueryWidget(Id(:configured_wd), :CurrentItem)
        @my_model.remove_from_config(to_remove)
        refresh_view
      else
        super
      end
    end

    def wd_selection_popup
      log.debug "--- #{self.class}.#{__callee__} --- "
      base_popup(
        "Select a module to configure",
        nil,
        MinHeight(10,
          SelectionBox(Id(:selected), 'Available modules:', @my_model.proposals))
      )
    end
  end
end
