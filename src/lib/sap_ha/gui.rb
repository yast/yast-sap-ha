require 'yast'
require 'yaml'
require 'sap_ha/sap_ha_dialogs'
require 'sap_ha/helpers'

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
          SelectionBox(Id(:selection_box), Opt(:vstretch), '', list_contents),
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

    def stub(title, label)
      Wizard.SetContents(
        "#{title} [stub]",
        base_layout(
          Label(label)
        ),
        nil,
        true,
        true
      )
    end

    private

    def base_layout(contents)
      HBox(
        HSpacing(3),
        contents,
        HSpacing(3)
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

    def base_popup(message, *widgets)
      UI.OpenDialog(
        VBox(
          Label(message),
          *widgets,
          Wizard.CancelOKButtonBox
        )
      )
      ui = UI.UserInput
      case ui
      when :ok
        parameters = {}
        widgets.each do |w|
          if [:InputField, :TextEntry].include? w.value
            id = w.params.find do |parameter|
              parameter.respond_to?(:value) and parameter.value == :id
            end.params[0]
            parameters[id] = UI.QueryWidget(Id(id), :Value)
          end
        end
        UI.CloseDialog
        return parameters
      when :cancel
        UI.CloseDialog
        return {}
      end
    end

    # Returns the ring configuration parameters
    def ring_configuration_popup(ring_number=0)
      log.debug "--- #{self.class}.#{__callee__} --- "
      base_popup(
        "Configuration for Ring \##{ring_number}",
        InputField(Id(:address_entry), 'Address:', ''),
        InputField(Id(:port_entry), 'Port:', '')
      )
    end

    def node_configuration_popup(node_name='node')
      log.debug "--- #{self.class}.#{__callee__} --- "
      base_popup(
        "Configuration for Node #{node_name}",
        InputField(Id(:host_name), 'Host name:', ''),
        InputField(Id(:ip_ring1), 'IP Ring 1:', ''),
        InputField(Id(:ip_ring2), 'IP Ring 2:', ''),
        InputField(Id(:node_id), 'Node ID:', ''),
      )
    end

  end

  SAPHAGUI = SAPHAGUIClass.new
end
