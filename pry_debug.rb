require 'pry'

ENV['Y2DIR'] = File.expand_path('../src', __FILE__)

require_relative 'src/lib/sap_ha/configuration.rb'
require 'sap_ha_system/ssh'
require 'sap_ha/semantic_checks'


# config = Yast::ScenarioConfiguration.new
# config.product_id = "HANA"
# config.scenario_name = "Performance-optimized"

# ssh = Yast::SSH.instance

chk = Yast::SemanticChecks.instance

# puts chk.unique('[1, 2, 3] Should be unique!', false, 1, 2, 3)
# puts chk.unique('[1, 2, 3, 2] Should be unique!', false, 1, 2, 3, 2)
# puts chk.unique('[1, 2, 3, 2] Should be non-unique!', true, 1, 2, 3, 2)
# puts chk.unique('[1, 2, 3] Should be non-unique!', true, 1, 2, 3)

binding.pry



# config.can_install?

puts "haha"
