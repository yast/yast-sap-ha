require 'pry'
require 'yaml'

ENV['Y2DIR'] = File.expand_path('../src', __FILE__)

require_relative 'test/test_helper'

require_relative 'src/lib/sap_ha/configuration.rb'
require 'sap_ha/system/ssh'
require 'sap_ha/system/local'
require 'sap_ha/semantic_checks'
require 'sap_ha/helpers'

require_relative 'src/clients/sap_ha.rb'

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

def process
  Yast::SSH.instance.run_rpc_server("192.168.103.22")
  sleep 3
  c = prepare_hana_config
  y = c.dump(true)
  s = rpc(:hana2)
  s.call('sapha.import_config', y)
  s.call('sapha.config.start_setup')
  for component_id in c.components
    puts "--- configuring component #{component_id} ---"
    func = "sapha.config_#{component_id.to_s[1..-1]}.bogus_apply"
    s.call(func)
  end
  s.call('sapha.config.end_setup')
  puts s.call('sapha.config.collect_log')
  s.call('sapha.shutdown')
  # s.call('system.listMethods')
end

def read_config
  YAML.load(File.read('config.yml'))
end

c = prepare_hana_config(nil, notest: true)

binding.pry

puts nil
