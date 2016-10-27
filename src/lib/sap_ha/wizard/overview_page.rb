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
# Summary: SUSE High Availability Setup for SAP Products: Configuration overview page
# Authors: Ilya Manyugin <ilya.manyugin@suse.com>

require 'yast'
require 'sap_ha/helpers'

module SapHA
  module Wizard
    # Configuration Overview page
    class ConfigurationOverviewPage < BaseWizardPage
      attr_accessor :model

      def initialize(model)
        @config = model
      end

      def set_contents
        super
        tmpl = Yast::UI.TextMode ? 'tmpl_config_overview_con.erb' : 'tmpl_config_overview_gui.erb'
        base_rich_text(
          "High-Availability Configuration Overview",
          Helpers.render_template(tmpl, binding),
          Helpers.load_help('setup_summary'),
          true,
          true
        )
      end

      def refresh_view
        Yast::Wizard.DisableBackButton
        log.info "--- #{self.class}.#{__callee__} : can_install=#{@config.can_install?.inspect} ---"
        Yast::Wizard.SetNextButton(:next, "&Install")
        if can_go_next?
          Yast::Wizard.EnableNextButton
        else
          Yast::Wizard.DisableNextButton
          set_value(:next, false, :Enabled)
        end
      end

      def can_go_next?
        @config.can_install?
      end

      protected

      def main_loop
        # TODO: the 'x' button of the window doesn't work here...
        log.debug "--- #{self.class}.#{__callee__} ---"
        input = Yast::Wizard.UserInput
        log.error "--- #{self.class}.#{__callee__}: input is #{input.inspect} ---"
        Yast::Wizard.SetNextButton(:summary, "&Overview") unless input == :next
        input.to_sym
      end

    end
  end
end
