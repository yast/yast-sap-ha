require 'yast'
require 'sap_ha/helpers'
require 'sap_ha_wizard/base_wizard_page'
Yast.import 'IP'
Yast.import 'Hostname'
Yast.import 'Report'

module Yast
  # Cluster Nodes Configuration Page
  class ClusterMembersConfigurationPage < BaseWizardPage
    def initialize(model)
      super(model)
      @my_model = @model.cluster_members
      log.info "--- #{self.class}.#{__callee__}: number_of_rings == #{@my_model.number_of_rings} ---"
    end

    def set_contents
      # TODO: allow adding nodes if !@my_model.fixed_number_of_nodes?
      super
      Wizard.SetContents(
        _('Cluster Members'),
        base_layout_with_label(
          _('Define cluster member nodes'),
          VBox(
            HBox(
              HSpacing(20),
              table_widget,
              HSpacing(20)
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
      flag = @my_model.nodes.all? { |_, v| node_configuration_validators(v, false) }
      Report.Error("Configuration is invalid. Please review the parameters.") unless flag
      flag
    end

    def refresh_view
      super
      UI.ChangeWidget(Id(:node_definition_table), :Items, @my_model.table_items)
    end

    def table_widget
      Table(
          Id(:node_definition_table),
          Opt(:keepSorting),
          header,
          []
        )
    end

    def header
      case @my_model.number_of_rings
      when 1
        Header(_('Host name'), _('IP Ring 1'), _('Node ID'))
      when 2
        Header(_('Host name'), _('IP Ring 1'), _('IP Ring 2'), _('Node ID'))
      when 3
        Header(_('Host name'), _('IP Ring 1'), _('IP Ring 3'), _('IP Ring 3'), _('Node ID'))
      end
    end

    def handle_user_input(input)
      super
      case input
      when :edit_node
        item_id = UI.QueryWidget(Id(:node_definition_table), :Value)
        values = node_configuration_popup(@my_model.node_parameters(item_id))
        Report.ClearErrors
        log.info "Return from ring_configuration_popup: #{values}"
        if !values.nil? && !values.empty?
          @my_model.update_values(item_id, values)
          refresh_view
        end
      else
        log.warn "--- #{self.class}.#{__callee__}: Unexpected user input: #{input} ---"
      end
    end

    def node_configuration_popup(values)
      log.debug "--- #{self.class}.#{__callee__} --- "
      base_popup(
        "Configuration for Node #{values[:node_id]}",
        -> (args) { node_configuration_validators(args) },
        InputField(Id(:host_name), 'Host name:', values[:host_name] || ""),
        InputField(Id(:ip_ring1), 'IP Ring 1:', values[:ip_ring1] || ""),
        @my_model.number_of_rings > 1 ? InputField(Id(:ip_ring2), 'IP Ring 2:', values[:ip_ring2] || "") : Empty(),
        @my_model.number_of_rings > 2 ? InputField(Id(:ip_ring3), 'IP Ring 3:', values[:ip_ring3] || "") : Empty(),
        InputField(Id(:node_id), 'Node ID:', values[:node_id] || "")
      )
    end

    def node_configuration_validators(values, report = true)
      if !IP.Check4(values[:ip_ring1])
        Report.Error("Invalid entry for IP Ring 1: #{IP.Valid4}") if report
        return false
      end
      if @my_model.number_of_rings > 1 && !IP.Check4(values[:ip_ring2])
        Report.Error("Invalid entry for IP Ring 2: #{IP.Valid4}") if report
        return false
      end
      if @my_model.number_of_rings > 2 && !IP.Check4(values[:ip_ring3])
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
