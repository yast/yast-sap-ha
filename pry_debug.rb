require 'pry'
# require_relative 'src/lib/sap_ha/scenario_configuration.rb'
require_relative 'src/lib/sap_ha_system/cluster.rb'
require_relative 'src/lib/sap_ha_system/watchdog.rb'
require_relative 'src/lib/sap_ha_configuration/watchdog_configuration.rb'

# c = Yast::ScenarioConfiguration.new
# n = Yast::NodesConfiguration.new(2)
c = Yast::SAPHACluster.instance
w = Yast::Watchdog.instance
wc = Yast::WatchdogConfiguration.new
# breakpoint 5
binding.pry

puts "haha"
