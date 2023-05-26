# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2016 SUSE Linux GmbH, Nuernberg, Germany.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact SUSE Linux GmbH.
#
# ------------------------------------------------------------------------------
#
# Summary: SUSE High Availability Setup for SAP Products
# Authors: Ilya Manyugin <ilya.manyugin@suse.com>

require "etc"

# Set the paths
ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

RSpec.configure do |config|
  config.mock_with :rspec do |mocks|
    # If you misremember a method name both in code and in tests,
    # will save you.
    # https://relishapp.com/rspec/rspec-mocks/v/3-0/docs/verifying-doubles/partial-doubles
    #
    # With graceful degradation for RSpec 2
    mocks.verify_partial_doubles = true if mocks.respond_to?(:verify_partial_doubles=)
  end
end

if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start do
    add_filter "/test/"
  end

  src_location = File.expand_path("../src", __dir__)
  # track all ruby files under src
  SimpleCov.track_files("#{src_location}/**/*.rb")

  # additionally use the LCOV format for on-line code coverage reporting at CI
  if ENV["CI"] || ENV["COVERAGE_LCOV"]
    require "simplecov-lcov"

    SimpleCov::Formatter::LcovFormatter.config do |c|
      c.report_with_single_file = true
      # this is the default Coveralls GitHub Action location
      # https://github.com/marketplace/actions/coveralls-github-action
      c.single_report_path = "coverage/lcov.info"
    end

    SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
      SimpleCov::Formatter::HTMLFormatter,
      SimpleCov::Formatter::LcovFormatter
    ]
  end
end

require "yast"

def build_service?
  Etc.getlogin == "abuild"
end

def user_root?
  Process.uid == 0
end

# Prepare a valid HANA configuration
# If no options are passed, then it creates a two node cluster with two rings
# and unicast communication
def prepare_hana_config(instance = nil, options = {})
  instance = SapHA::HAConfiguration.new if instance.nil?
  _make_basic_ha_config(instance, "HANA",
    options.fetch(:scenario_name, "Scale Up: Performance-optimized"),
    options)
end

def _make_basic_ha_config(config, product_id, scenario_name, options = {})
  # stub the IP checks so the tests don't fail
  unless options[:notest]
    allow(SapHA::SemanticChecks.instance).to receive(:intersection_not_empty).with(
      anything, anything, anything, "IP addresses for ring 1"
    ).and_return(true)
    allow(SapHA::SemanticChecks.instance).to receive(:intersection_not_empty).with(
      anything, anything, anything, "IP addresses for ring 2"
    ).and_return(true)
  end
  config.set_product_id product_id
  config.set_scenario_name scenario_name
  config.cluster.import(
    fixed_number_of_nodes: options.fetch(:fixed_number_of_nodes, true),
    transport_mode:        options.fetch(:transport_mode, :unicast),
    cluster_name:          options.fetch(:cluster_name, "hana_sysrep"),
    number_of_rings:       options.fetch(:number_of_rings, 2),
    number_of_nodes:       options.fetch(:number_of_nodes, 2),
    expected_votes:        options.fetch(:expected_votes, 2),
    rings:                 { ring1: { address: "192.168.101.0/24", port: "5405",
                                      id: 1, mcast: "239.255.255.255",
                                      address_no_mask: "192.168.101.0/24" },
                             ring2: { address: "192.168.103.0/24", port: "5405",
                                      id: 2, mcast: "239.255.255.255",
                                      address_no_mask: "192.168.103.0" } },
    nodes:                 { node1: { host_name: "hana01", ip_ring1: "192.168.101.21",
                                     ip_ring2: "192.168.103.21", node_id: "1" },
                             node2: { host_name: "hana02", ip_ring1: "192.168.101.22",
                                     ip_ring2: "192.168.103.22", node_id: "2" } }
  )
  # let the model reduce the number of rings, if necessary
  config.cluster.number_of_rings = options.fetch(:number_of_rings, 2)
  config.fencing.import(
    devices: ["/dev/vdb"]
  )
  config.watchdog.import(to_install: ["softdog"])
  config.hana.import(
    system_id:       options.fetch(:system_id, "XXX"),
    instance:        options.fetch(:instance, "05"),
    virtual_ip:      options.fetch(:virtual_ip, "192.168.101.100"),
    prefer_takeover: options.fetch(:prefer_takeover, true),
    auto_register:   options.fetch(:auto_register, false),
    site_name_1:     options.fetch(:site_name_1, "WALLDORF1"),
    site_name_2:     options.fetch(:site_name_2, "ROT1"),
    backup_user:     options.fetch(:backup_user, "mybackupuser"),
    backup_file:     options.fetch(:backup_file, "mybackupfile2"),
    perform_backup:  options.fetch(:perform_backup, false)
  )
  ntp_cfg = {
    "ntp_sync"=>"systemd",
    "ntp_policy"=>"auto",
    "ntp_servers"=>[
      { "address" => "0.suse.pool.ntp.org", "iburst" => true, "offline" => false },
      { "address" => "1.suse.pool.ntp.org", "iburst" => true, "offline" => false },
      { "address" => "2.suse.pool.ntp.org", "iburst" => true, "offline" => false },
      { "address" => "3.suse.pool.ntp.org", "iburst" => true, "offline" => false }
    ]
  }
  config.ntp.import(
    config:       ntp_cfg,
    used_servers: ["2.suse.pool.ntp.org"]
  )
  config
end
