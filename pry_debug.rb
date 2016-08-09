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
    ip = node
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

def create_sequence(conf)
  make_entry = lambda do |current, nexti|
    return {
      abort:          :abort,
      cancel:         :abort,
      comm_layer:     "configure_comm_layer",
      config_cluster: "configure_cluster",
      join_cluster:   "join_cluster",
      fencing:        "fencing",
      watchdog:       "watchdog",
      hana:           "hana",
      ntp:            "ntp",
      next:           "installation",
      back:           :back
    } if current == 'config_overview'
    {
      back:    :back,
      abort:   :abort,
      cancel:  :abort,
      next:    nexti || :ws_finish,
      overview: "config_overview"
    }
  end
  seq = {}
  pages_seq = conf.scenario['screen_sequence']
  (0...pages_seq.length).each do |ix|
    seq['ws_start'] = pages_seq[0] if ix == 0
    seq[pages_seq[ix]] = make_entry.call(pages_seq[ix], pages_seq[ix+1])
  end
  seq
end

c = SapHA::HAConfiguration.new
c = prepare_hana_config(c, notest: true, transport_mode: :multicast)
c.cluster.nodes[:node1][:ip_ring1] = '192.168.101.1'
c.cluster.nodes[:node1][:ip_ring2] = '192.168.103.1'
r = rpc :hana1
y = c.dump(true)

require_relative 'src/lib/sap_ha/system/connectivity'
h = SapHA::System::Host.new('hana01', ['192.168.103.21'])


def cccccc
  @config = SapHA::HAConfiguration.new
  @config.set_product_id "HANA"
  @config.set_scenario_name 'Scale Up: Performance-optimized'
  @config.cluster.import(
        number_of_rings: 2,
        transport_mode:  :unicast,
        # transport_mode:  :multicast,
        cluster_name:    'hana_sysrep',
        expected_votes:  2,
        rings:           {
          ring1: {
            address: '192.168.101.0',
            port:    '5405',
            id:      1,
            mcast:   ''
            # mcast:   '239.0.0.1'
          },
          ring2: {
            address: '192.168.103.0',
            port:    '5405',
            id:      2,
            mcast:   ''
            # mcast:   '239.0.0.2'
          }
        }
      )
      @config.cluster.import(
        number_of_rings: 2,
        number_of_nodes: 2,
        nodes:           {
          node1: {
            host_name: "hana01",
            ip_ring1:  "192.168.101.21",
            ip_ring2:  "192.168.103.21",
            node_id:   '1'
          },
          node2: {
            host_name: "hana02",
            ip_ring1:  "192.168.101.22",
            ip_ring2:  "192.168.103.22",
            node_id:   '2'
          }
        }
      )
      @config.fencing.import(devices: [{ name: '/dev/vdb', type: 'disk', uuid: '' }])
      @config.watchdog.import(to_install: ['softdog'])
      @config.hana.import(
        system_id:   'XXX',
        instance:    '00',
        virtual_ip:  '192.168.101.100',
        backup_user: 'xxxadm'
      )
      ntp_cfg = {
        "synchronize_time" => false,
        "sync_interval"    => 5,
        "start_at_boot"    => true,
        "start_in_chroot"  => false,
        "ntp_policy"       => "auto",
        "restricts"        => [],
        "peers"            => [
          { "type"    => "server",
            "address" => "ntp.local",
            "options" => " iburst",
            "comment" => "# key (6) for accessing server variables\n"
          }
        ]
      }
      @config.ntp.read_configuration
      return @config
end

c2 = cccccc

binding.pry

puts nil
