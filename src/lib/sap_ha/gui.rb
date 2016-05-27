require 'yast'
require 'yaml'
require 'sap_ha/sap_ha_dialogs'
require 'sap_ha/helpers'


# TODO: get rid of this
module Yast
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
