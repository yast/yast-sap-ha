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
require 'sap_ha/node_logger'

module SapHA
  module Wizard
    # Setup summary page
    class SetupSummaryPage < BaseWizardPage
      attr_accessor :model

      def initialize(model)
        @config = model
      end

      def set_contents
        super
        Yast::Wizard.SetContents(
          "High-Availability Setup Summary",
          VBox(
            HBox(
              HSpacing(3),
              RichText(SapHA::NodeLogger.to_html(@config.logs)),
              HSpacing(3)
            ),
            HBox(
              PushButton(Id(:save_log), 'Save Log'),
              PushButton(Id(:open_hawk), 'Open Hawk')
            )
          ),
          '',
          false,
          true
        )
      end

      def refresh_view
        Yast::Wizard.DisableBackButton
        Yast::Wizard.SetNextButton(:next, "&Finish")
        Yast::Wizard.EnableNextButton
      end

      def can_go_next
        true
      end

      def handle_user_input(input, event)
        case input
        when :save_log
          log.error "SAVE_LOG: event=#{event}"
          file_name = Yast::UI.AskForSaveFileName("/tmp", "*.txt *.log *.html",
            "Save log file as...")
          return unless file_name
          if file_name.end_with?('html') || file_name.end_with?('htm')
            log = SapHA::NodeLogger.to_html(@config.logs)
          else
            log = @config.logs
          end
          success = SapHA::Helpers.write_file(file_name, log)
          if success
            show_dialog_errors(["Log was written to <code>#{file_name}</code>"], 'Success')
          else
            show_dialog_errors(["Could not write log file <code>#{file_name}</code>"], 'Error')
          end
        when :open_hawk
          SapHA::Helpers.open_url('https://localhost:7630/')
        end
      end
    end
  end
end
