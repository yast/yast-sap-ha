require 'yast'
require 'sap_ha_system/cluster'

module Yast
  class SAPHAClusterClass < Client
    Yast.import 'Wizard'
    Yast.import 'Progress'

    def main
      cluster = SAPHACluster.instance
      Wizard.CreateDialog
      Progress.New(
        'SAP HA Configuration',
        '',
        4,
        [
          'SSH Server',
          'SUSEFirewall',
          'NTP Service',
          'Watchdog'
        ],
        [
          _('Starting SSH Server'),
          _('Adjusting SUSEFirewall rules'),
          _('Checking the Network Time Protocol Service'),
          _('Checking the Watchdog configuration')
        ],
        ""
      )
      sleep(2)
      Progress.NextStage
      # SSH Server
      sleep(2)
      Progress.NextStage if cluster.configure_sshd
      # Firewall
      sleep(2)
      Progress.NextStage if cluster.configure_firewall
      # NTP
      sleep(2)
      Progress.NextStage if cluster.ntp_configured?
      # Watchdog
      sleep(2)
      Progress.NextStage if cluster.watchdog_configured?
      # Finish
      sleep(2)
      Wizard.CloseDialog
    end
  end

  SAPHACluster = SAPHAClusterClass.new.main
end
