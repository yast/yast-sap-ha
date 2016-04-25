require 'yast'

Yast.import 'WFM'


module Yast
    class ClusterPropClass < Client
        include Yast::Logger
        def main
            # WFM.CallFunction('cluster', [Yast::Path.new('.propose')])
            # prop = WFM.CallFunction('cluster_proposal', ['MakeProposal'])
            prop = WFM.CallFunction('cluster_proposal', ['AskUser'])
            log.info "PROPOSAL: #{prop}"
        end
    end

    ClusterProp = ClusterPropClass.new()
    ClusterProp.main
end