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
require 'sap_ha/wizard/base_wizard_page'
require 'sap_ha/sap_ha_installation'

Yast.import 'UI'
Yast.import 'Progress'

module SapHA
  module Wizard
    # GUI Installation Page
    class GUIInstallationPage
      include Yast::Logger
      include Yast::UIShortcuts

      def set(nodes, titles, tasks)
        @tasks = tasks
        log.error "--- #{self.class}.#{__callee__}: Progress running? #{Yast::Progress.IsRunning} ---"
        log.error "--- #{self.class}.#{__callee__}: Stack size? #{Yast::Progress.StackSize} ---"
        log.error "--- #{self.class}.#{__callee__}: calling Yast::Progress.New ---"
        # Yast::Wizard.SetContents('Installation Progress', Empty(), '', false, false)
        # unless Yast::Progress.status
        #   Yast::Progress.set(true)
        # end
        Yast::Progress.New(
          'SAP High-Availability Setup',
          '',
          titles.length,
          nodes,
          titles,
          '')
        log.error "--- #{self.class}.#{__callee__}: returned, setting SubprogressType ---"
        Yast::Progress.SubprogressType(:progress, @tasks.length)
        Yast::Progress.SubprogressTitle("")
        log.error "--- #{self.class}.#{__callee__}: finished ---"
      end

      def next_node
        @task_no = 0
        Yast::Progress.NextStageStep(0)
        # next_task
      end

      def next_task
        @task_no += 1
        Yast::Progress.SubprogressValue(@task_no)
        Yast::Progress.SubprogressTitle(@tasks[@task_no])
      end

      def unblock
        Yast::Progress.Finish
      end
    end
  end
end
