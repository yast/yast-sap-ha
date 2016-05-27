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

errors = Yast::SemanticChecks.instance.verbose_check do |check|
  check.ipv4('1', 'field 1')
  check.ipv4('12', 'field 2')
end

flags = Yast::SemanticChecks.instance.silent_check do |check|
  check.ipv4('1', 'field 1')
  check.ipv4('12', 'field 2')
end

binding.pry

# config.can_install?

puts "haha"
