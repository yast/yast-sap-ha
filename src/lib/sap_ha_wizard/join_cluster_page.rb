require 'sap_ha_wizard/base_wizard_page'
require 'sap_ha_system/ssh'
require 'sap_ha_system/network'

Yast.import 'Popup'

module Yast
  class JoinClusterPage < BaseWizardPage
    def set_contents
      super
      Wizard.SetContents(
        _('Join an Existing Cluster'),
        base_layout_with_label(
          _("Please provide the IP address of the existing cluster"),
          VBox(
            InputField(Id(:ip_address), 'IP Address', ''),
            ComboBox(Id(:interface), 'Local Network Interface', HANetwork.list_all_interfaces),
            PushButton(Id(:join), 'Join Cluster')
          )
        ),
        '',
        true,
        true
      )
      refresh_view
    end

    def handle_user_input(input)
      case input
      when :join
        node_ip = value(:ip_address)
        interface = value(:interface)
        begin
          SSH.instance.check_ssh(node_ip)
        rescue SSHAuthException
          passwd = password_prompt(node_ip)
          return if passwd.nil?
          begin
            SSH.instance.copy_keys(node_ip, true, passwd)
          rescue SSHException =>e
            log.error e.message
            Popup.Error(e.message)
          end
        rescue SSHException => e
          Popup.Error(e.message)
        end
      else
        super
      end
    end

    def refresh_view
      super
    end

    def can_go_next
      return true if @model.no_validators
      super
    end
  end
end
