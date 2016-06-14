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
# Summary: SUSE High Availability Setup for SAP Products: Setup summary page
# Authors: Ilya Manyugin <ilya.manyugin@suse.com>

require 'yast'
require 'sap_ha/helpers'
require 'sap_ha_system/node_logger'

module Yast
  # Setup summary page
  class SetupSummaryPage < BaseWizardPage
    attr_accessor :model

    def initialize(model)
      @config = model
    end

    def set_contents
      super
      Wizard.SetContents(
        "High-Availability Setup Summary",
        VBox(
          HBox(
            HSpacing(3),
            RichText(SapHA::NodeLogger.to_html(@config.zlog)),
            HSpacing(3)
          ),
          HBox(
            PushButton(Id(:save_log), 'Save Log')
          )
        ),
        '',
        false,
        true
      )
      # base_rich_text(
        
      #   # UI.TextMode ? SAPHAHelpers.instance.render_template('tmpl_config_overview_con.erb', binding) :
      #   # SAPHAHelpers.instance.render_template('tmpl_config_overview_gui.erb', binding),
      #   SapHA::NodeLogger.to_html(@config.zlog),
      #   # SAPHAHelpers.instance.load_help('help_setup_summary.html'),
      #   '',
      #   true,
      #   true
      # )
      # # Checkbox: save configuration
      # # Button: show log
    end

    def refresh_view
      Wizard.DisableBackButton
      Wizard.SetNextButton(:next, "&Finish")
      Wizard.EnableNextButton
    end

    def can_go_next
      true
    end

    def handle_user_input(input, event)
      case input
      when :save_log
        file_name = UI.AskForSaveFileName("/tmp", "*", "Save as...")
        return unless file_name
        success = SAPHAHelpers.instance.write_file(file_name, @config.zlog)
        if success
          show_dialog_errors(["Written log to #{file_name}"], 'Success')
        else
          show_dialog_errors(["Could not write log file #{file_name}"], 'Error')
        end
      end
    end
  end
end
