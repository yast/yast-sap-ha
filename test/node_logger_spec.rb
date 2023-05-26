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

require_relative "test_helper"
require "sap_ha/node_logger"

describe SapHA::NodeLogger do
  subject { SapHA::NodeLogger }
  let(:unknown_msg) { "This is an unknown message" }
  let(:debug_msg)   { "This is a debug message" }
  let(:info_msg)    { "This is an info message" }
  let(:warn_msg)    { "This is a warning message!" }
  let(:error_msg)   { "This is an error message!!!" }
  let(:fatal_msg)   { "This is a fatal message!!!1111" }

  describe "#instance" do
    it "works" do
      expect(subject).not_to be_nil
    end
  end

  describe "#text" do
    it "returns a plain-text log" do
      subject.unknown(unknown_msg)
      subject.debug(debug_msg)
      subject.info(info_msg)
      subject.warn(warn_msg)
      subject.error(error_msg)
      subject.fatal(fatal_msg)
      text = subject.text
      expect(text).to match(/OUTPUT: #{unknown_msg}/)
      expect(text).not_to match(/DEBUG: #{debug_msg}/)
      expect(text).to match(/INFO: #{info_msg}/)
      expect(text).to match(/WARN: #{warn_msg}/)
      expect(text).to match(/ERROR: #{error_msg}/)
      expect(text).to match(/FATAL: #{fatal_msg}/)
    end
  end

  describe "#set_debug" do
    it "enables debug logging" do
      subject.set_debug
      subject.debug(debug_msg)
      expect(subject.text).to match(/DEBUG: #{debug_msg}/)
    end
  end

  describe "#to_html" do
    it "converts a plain-text log into HTML representation" do

      def colored_level(level_name)
        '<font color="[^"]+"><b>\s+%s</b></font>' % level_name
      end

      html = SapHA::NodeLogger.to_html(subject.text)
      expect(html).to match(/#{colored_level('DEBUG')}: #{debug_msg}/)
      expect(html).to match(/#{colored_level('INFO')}: #{info_msg}/)
      expect(html).to match(/#{colored_level('WARN')}: #{warn_msg}/)
      expect(html).to match(/#{colored_level('ERROR')}: #{error_msg}/)
      expect(html).to match(/#{colored_level('FATAL')}: #{fatal_msg}/)
      # the command output line is prepended only by the host name
      expect(html).not_to match(/#{colored_level('OUTPUT')}: #{unknown_msg}/)
      expect(html).to match(/font> #{unknown_msg}/)
    end
  end

end
