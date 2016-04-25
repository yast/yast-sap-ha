require 'yast'

Yast.import "Label"
Yast.import 'UI'
# Yast.import "Wizard"
# Yast.import "Cluster"
# Yast.import "IP"
# Yast.import "Popup"
# Yast.import "Service"
# Yast.import "SystemdSocket"
# Yast.import "Report"
# Yast.import "CWMFirewallInterfaces"
# Yast.import "SuSEFirewall"
# Yast.import "SuSEFirewallServices"

module Yast
  class SAPHADialogsClass
    include Yast::UIShortcuts

    def select_from_list_page(message, options)
      HBox(
        HSpacing(Opt(:hstretch)),
        VBox(
          HSpacing(80),
          VSpacing(Opt(:vstretch)),
          RichText(message),
          VSpacing(3),
          SelectionBox(Id(:selection_box), '', options),
          VSpacing(Opt(:vstretch))
        ),
        HSpacing(Opt(:hstretch))
      )
    end
  end

  def node_definition_page
    base_layout(
      Label('Nodes definition'),
      Label('Hello')
      )
  end

  private

  def base_layout(stuff)
    HBox(
      HSpacing(Opt(:hstretch)),
      VBox(
        stuff
        ),
      HSpacing(Opt(:hstretch))
      )
  end

  SAPHADialogs = SAPHADialogsClass.new

end

