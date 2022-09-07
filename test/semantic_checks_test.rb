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

require_relative 'test_helper'
require 'sap_ha/semantic_checks'

describe SapHA::SemanticChecks do
  subject { SapHA::SemanticChecks.instance }

  describe '#ipv4' do
    it "reports validness of an IP address in silent mode" do
      subject.silent = true
      expect(subject.ipv4('100')).to eq false
      expect(subject.ipv4('')).to eq false
      expect(subject.ipv4(1000)).to eq false
      expect(subject.ipv4(nil)).to eq false
      expect(subject.ipv4('192.168.100.100')).to eq true
    end

    it "reports validness of an IP address in verbose mode" do
      subject.silent = false
      expect(subject.ipv4('100')).to be_kind_of ::String
      expect(subject.ipv4('')).to be_kind_of ::String
      expect(subject.ipv4(1000)).to be_kind_of ::String
      expect(subject.ipv4(nil)).to be_kind_of ::String
      expect(subject.ipv4('192.168.100.100')).to eq nil
    end

    it "works in a transaction" do
      flag = subject.silent_check do |check|
        check.ipv4('100')
        check.ipv4('192.168.100.100')
      end

      expect(flag).to eq false

      flag = subject.silent_check do |check|
        check.ipv4('192.168.100.100')
        check.ipv4('192.168.100.1')
      end

      expect(flag).to eq true
      errs = subject.verbose_check do |check|
        check.ipv4('192.168.100.100')
        check.ipv4('192.168.100.1')
      end

      expect(errs).to be_empty
      errs = subject.verbose_check do |check|
        check.ipv4('10')
        check.ipv4('102.100.100.100')
      end
      expect(errs).not_to be_empty
    end
  end

  describe '#hostname' do
    it "reports validness of a hostname in silent mode" do
      subject.silent = true
      expect(subject.hostname('100')).to eq true
      expect(subject.hostname('suse')).to eq true
      expect(subject.hostname('suse-01')).to eq true
      expect(subject.hostname('suse-com')).to eq true
      expect(subject.hostname('-suse')).to eq false
      expect(subject.hostname('suse-')).to eq false
      expect(subject.hostname('!suse')).to eq false
    end

    it "reports validness of a hostname in silent mode" do
      subject.silent = false
      expect(subject.hostname('100')).to eq nil
      expect(subject.hostname('suse')).to eq nil
      expect(subject.hostname('suse-01')).to eq nil
      expect(subject.hostname('suse-com')).to eq nil
      expect(subject.hostname('-suse')).to be_kind_of ::String
      expect(subject.hostname('suse-')).to be_kind_of ::String
      expect(subject.hostname('!suse')).to be_kind_of ::String
    end

    it "works in a transaction" do
      errors = subject.verbose_check do |check|
        check.hostname('suse-1')
        check.hostname('suse-com')
      end

      expect(errors).to be_empty
      errors = subject.verbose_check do |check|
        check.hostname('suse-1!')
        check.hostname('suse-com')
      end
      expect(errors).not_to be_empty

      flag = subject.silent_check do |check|
        check.hostname('-suse')
        check.hostname('suse-')
      end
      expect(flag).to eq false

      flag = subject.silent_check do |check|
        check.hostname('suse')
        check.hostname('suse-com')
      end
      expect(flag).to eq true
    end
  end

  describe '#unique' do
    it "reports uniqueness in silent mode" do
      subject.silent = true
      expect(subject.unique(['100', '100', '100'])).to eq false
      expect(subject.not_unique(['100', '100', '100'])).to eq true
    end
  end

  describe '#ipv4_in_network_cidr' do
    it 'reports if the given IPv4 belongs to the network' do
      subject.silent = true
      expect(subject.ipv4_in_network_cidr('192.168.100.1', '192.168.100.0/24')).to eq true
      expect(subject.ipv4_in_network_cidr('192.168.100.254', '192.168.100.0/24')).to eq true
      expect(subject.ipv4_in_network_cidr('192.168.100.1', '192.168.100.0/28')).to eq true
      expect(subject.ipv4_in_network_cidr('192.168.100.14', '192.168.100.0/28')).to eq true
      expect(subject.ipv4_in_network_cidr('192.168.100.16', '192.168.100.0/28')).to eq false
    end
    it 'reports if valid instance number will be allowed' do
      subject.silent = true
      expect(subject.sap_instance_number('01')).to eq true
      expect(subject.sap_instance_number('10')).to eq true
      expect(subject.sap_instance_number('99')).to eq true
    end
    it 'reports if invalid instance number will be found' do
      subject.silent = true
      expect(subject.sap_instance_number('1')).to eq false
      expect(subject.sap_instance_number('1A')).to eq false
      expect(subject.sap_instance_number('999')).to eq false
    end
  end
end
