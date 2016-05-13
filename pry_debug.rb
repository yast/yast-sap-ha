require 'pry'
# require_relative 'src/lib/sap_ha/scenario_configuration.rb'
require_relative 'src/modules/cluster.rb'
require_relative 'src/modules/watchdog.rb'

# c = Yast::ScenarioConfiguration.new
# n = Yast::NodesConfiguration.new(2)
c = Yast::SAPHACluster.instance
w = Yast::Watchdog.instance
# breakpoint 5
binding.pry

puts "haha"
