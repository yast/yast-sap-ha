require 'pry'

ENV['Y2DIR'] = File.expand_path('../src', __FILE__)

require_relative 'src/lib/sap_ha/configuration.rb'
require 'sap_ha_system/ssh'
require 'sap_ha/semantic_checks'

require_relative 'src/clients/sap_ha.rb'

config = Yast::ScenarioConfiguration.new
config.product_id = "HANA"
config.scenario_name = "Performance-optimized"

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
    config = Yast::ScenarioConfiguration.new
    config.product_id = "HANA"
    config.scenario_name = "Performance-optimized"
    config
end

def rpc
    require "xmlrpc/client"
    XMLRPC::Client.new("192.168.103.21", "/RPC2", 8080)
end

s = init_config.stonith

binding.pry

# config.can_install?

puts "haha"
