require "yast"

module Yast
  class HanaHAConfigClass < Module
    Yast.import 'WFM'
    include Yast::Logger
    
    def initialize
      textdomain "sap-ha"
      # Yast.import "Progress"
      # Yast.import "Report"
      # Yast.import "Summary"
      # Yast.import "Message"
      # Yast.import "PackageSystem"
      # Yast.import "SuSEFirewall"
      # Yast.import "SuSEFirewallServices"


      @modified = false
      @proposal_valid = false
      @firstrun = false
      @write_only = false

      # Settings: Define all variables needed for configuration of cluster
      @hana_site_name_primary = ""
      @hana_site_name_secondary = ""
      @hana_host_name_primary = ""
      @hana_host_name_secondary = ""
      @hana_instance_number = ""
      @hana_sid = ""
      @hana_prefer_site_takeover = true
      @hana_automated_register = false
      @hana_current_primary = true
      # username to make backup with
      @hana_backup_user = 'system'
    end

    def modified?
      log.debug("modified = #{@modified}")
      @modified
    end

    def modified(value)
      @modified = true
    end

    def proposal_valid?
      @proposal_valid
    end

    def proposal_valid(value)
      @proposal_valid = value
    end

    # @return true if module is marked as "write only" (don't start services etc...)
    def write_only?
      @write_only
    end

    # Set write_only flag (for autoinstalation).
    def write_only(value)
      @write_only = value
    end


    def load_configuration
      if WFM.ClientExists('cluster_auto')
        Report.ClearAll
        @cluster_config = WFM.CallFunction('cluster_auto', ['Export'])
        if Report.NumErrors != 0
          errors = Report.GetMessages(false, true, false, false)
          log.error("The cluster_auto client returned the following errors: #{errors}")
      else
        log.error('The cluster_auto Yast client is not installed in the system.')
      end
      nil
    end

    private

    def prepare_hana
      if @hana_current_primary
        bash_execute "hdbsql -u #{@hana_backup_user} -i #{@hana_instance_number} \"BACKUP DATA USING FILE ('backup')\""
        bash_execute "hdbnsutil -sr_enable --name=#{@hana_site_name_primary}"
      else
      end
    end

    def bash_execute(cmd)
      SCR.Execute(path('.target.bash_output'), cmd)
    end

  HanaHAConfig = HanaHAConfigClass.new
  HanaHAConfig.main
end
