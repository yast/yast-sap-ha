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
# Summary: SUSE High Availability Setup for SAP Products: common GUI routines
# Authors: Ilya Manyugin <ilya.manyugin@suse.com>

require 'yast'
require 'yaml'
require 'sap_ha/helpers'

# TODO: get rid of this
module Yast
  # common GUI routines
  class SAPHAGUIClass
    Yast.import 'UI'
    Yast.import 'Wizard'
    include Yast::UIShortcuts
    include Yast::Logger
    include Yast::I18n

    def list_selection(title, message, list_contents, help, allow_back, allow_next)
      Wizard.SetContents(
        title,
        base_layout_with_label(
          message,
          SelectionBox(Id(:selection_box), Opt(:vstretch), '', list_contents)
        ),
        help,
        allow_back,
        allow_next
      )
    end

    def richt_text(title, contents, help, allow_back, allow_next)
      Wizard.SetContents(
        title,
        base_layout(
          RichText(contents)
        ),
        help,
        allow_back,
        allow_next
      )
    end

    def base_layout_with_label(label_text, contents)
      base_layout(
        VBox(
          HSpacing(80),
          VSpacing(1),
          Left(Label(label_text)),
          VSpacing(1),
          contents,
          VSpacing(Opt(:vstretch))
        )
      )
    end

    def base_layout(contents)
      HBox(
        HSpacing(3),
        contents,
        HSpacing(3)
      )
    end
  end
  SAPHAGUI = SAPHAGUIClass.new
end
