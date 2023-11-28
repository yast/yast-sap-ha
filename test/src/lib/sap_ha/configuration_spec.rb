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

require_relative "../../../test_helper"
require "sap_ha/configuration"
require "sap_ha/exceptions"

describe SapHA::HAConfiguration do
  describe "#new" do
    it "creates a valid instance" do
      result = SapHA::HAConfiguration.new
      expect(result).not_to be_nil
    end
  end

  describe "#set_product_id" do
    it "sets the product ID correctly" do
      ha_configuration = SapHA::HAConfiguration.new
      ha_configuration.set_product_id("HANA")
      # ha_configuration.set_product_id('NW')
      expect { ha_configuration.set_product_id("Hana") }
        .to raise_error SapHA::Exceptions::ProductNotFoundException
    end
  end

  describe "#set_scenario_name" do
    it "sets the scenario name correctly" do
      ha_configuration = SapHA::HAConfiguration.new
      expect { ha_configuration.set_scenario_name("Some scenario") }
        .to raise_error SapHA::Exceptions::ProductNotFoundException
      ha_configuration.set_product_id("HANA")
      ha_configuration.set_scenario_name("Scale Up: Performance-optimized")
      expect { ha_configuration.set_scenario_name("Some scenario") }
        .to raise_error SapHA::Exceptions::ScenarioNotFoundException
    end

    it "applies the configuration sequence" do
      ha_configuration = SapHA::HAConfiguration.new
      ha_configuration.set_product_id("HANA")
      for scenario_name in ha_configuration.all_scenarios
        ha_configuration.set_scenario_name("Scale Up: Performance-optimized")
        # configuration sequence
        cs = ha_configuration.config_sequence
        cluster = cs.find { |e| e[:screen_name] == "Cluster Configuration" }
        expect(cluster).not_to be_nil
        expect(cluster[:object]).to eq ha_configuration.cluster
      end
      # check order
      expect(cs.map { |e| e[:id] }).to match_array %w(ntp watchdog fencing cluster hana)
    end
  end

  describe "#all_scenarios" do
    it "lists all scenarios defined for particular product" do
      ha_configuration = SapHA::HAConfiguration.new
      expect { ha_configuration.all_scenarios }
        .to raise_error SapHA::Exceptions::ProductNotFoundException
      ha_configuration.set_product_id("HANA")
      result = ha_configuration.all_scenarios
      expect(result.empty?).to eq false
    end
  end

  describe "#scenarios_help" do
    it "generates an HTML help for all scenarios defined for the product" do
      ha_configuration = SapHA::HAConfiguration.new
      expect { ha_configuration.scenarios_help }
        .to raise_error SapHA::Exceptions::ProductNotFoundException
      ha_configuration.set_product_id("HANA")
      result = ha_configuration.scenarios_help
      expect(result.empty?).to eq false
    end
  end

  describe "#can_install?" do
    it "works for two-ring cluster config and unicast" do
      ha_configuration = SapHA::HAConfiguration.new
      expect(ha_configuration.can_install?).to eq false
      ha_configuration = prepare_hana_config(ha_configuration)
      expect(ha_configuration.can_install?).to eq(true),
        -> { "Configuration errors:\n#{ha_configuration.verbose_validate.join("\n")}" }
    end

    it "works for two-ring cluster config and multicast" do
      ha_configuration = SapHA::HAConfiguration.new
      expect(ha_configuration.can_install?).to eq false
      ha_configuration = prepare_hana_config(ha_configuration, transport_mode: :multicast)
      expect(ha_configuration.can_install?).to eq(true),
        -> { "Configuration errors:\n#{ha_configuration.verbose_validate.join("\n")}" }
    end

    it "works for single-ring cluster config and unicast" do
      ha_configuration = SapHA::HAConfiguration.new
      expect(ha_configuration.can_install?).to eq false
      ha_configuration = prepare_hana_config(ha_configuration, number_of_rings: 1)
      expect(ha_configuration.can_install?).to eq(true),
        -> { "Configuration errors:\n#{ha_configuration.verbose_validate.join("\n")}" }
    end

    it "works for single-ring cluster config and multicast" do
      ha_configuration = SapHA::HAConfiguration.new
      expect(ha_configuration.can_install?).to eq false
      ha_configuration = prepare_hana_config(ha_configuration, number_of_rings: 1,
        transport_mode: :multicast)
      expect(ha_configuration.can_install?).to eq(true),
        -> { "Configuration errors:\n#{ha_configuration.verbose_validate.join("\n")}" }
    end
  end

  describe "#dump" do
    it "works" do
      ha_configuration = SapHA::HAConfiguration.new
      expect(ha_configuration.dump(true)).to be_nil
      ha_configuration = prepare_hana_config(ha_configuration)
      expect(ha_configuration.dump(true)).not_to be_nil
    end
  end

  describe "#start_setup" do
    it "works" do
      ha_configuration = SapHA::HAConfiguration.new
      ha_configuration.start_setup
    end
  end

  describe "#end_setup" do
    it "works" do
      ha_configuration = SapHA::HAConfiguration.new
      ha_configuration.end_setup
    end
  end

  describe "#collect_log" do
    it "works" do
      ha_configuration = SapHA::HAConfiguration.new
      result = ha_configuration.collect_log
      expect(result).not_to be_nil
    end
  end

end
