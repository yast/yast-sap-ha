require 'pry'
require 'yaml'

ENV['Y2DIR'] = File.expand_path('../src', __FILE__)

require_relative 'src/lib/sap_ha/configuration.rb'
require 'sap_ha/system/ssh'
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

c = init_config

c.cluster.import(
  number_of_rings: 2,
  transport_mode: :unicast,
  number_of_nodes: 2,
  cluster_name: 'hana_sysrep',
  expected_votes: 2,
  rings: {
    ring1: {
      address:  '192.168.103.0',
      port:     '5999',
      id:       1,
      mcast:    ''
    },
    ring2: {
      address:  '192.168.101.0',
      port:     '5999',
      id:       2,
      mcast:    ''
    }
  },
  nodes: {
    node1: {
      host_name:  "hana01",
      ip_ring1:   "192.168.101.21",
      ip_ring2:   "192.168.103.21",
      ip_ring3:   "",
      node_id:    '1'
    },
    node2: {
      host_name:  "hana02",
      ip_ring1:   "192.168.101.22",
      ip_ring2:   "192.168.103.23",
      ip_ring3:   "",
      node_id:    '2'
    }
  }
)
c.fencing.import(devices: [{name: '/dev/vdb', type: 'disk', uuid: ''}])
c.watchdog.import(to_install: ['softdog'])
c.hana.import(
      system_id: 'XXX',
      instance:  '05',
      virtual_ip: '192.168.101.100'
    )



class FooBar
  def initialize
    @a = 1
    @b = 2
    @c = 3
  end
end

class FooBaz < FooBar
  def encode_with(coder)
    super
  end

  def init_with(coder)
    super
  end
end

class FooBax < FooBar
  def initialize
    super
    @log = 'FooBaxLog'
    @yaml_exclude = [:@c, :@yaml_exclude, :@log]
  end

  def encode_with(coder)
    puts "FooBax:encode_with"
    instance_variables.each do |variable_name|
      next if @yaml_exclude.include? variable_name
      key = variable_name.to_s[1..-1]
      coder[key] = instance_variable_get(variable_name)
    end
    coder['instance_variables'] = instance_variables - @yaml_exclude
  end

  def init_with(coder)
    puts "FooBax:init_with"
    coder['instance_variables'].each do |variable_name|
      key = variable_name.to_s[1..-1]
      instance_variable_set(variable_name, coder[key])
    end
    @coder = 'FooBaxLog_init'
  end
end


class Meow < FooBax
  def initialize
    super
    @d = 5
    @f = 'hide me'
    @yaml_exclude << :@f
  end

  def init_with(coder)
    puts "Meow:init_with"
    super
    @f = 'hidden!'
  end
end

binding.pry



puts nil

# flag = Yast::SemanticChecks.instance.check(:silent) do |check|
#   check.unique(['100', '100', '100'], true)
# end

# puts "Checks passed: #{flag}"

# config.can_install?

# puts "haha"
