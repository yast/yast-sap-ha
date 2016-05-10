require 'yast'
require 'sap_ha/helpers'
require 'sap_ha_wizard/base_wizard_page'
Yast.import 'IP'
Yast.import 'Hostname'
Yast.import 'Report'

module Yast
  # Cluster Nodes Configuration Page
  class NodeConfigurationPage < BaseWizardPage
    def initialize(model)
      super(model)
    end

    def set_contents
      super
      Wizard.SetContents(
        _('Cluster Definition'),
        base_layout_with_label(
          _('Define cluster nodes'),
          VBox(
            Table(
              Id(:node_definition_table),
              Opt(:keepSorting),
              Header(_('Host name'), _('IP Ring 1'), _('IP Ring 2'), _('Node ID')),
              []
            ),
            PushButton(Id(:edit_node), _('Edit selected'))
            )
          ),
        '',
        true,
        true
        )
      refresh_view
    end

    def can_go_next
      flag = @model.conf_nodes.nodes.all? { |_, v| node_configuration_validators(v, false) }
      Report.Error("Configuration is invalid. Please review the parameters.") unless flag
      flag
    end

    def refresh_view
      super
      entries = @model.conf_nodes.table_items.map { |entry| Item(Id(entry[0]), *entry[1..-1]) }
      log.info "Table items: #{entries.inspect}"
      UI.ChangeWidget(Id(:node_definition_table), :Items, entries)
    end

    def handle_user_input(input)
      super
      case input
      when :edit_node
        item_id = UI.QueryWidget(Id(:node_definition_table), :Value)
        values = node_configuration_popup(@model.conf_nodes.node_parameters(item_id))
        Report.ClearErrors
        log.info "Return from ring_configuration_popup: #{values}"
        if !values.nil? && !values.empty?
          @model.conf_nodes.update_values(item_id, values)
          refresh_view
        end
      else
        log.warn "--- #{self.class}.#{__callee__}: Unexpected user input: #{input} ---"
      end
    end

    def node_configuration_popup(values)
      log.debug "--- #{self.class}.#{__callee__} --- "
      base_popup(
        "Configuration for Node #{values[:node_name]}",
        -> (args) { node_configuration_validators(args) },
        InputField(Id(:host_name), 'Host name:', values[:host_name] || ""),
        InputField(Id(:ip_ring1), 'IP Ring 1:', values[:ip_ring1] || ""),
        InputField(Id(:ip_ring2), 'IP Ring 2:', values[:ip_ring2] || ""),
        InputField(Id(:node_id), 'Node ID:', values[:node_id] || "")
      )
    end

    def node_configuration_validators(values, report = true)
      if !IP.Check4(values[:ip_ring1])
        Report.Error("Invalid entry for IP Ring 1: #{IP.Valid4}") if report
        return false
      end
      if !IP.Check4(values[:ip_ring2])
        Report.Error("Invalid entry for IP Ring 2: #{IP.Valid4}") if report
        return false
      end
      if !Hostname.Check(values[:host_name])
        Report.Error("Invalid entry for Hostname: #{Hostname.ValidHost}") if report
        return false
      end
      true
    end
  end
end
