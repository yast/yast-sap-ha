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
# Summary: SUSE High Availability Setup for SAP Products: GUI Installation Page
# Authors: Ilya Manyugin <ilya.manyugin@suse.com>

require 'yast'
require 'sap_ha/helpers'
require 'sap_ha_wizard/base_wizard_page'
require 'sap_ha/sap_ha_installation'
Yast.import 'Progress'

module Yast
  # GUI Installation Page
  class GUIInstallationPage # < BaseWizardPage
    # def initialize(model)
    #   super(model)
    #   @installer = SAPHAInstallation.instance
    # end

    # def set_contents
    #   Progress.New(
    #     'SAP High-Availability Configuration',
    #     '',
    #     4,
    #     [
    #       'SSH Server',
    #       'SUSEFirewall',
    #       'NTP Service',
    #       'Watchdog'
    #       ],
    #       [
    #         _('Starting SSH Server'),
    #         _('Adjusting SUSEFirewall rules'),
    #         _('Checking the Network Time Protocol Service'),
    #         _('Checking the Watchdog configuration')
    #         ],
    #         ""
    #         )
    # end

    # def main_loop
    #   Progress.NextStage
    #   @installer.activate_sshd
    #   # SSH Server
    #   sleep(2)
    #   Progress.NextStage
    #   # Firewall
    #   sleep(2)
    #   Progress.NextStage
    #   show_dialog_errors(["Stuff went wrong here", "And here is something suspicious"])
    #   # NTP
    #   sleep(2)
    #   Progress.NextStage
    #   # Watchdog
    #   sleep(2)
    #   Progress.NextStage
    #   # Finish
    #   sleep(2)
    # end

    def set(nodes, titles, tasks)
      @tasks = tasks
      Progress.New(
        'SAP High-Availability Setup',
        '',
        titles.length,
        nodes,
        titles,
        '')
      Progress.SubprogressType(:progress, @tasks.length)
      Progress.SubprogressTitle("")
    end

    def next_node
      Progress.NextStage
      @task_no = -1
      next_task
    end

    def next_task
      @task_no += 1
      Progress.SubprogressValue(@task_no)
      Progress.SubprogressTitle(@tasks[@task_no])
    end

    def unblock
      Progress.Finish
      # Wizard.SetNextButton(:next, "&Next")
      # Wizard.EnableNextButton
      # Wizard.DisableBackButton
    end
  end
end
