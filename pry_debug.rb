require 'pry'
# require_relative 'src/lib/sap_ha/configuration.rb'
# require_relative 'src/lib/sap_ha_system/cluster.rb'
# require_relative 'src/lib/sap_ha_system/watchdog.rb'
# require_relative 'src/lib/sap_ha_configuration/watchdog.rb'
require_relative 'src/lib/sap_ha_configuration/communication_layer.rb'
require_relative 'src/lib/sap_ha_configuration/cluster_members.rb'

# c = Yast::ScenarioConfiguration.new
# n = Yast::NodesConfiguration.new(2)
# c = Yast::SAPHACluster.instance
# w = Yast::Watchdog.instance
# wc = Yast::WatchdogConfiguration.new
cc = Yast::CommunicationLayerConfiguration.new
cm = Yast::ClusterMembersConfiguration.new(2)
# breakpoint 5
binding.pry

puts "haha"
