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

module Yast
  # Installation Summary page
  # TODO: THIS IS the SUMMARY. The other one is just the configuration overview
  class SetupLogPage < BaseWizardPage
    attr_accessor :model

    def initialize(model)
      @config = model
    end

    def set_contents
      super
      text =  if UI.TextMode
                SAPHAHelpers.instance.render_template('tmpl_config_overview_con.erb', binding)
              else
                SAPHAHelpers.instance.render_template('tmpl_config_overview_gui.erb', binding)
              end        

      base_rich_text(
        "High-Availability Setup Summary",
        text,
        SAPHAHelpers.instance.load_help('help_setup_summary.html'),
        true,
        true
      )
    end

    def refresh_view
      Wizard.DisableBackButton
      log.warn "--- #{self.class}.#{__callee__} : can_install=#{@config.can_install?.inspect} ---"
      if @config.can_install?
        Wizard.EnableNextButton
      else
        Wizard.DisableNextButton
      end
      Wizard.SetNextButton(:install, "&Install")
    end

    def can_go_next
      false
    end

    protected

    def main_loop
      log.debug "--- #{self.class}.#{__callee__} ---"
      input = Wizard.UserInput
      log.debug "--- #{self.class}.#{__callee__}: input is #{input.inspect} ---"
      Wizard.SetNextButton(:summary, "&Summary") unless input == :next
      input.to_sym
    end
  end
end
