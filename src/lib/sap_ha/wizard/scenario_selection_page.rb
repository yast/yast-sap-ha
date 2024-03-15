# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2017 SUSE Linux GmbH, Nuernberg, Germany.
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
# Summary: SUSE High Availability Setup for SAP Products: Scenario Selection page
# Authors: Ilya Manyugin <ilya.manyugin@suse.com>

require "yast"
require "sap_ha/helpers"

module SapHA
  module Wizard
    # Scenario Selection page
    class ScenarioSelectionPage < BaseWizardPage
      def initialize(model)
        super(model)
        @to_load = nil
      end

      def set_contents
        super
        choices = @model.all_scenarios
        help = @model.scenarios_help
        base_list_selection("Scenario selection for #{@model.product_name}",
          "An #{@model.product_name} installation was detected. "\
          "Please select an High Availability scenario:",
          choices, help, false, true)
      end

      def refresh_view
        begin
          previous_configs = SapHA::Helpers.get_configuration_files(@model.product_id)
          previous_configs_popup(previous_configs) if !previous_configs.empty?
	rescue StandardError => e
          log.info "Could not parse previous config files: #{e.message}"
	end
      end

      def can_go_next?
        true
      end

      def update_model
        super
        begin
          @model.set_scenario_name(value(:selection_box))
        rescue ScenarioNotFoundException
          return :unknown
        rescue GUIFatal => e
          Popup.Error(e.message)
          return :abort
        end
        :next
      end

    protected

      def previous_configs_popup(previous_configs)
        log.debug "--- #{self.class}.#{__callee__} ---"
        list_contents = previous_configs.map { |e| e[0] }
        ret = base_popup(
          "Would you like to load a previous configuration?",
          nil,
          MinSize(55, 11,
            SelectionBox(Id(:config_name), Opt(:vstretch, :notify), "", list_contents))
        )
        log.debug "--- #{self.class}.#{__callee__}: ret from base_popup: #{ret.inspect} ---"
        @to_load = previous_configs.find { |e| e[0] == ret[:config_name] }[1] unless ret.nil?
      end

      def main_loop
        log.debug "--- #{self.class}.#{__callee__} ---"
        # return the config to load
        return @to_load if !@to_load.nil?
        loop do
          event = Yast::UI.WaitForEvent
          log.debug "--- #{self.class}.#{__callee__}: event=#{event} ---"
          return :next unless event # allow for debugging
          # Allow for double-clicking the item in the list
          input = event["ID"]
          case input
          when :selection_box
            if event["EventReason"] == "Activated"
              return update_model
            end
          when :next
            return update_model
          when :abort, :cancel
            return input
          else
            log.error "--- #{self.class}.#{__callee__}: Strange input event #{event} ---"
          end
        end
      end
    end
  end
end
