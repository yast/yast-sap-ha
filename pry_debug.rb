require 'pry'
require_relative 'src/lib/sap_ha/scenario_configuration.rb'

c = Yast::ScenarioConfiguration.new
n = Yast::NodesConfiguration.new(2)

breakpoint 5
binding.pry
