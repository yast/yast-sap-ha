require 'pry'

ENV['Y2DIR'] = File.expand_path('../src', __FILE__)

require_relative 'src/lib/sap_ha/configuration.rb'
require 'sap_ha_system/ssh'

config = Yast::ScenarioConfiguration.new
config.product_id = "HANA"
config.scenario_name = "Performance-optimized"

ssh = Yast::SSH.instance

binding.pry

config.can_install?

puts "haha"
