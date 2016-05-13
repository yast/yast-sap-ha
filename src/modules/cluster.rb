require 'yast'
require 'open3'

Yast.import 'Service'

module Yast
  
  # Class for cluster configuration
  class SAPHACluster
    include Singleton
    include Yast::Logger

    def initialize
    end

    # join an existing cluster
    def join_cluster(ip_address)
    end

    # private

    def ntp_configured?
      configured = true
      unless Service.enabled?('ntpd')
        log.warn "The NTP service is not enabled"
        # TODO: we should report this to the user
        configured &= false
      end
      unless Service.active?('ntpd')
        log.warn "The NTP service is not active"
        # TODO: ditto
        configured &= false
      end
      configured
    end
  end
end
