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
# Authors: Peter Varkoly <varkoly@suse.com>

require 'yast'
require "yast/i18n"
require 'sap_ha/helpers'
require 'sap_ha/wizard/base_wizard_page'

module SapHA
  module Wizard
    # Watchdog Configuration Page
    class WatchdogConfigurationPage < BaseWizardPage
      def initialize(model)
        super(model)
        textdomain "hana-ha"
        @my_model = model.watchdog
        @page_validator = @my_model.method(:validate)
      end

      def set_contents
        super
        Yast::Wizard.SetContents(
          _('Watchdog Setup'),
          base_layout_with_label(
            'Select appropriate watchdog modules to load at system startup',
            VBox(
              SelectionBox(Id(:wd_to_configure), Opt(:notify, :immediate),
                'Watchdogs to configure:', []),
              HBox(
                PushButton(Id(:add_wd), 'Add'),
                PushButton(Id(:remove_wd), 'Remove')
              ),
              SelectionBox(Id(:configured_wd), Opt(:notify, :immediate),
                'Configured watchdogs:', []),
              SelectionBox(Id(:loaded_wd), 'Loaded watchdogs:', [])
            )
          ),
          Helpers.load_help('watchdog'),
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
        set_value(:wd_to_configure, @my_model.to_install, :Items)
        set_value(:configured_wd, @my_model.configured, :Items)
        set_value(:loaded_wd, @my_model.loaded, :Items)
      end

      def handle_user_input(input, event)
        case input
        when :add_wd
          to_add = wd_selection_popup
          return if to_add.nil?
          begin
            @my_model.add_to_config(to_add[:selected])
          rescue WatchdogConfigurationException => e
            show_dialog_errors([e.message], "Wrong selection")
          end
          refresh_view
        when :remove_wd
          to_remove = value(:wd_to_configure, :CurrentItem)
          @my_model.remove_from_config(to_remove)
          refresh_view
        else
          super
        end
      end

      def wd_selection_popup
        log.debug "--- #{self.class}.#{__callee__} --- "
        base_popup(
          "Select a module to add",
          nil,
          MinHeight(10,
            SelectionBox(Id(:selected), 'Available modules:', @my_model.proposals))
        )
      end
    end
  end
end
