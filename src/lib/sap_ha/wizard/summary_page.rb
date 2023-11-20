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

require "yast"
require "sap_ha/helpers"
require "sap_ha/node_logger"

module SapHA
  module Wizard
    # Setup summary page: display installation log
    class SetupSummaryPage < BaseWizardPage
      attr_accessor :model

      def initialize(model)
        super(model)
        @config = model
      end

      def set_contents
        super
        contents = Yast::UI.TextMode ? SapHA::NodeLogger.text_br : SapHA::NodeLogger.html
        Yast::Wizard.SetContents(
          "High-Availability Setup Summary",
          VBox(
            HBox(
              HSpacing(3),
              RichText(contents),
              HSpacing(3)
            ),
            HBox(
              PushButton(Id(:save_config), "Save configuration"),
              PushButton(Id(:save_log), "Save log"),
              PushButton(Id(:open_hawk), "Open HAWK2")
            )
          ),
          "",
          false,
          true
        )
      end

      def refresh_view
        Yast::Wizard.DisableBackButton
        Yast::Wizard.SetNextButton(:next, "&Finish")
        Yast::Wizard.EnableNextButton
        set_value(:open_hawk, false, :Enabled) if Yast::UI.TextMode
        SapHA::Helpers.write_var_file("installation_log.html", SapHA::NodeLogger.html,
          timestamp: true)
        SapHA::Helpers.write_var_file("installation_log.txt", SapHA::NodeLogger.text,
          timestamp: true)
        SapHA::Helpers.write_var_file("configuration.yml", @config.dump(false),
          timestamp: @config.timestamp)
      end

      def can_go_next?
        true
      end

      def handle_user_input(input, _event)
        case input
        when :save_log
          file_name = Yast::UI.AskForSaveFileName("/tmp", "*.txt *.log *.html",
            "Save log file as...")
          return unless file_name
          log = if file_name.end_with?("html", "htm")
            SapHA::NodeLogger.html
          else
            SapHA::NodeLogger.text
                end
          success = SapHA::Helpers.write_file(file_name, log)
          if success
            show_message("Log was written to <code>#{file_name}</code>", "Success")
          else
            show_message("Could not write log file <code>#{file_name}</code>", "Error")
          end
        when :save_config
          file_name = Yast::UI.AskForSaveFileName("/tmp", "*.yml", "Save configuration file as...")
          return unless file_name
          success = SapHA::Helpers.write_file(file_name, @config.dump)
          if success
            show_message("Configuration was written to <code>#{file_name}</code>", "Success")
          else
            show_message("Could not write configuration file <code>#{file_name}</code>", "Error")
          end
        when :open_hawk
          SapHA::Helpers.open_url("https://localhost:7630/")
        end
      end
    end
  end
end
