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
# Summary: SUSE High Availability Setup for SAP Products: Tests
# Authors: Ilya Manyugin <ilya.manyugin@suse.com>

require_relative 'test_helper'
require 'sap_ha_system/node_logger'

describe SapHA::NodeLogger do
  subject { SapHA::NodeLogger.instance }
  let(:unknown_msg) { 'This is an unknown message' }
  let(:debug_msg)   { 'This is a debug message' }
  let(:info_msg)    { 'This is an info message' }
  let(:warn_msg)    { 'This is a warning message!' }
  let(:error_msg)   { 'This is an error message!!!' }

  describe '#instance' do
    it 'works' do
      expect(subject).not_to be_nil
    end
  end

  describe '#method_missing' do
    it 'proxies logger calls' do
      subject.method_missing(:unknown, unknown_msg)
      expect(subject.text).to match(/ANY: #{unknown_msg}/)
    end
  end

  describe '#text' do
    it 'returns a plain-text log' do
      subject.debug(debug_msg)
      subject.info(info_msg)
      subject.warn(warn_msg)
      subject.error(error_msg)
      text = subject.text
      expect(text).not_to match(/DEBUG: #{debug_msg}/)
      expect(text).to match(/INFO: #{info_msg}/)
      expect(text).to match(/WARN: #{warn_msg}/)
      expect(text).to match(/ERROR: #{error_msg}/)
    end
  end

  describe '#set_debug' do
    it 'enables debug logging' do
      subject.set_debug
      subject.debug(debug_msg)
      expect(subject.text).to match(/DEBUG: #{debug_msg}/)
    end
  end

  describe '#to_html' do
    it 'converts a plain-text log into HTML representation' do
      text = subject.text
      html = SapHA::NodeLogger.to_html(text)
      expect(html).to match(/DEBUG: <font color="grey">#{debug_msg}<\/font>/)
      expect(html).to match(/INFO: <font color="green">#{info_msg}<\/font>/)
      expect(html).to match(/WARN: <font color="yellow">#{warn_msg}<\/font>/)
      expect(html).to match(/ERROR: <font color="red">#{error_msg}<\/font>/)
      expect(html).to match(/ANY: #{unknown_msg}/)
    end
  end

end
