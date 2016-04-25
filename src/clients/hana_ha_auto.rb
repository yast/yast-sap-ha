# @param function to execute
# @param map/list of cluster settings
# @return [Hash] edited settings, Summary or boolean on success depending on called function
# @example map mm = $[ "FAIL_DELAY" : "77" ];
# @example map ret = WFM::CallFunction ("cluster_auto", [ "Summary", mm ]);
module Yast
  class ClusterAutoClient < Client
    Yast.import "HanaHAConfig"
    Yast.import "UI"
    include Yast::Logger

    def main
      textdomain "sap-ha"
      yast_module = HanaHAConfig
      log.info("----------------------------------------")
      log.info("hana-ha-auto started")
      # TODO: WUT?
      # Yast.include self, "cluster/wizards.rb"

      @ret = nil
      @func = ""
      @param = {}

      # Check arguments
      if WFM.Args.size > 0 && Ops.is_string?(WFM.Args(0))
        @func = WFM.Args(0)
        if WFM.Args.size > 1 && Ops.is_map?(WFM.Args(1))
          @params = WFM.Args(1)
        end
      end
      log.debug("Function = #{@func}")
      log.debug("Parameters = #{@params}")


      case @func
      when "Summary"
        @ret = yast_module.get_summary || ""
      when "Reset"
        yast_module.import_settings({})
        @ret = {}
      when "Change"
        # Change configuration (run AutoSequence)
      when "Import"  
        @ret = yast_module.import_settings(@params)
      when "Export"
        @ret = yast_module.export_settings
      when "Packages"
        @ret = yast_module.get_packages
      when "Read"
        Yast.import "Progress"
        @progress_orig = Progress.set(false)
        @ret = yast_module.Read
        Progress.set(@progress_orig)
      when "Write"
        Yast.import "Progress"
        @progress_orig = yast_module.set(false)
        yast_module.SetWriteOnly(true)
        @ret = Cluster.Write
        Progress.set(@progress_orig)
      when "GetModified"
        yast_module.get_modified
      when "SetModified"
        @ret = yast_module.set_modified(true)
      else
        log.error("Unknown function '#{@func}'")
        @ret = false
      end

      log.debug("Return = #{@ret}")
      log.info("hana-ha-auto finished")
      log.info("----------------------------------------")

      deep_copy(@ret) 

    end
  end
end

Yast::ClusterAutoClient.new.main
