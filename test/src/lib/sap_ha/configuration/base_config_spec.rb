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

require_relative '../../../../test_helper'
require 'sap_ha/configuration/base_config'
require 'sap_ha/exceptions'

class TestConfig < SapHA::Configuration::BaseConfig
  def initialize
    super(nil)
  end
end

describe SapHA::Configuration::BaseConfig do
  describe '#new' do
    it 'raises an exception, preventing instantiation' do
      expect { SapHA::Configuration::BaseConfig.new(nil) }
        .to raise_error SapHA::Exceptions::BaseConfigException
      expect(TestConfig.new).not_to be_nil
    end
  end

  # TODO: test actual YAML coding
  describe '#encode_with' do
    it 'omits the specified attributesS' do
      base_config = TestConfig.new
      coder = double('coder')
      allow(coder).to receive(:[]=)
      base_config.encode_with(coder)
    end
  end

  # TODO: test actual YAML restoration
  describe '#init_with' do
    it 'recreates the object' do
      base_config = TestConfig.new
      coder = double('coder')
      expect(coder).to receive(:[]).with('instance_variables') { [] }.at_most(2).times
      result = base_config.init_with(coder)
      expect(result).not_to be_nil
    end
  end

  describe '#read_system' do
    it 'reads local system configuration' do
      base_config = TestConfig.new
      expect { base_config.read_system }.to raise_error SapHA::Exceptions::BaseConfigException
    end
  end

  describe '#configured?' do
    it 'reports if the configuration is complete' do
      base_config = TestConfig.new
      result = base_config.configured?
      expect(result).to eq false
    end
  end

  describe '#description' do
    it 'provides a description' do
      base_config = TestConfig.new
      expect { base_config.description }.to raise_error SapHA::Exceptions::BaseConfigException
    end
  end

  describe '#import' do
    it 'imports the parameters from a hash to the instance' do
      base_config = TestConfig.new
      hash = { something: 22 }
      base_config.import(hash)
      expect(base_config.instance_variable_get(:@something)).to eq 22
    end
  end

  # TODO: auto-generated
  describe '#export' do
    it 'exports instance variables to a hash' do
      base_config = TestConfig.new
      hash = { something: 22 }
      base_config.import(hash)
      hash = base_config.export
      expect(hash).to include(:@something => 22)
    end
  end

  describe '#apply' do
    it 'raises an exception' do
      base_config = TestConfig.new
      expect { base_config.apply(:master) }.to raise_error SapHA::Exceptions::BaseConfigException
    end
  end

  describe '#validate' do
    it 'raises an exception' do
      base_config = TestConfig.new
      expect { base_config.validate }.to raise_error SapHA::Exceptions::BaseConfigException
    end
  end

end
