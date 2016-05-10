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

    def network_definition_page
      log.debug "--- called #{self.class}.#{__callee__} ---"
      Wizard.SetContents(
        _('Cluster Definition'),
        base_layout_with_label(
          'Define the communication layer',
          VBox(
            HBox(
              Label('Transport mode:'),
              RadioButtonGroup(
                Id(:transport_mode),
                HBox(
                  RadioButton('Unicast', true),
                  RadioButton('Multicast', false)
                )
              )
            ),
            HBox(
              Label('Number of rings:'),
              ComboBox('',
                ['1', '2']
              )
            ),
            Table(
              Id(:ring_definition_table),
              Opt(:keepSorting, :immediate),
              Header(_('Ring'), _('Address'), _('Port')),
              [Item(Id(:ring1), '1', '192.168.10.0', '5490'),
               Item(Id(:ring2), '2', '192.168.11.0', '5495')]
            ),
            PushButton(Id(:edit_ring), _('Edit selected')),
            InputField(_('Cluster name:'), 'hacluster'),
            InputField(_('Expected votes:'), '2')
          )
        ),
        '',
        true,
        true
      )
      loop do
        ui = Wizard.UserInput()
        log.debug "--- #{self.class}.#{__callee__} : UserInput returned #{ui} ---"
        case ui
        when :edit_ring
          values = ring_configuration_popup
          log.info "Return from ring_configuration_popup: #{values}"
          if not values.empty?
            # TODO: here we change the values
          end
        when :abort, :next, :back
          return ui
        when :ring_definition_table
          vals = UI.QueryWidget(Id(:ring_definition_table), :Value)
          log.info ":ring_definition_table: #{vals}"
        end
      end
    end

    def node_definition_page
      # TODO: we must take the IPs from the previous step, the communication layer definition
      log.debug "--- called #{self.class}.#{__callee__} ---"
      Wizard.SetContents(
        _('Cluster Definition'),
        base_layout_with_label(
          _('Define cluster nodes'),
          VBox(
            Table(
              Id(:node_definition_table),
              Opt(:keepSorting),
              Header(_('Host name'), _('IP Ring 1'), _('IP Ring 2'), _('Node ID')),
              [Item(Id(:item3), 'hana1', '192.168.10.1', '192.168.11.1' '1'),
               Item(Id(:item4), 'hana2', '192.168.10.2', '192.168.11.2' '2')]
            ),
            PushButton(Id(:edit_node), _('Edit selected'))
          )

        ),
        '',
        true,
        true
      )
      loop do
        ui = Wizard.UserInput()
        log.debug "--- #{self.class}.#{__callee__} : UserInput returned #{ui} ---"
        case ui
        when :edit_node
          values = node_configuration_popup
          log.info "Return from ring_configuration_popup: #{values}"
          if not values.empty?
            # TODO: here we change the values
          end
        when :abort, :next, :back
          return ui
        end
      end
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
