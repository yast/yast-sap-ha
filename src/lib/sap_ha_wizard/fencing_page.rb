require 'yast'
require 'sap_ha/helpers'
require 'sap_ha_wizard/base_wizard_page'
Yast.import 'IP'
Yast.import 'Hostname'
Yast.import 'Report'

module Yast
  # Fencing Mechanism Configuration Page
  class FencingConfigurationPage < BaseWizardPage
    def initialize(model)
      super(model)
    end

    def set_contents
      super
      Wizard.SetContents(
        _('Fencing Mechanism'),
        base_layout_with_label(
          'Choose the STONITH method',
          VBox(
            VBox(
              HBox(
                Label('STONITH Method:'),
                ComboBox(Id(:stonith_method), '', ['SBD', 'IPMI'])
                )
              ),
            HBox(
              HSpacing(20),
              Table(
                Id(:sbd_dev_list_table),
                Opt(:keepSorting, :immediate),
                Header(_('#'), _('Mount Point'), _('Type'), _('UUID')),
                @model.stonith.table_items
              ),
              HSpacing(20)
            ),
            HBox(
              PushButton(Id(:add_sbd_device), _('Add')),
              PushButton(Id(:remove_sbd_device), _('Remove')),
            ),
            VSpacing(3),
            Label(_("Note that all the data on the selected devices WILL BE DESTROYED."))
          )
        ),
        '',
        true,
        true
      )
      UI.ChangeWidget(Id(:stonith_method), :Enabled, false)
    end

    def can_go_next
      return true if @model.debug
      true
    end

    def refresh_view
      super
      UI.ChangeWidget(Id(:sbd_dev_list_table), :Items, @model.stonith.table_items)
      # entries = @model.conf_nodes.table_items.map { |entry| Item(Id(entry[0]), *entry[1..-1]) }
      # log.info "Table items: #{entries.inspect}"
      # UI.ChangeWidget(Id(:ring_definition_table), :Items, entries)
    end

    def handle_user_input(input)
      case input
      when :add_sbd_device
        sbd_dev_configuration
      when :remove_sbd_device
        item_id = UI.QueryWidget(Id(:sbd_dev_list_table), :Value)
        log.debug "--- removing item #{item_id} from the table of SBD devices"
      else
        super
      end
      # case input
      # when :sbd_dev_list_table
      #   item_id = UI.QueryWidget(Id(:ring_definition_table), :Value)
      #   values = ring_configuration_popup(@model.conf_nodes.node_parameters(item_id))
      #   Report.ClearErrors
      #   log.info "Return from ring_configuration_popup: #{values}"
      #   if !values.nil? && !values.empty?
      #     @model.conf_nodes.update_values(item_id, values)
      #     refresh_view
      #   end
      # else
      #   log.warn "--- #{self.class}.#{__callee__}: Unexpected user input: #{input} ---"
      # end
    end

    def sbd_dev_configuration
      def handle_combo
        v = UI.QueryWidget(Id(:sbd_combo), :Value)
        log.info "--- combo event: value #{v} ---"
        log.info "--- values: #{@model.stonith.proposals} ---"
        item = @model.stonith.proposals.find { |e| e[:name] == v }
        UI.ChangeWidget(Id(:sbd_name), :Value, item[:name])
        UI.ChangeWidget(Id(:sbd_type), :Value, item[:type])
        UI.ChangeWidget(Id(:sbd_uuid), :Value, item[:uuid] || "")
        UI.RecalcLayout
      end

      log.debug "--- #{self.class}.#{__callee__} --- "
      items = @model.stonith.combo_items
      UI.OpenDialog(
        VBox(
          Left(Label(Opt(:boldFont), 'SBD Device Configuration')),
          Left(
            HBox(
              Label('Device:'),
              ComboBox(Id(:sbd_combo), Opt(:notify), '', items))),
          VBox(
            Left(HBox(Label('Name:'), Label(Id(:sbd_name), ''))),
            Left(HBox(Label('Type:'), Label(Id(:sbd_type), ''))),
            Left(HBox(Label('UUID:'), MinWidth(44, Label(Id(:sbd_uuid), ''))))
          ),
          Wizard.CancelOKButtonBox
        )
      )
      handle_combo
      loop do
        ui = UI.UserInput
        case ui
        when :ok
          v = UI.QueryWidget(Id(:sbd_combo), :Value)
          @model.stonith.add_to_config(v)
          UI.CloseDialog
          refresh_view
          break
        when :cancel
          UI.CloseDialog
          break
        when :sbd_combo
          handle_combo
        end
      end
    end
    # # Returns the ring configuration parameters
    # def ring_configuration_popup(ring_number=0)
    #   log.debug "--- #{self.class}.#{__callee__} --- "
    #   base_popup(
    #     "Configuration for Ring \##{ring_number}",
    #     nil,
    #     InputField(Id(:address), 'Address:', ''),
    #     InputField(Id(:port), 'Port:', '')
    #   )
    # end

    # def node_configuration_validators(values, report = true)
    #   if !IP.Check4(values[:ip_ring1])
    #     Report.Error("Invalid entry for IP Ring 1: #{IP.Valid4}") if report
    #     return false
    #   end
    #   if !IP.Check4(values[:ip_ring2])
    #     Report.Error("Invalid entry for IP Ring 2: #{IP.Valid4}") if report
    #     return false
    #   end
    #   if !Hostname.Check(values[:host_name])
    #     Report.Error("Invalid entry for Hostname: #{Hostname.ValidHost}") if report
    #     return false
    #   end
    #   true
    # end
  end
end
