require 'pry'

ENV['Y2DIR'] = File.expand_path('../src', __FILE__)

require_relative 'src/lib/sap_ha/configuration.rb'
require 'sap_ha_system/ssh'
require 'sap_ha/semantic_checks'

require_relative 'src/clients/sap_ha.rb'

config = Yast::Configuration.new
config.set_product_id "HANA"
config.set_scenario_name "Performance-optimized"

# ssh = Yast::SSH.instance

# chk = Yast::SemanticChecks.instance

# puts chk.unique('[1, 2, 3] Should be unique!', false, 1, 2, 3)
# puts chk.unique('[1, 2, 3, 2] Should be unique!', false, 1, 2, 3, 2)
# puts chk.unique('[1, 2, 3, 2] Should be non-unique!', true, 1, 2, 3, 2)
# puts chk.unique('[1, 2, 3] Should be non-unique!', true, 1, 2, 3)

# errors = Yast::SemanticChecks.instance.verbose_check do |check|
#   check.ipv4('1', 'field 1')
#   check.ipv4('12', 'field 2')
# end

# flags = Yast::SemanticChecks.instance.silent_check do |check|
#   check.ipv4('1', 'field 1')
#   check.ipv4('12', 'field 2')
# end

def sequence
  seq = Yast::SAPHA.sequence
  print 'product_check -> '
  current_key = "scenario_selection"
  while true
    print current_key 
    print ' -> '
    current_key = seq[current_key][:next]
    break if current_key.nil?
  end
  puts "end"
end

def init_config
  config = Yast::Configuration.new
  config.set_product_id "HANA"
  config.set_scenario_name "Performance-optimized"
  config
end

def rpc(node)
  ip = if node == :hana1
    "192.168.103.21"
  elsif node == :hana2
    "192.168.103.22"
  else
    raise 'Wuuuut?'
  end
  require "xmlrpc/client"
  XMLRPC::Client.new(ip, "/RPC2", 8080)
  end


# cc = Hash[c.components.map { |config_name| [config_name, c.instance_variable_get(config_name).screen_name] }]

def process
  Yast::SSH.instance.run_rpc_server("192.168.103.22")
  sleep 3
  c = init_config
  y = c.dump(true)
  s = rpc(:hana2)
  s.call('sapha.import_config', y)
  for component_id in c.components
    puts "--- configuring component #{component_id} ---"
    func = "sapha.config_#{component_id.to_s[1..-1]}.bogus_apply"
    s.call(func)
  end
  s.call('sapha.shutdown')
  # s.call('system.listMethods')
end

binding.pry

flag = Yast::SemanticChecks.instance.check(:silent) do |check|
  check.unique(['100', '100', '100'], true)
end

puts "Checks passed: #{flag}"

# config.can_install?

puts "haha"
