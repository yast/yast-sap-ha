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
# Summary: SUSE High Availability Setup for SAP Products: Input validators and checks
# Authors: Ilya Manyugin <ilya.manyugin@suse.com>

require 'sap_ha/exceptions'
require 'yast'
require 'erb'

Yast.import 'IP'
Yast.import 'Hostname'

module Yast
  # Input validators and checks
  class SemanticChecks
    include Singleton
    include Yast::Logger

    attr_accessor :silent

    IDENTIFIER_REGEXP = Regexp.new('^[_a-zA-Z][_a-zA-Z0-9]{0,30}$')
    SAP_SID_REGEXP = Regexp.new('^[A-Z]{3}$')

    def initialize
      @transaction = false
      @errors = []
      @checks_passed = true
      @silent = false
    end

    def ipv4(value, field_name = '')
      flag = IP.Check4(value)
      report_error(flag, IP.Valid4, field_name, value)
    end

    def ipv4_multicast(value, field_name = '')
      flag = IP.Check4(value) && value.start_with('239.')
      msg = 'A valid IPv4 multicast address should belong to the 239.* network.'
      report_error(flag, msg, field_name, value)
    end

    def hostname(value, field_name = '')
      flag = Hostname.Check(value)
      report_error(flag, Hostname.ValidHost, field_name, value)
    end

    def port(value, field_name = '')
      max_port_number = 65_535
      msg = "The port number must be in the interval from 1 to #{max_port_number}."
      begin
        portn = Integer(value)
        flag = 1 <= portn && portn < 65_535
      rescue ArgumentError
        return report_error(false, msg, field_name, value)
      end
      report_error(flag, msg, field_name, value)
    end

    def nonneg_integer(value, field_name = '')
      log.error "--- #{self.class}.#{__callee__} : value=#{value}, field_name=#{field_name} --- "
      flag = true
      begin
        int_ = Integer(value)
        flag &= int_ >= 0
      rescue ArgumentError
        flag = false
      end
      report_error(flag, 'The value must be a non-negative integer.', field_name, value)
    end

    def equal(rvalue, lvalue, message = '', field_name = '')
      eq = rvalue == lvalue
      report_error(eq, message, field_name, nil)
    end

    def not_equal(rvalue, lvalue, message = '', field_name = '')
      neq = rvalue != lvalue
      report_error(neq, message, field_name, nil)
    end

    def unique(args, message = '', field_name = '')
      uniq = (args == (args & args))
      report_error(uniq, message, field_name, nil)
    end

    def not_unique(args, message = '', field_name = '')
      uniq = (args != (args & args))
      report_error(uniq, message, field_name, nil)
    end

    def identifier(value, message = '', field_name = '')
      flag = !IDENTIFIER_REGEXP.match(value).nil?
      report_error(flag, message, field_name, value)
    end

    def integer_in_range(value, low, high, message = '', field_name = '')
      msg = "The value must be in the range between #{low} and #{high}."
      begin
        int = Integer(value)
        flag = low <= int && int <= high
      rescue ArgumentError
        return report_error(false, msg, field_name, value)
      end
      report_error(flag, msg, field_name, value)
    end

    def sap_sid(value, message = '', field_name = '')
      flag = value.length == 3 && !SAP_SID_REGEXP.match(value).nil?
      return report_error(flag, message, field_name, value)
    end

    def ips_belong_to_net(ips, net, message = '', field_name = '')
      last_dot = net.rindex('.')
      return report_error(false, message, field_name, value) if last_dot.nil?
      flag = ips.all? { |ip| ip.start_with?(net[0..last_dot]) }
      return report_error(flag, message, field_name, '')
    end

    def check(verbosity, &block)
      old_silent = @silent
      if verbosity == :verbose
        @silent = false
      else
        @silent = true
      end
      transaction_begin
      yield self
      if verbosity == :verbose
        return transaction_end
      else
        transaction_end
        return @checks_passed
      end
    ensure 
      @silent = old_silent
    end

    def verbose_check
      old_silent = @silent
      @silent = false
      transaction_begin
      yield self
      transaction_end
    ensure
      @silent = old_silent
    end

    def silent_check
      old_silent = @silent
      @silent = true
      transaction_begin
      yield self
      transaction_end
      @checks_passed
    ensure
      @silent = old_silent
    end

    private

    def report_error(flag, message, field_name, value)
      if @transaction
        @checks_passed &&= flag
        @errors << error_string(field_name, message, value) unless @silent || flag
        return
      end
      return flag if @silent
      return error_string(field_name, message, value) unless flag
      nil
    end

    def error_string(field_name, explanation, value = nil)
      field_name = field_name.strip
      explanation = explanation.strip
      explanation = explanation[0..-2] if explanation.end_with? '.'
      explanation = explanation
      if field_name.empty?
        "Invalid input: #{explanation}"
      elsif value.nil? || (value.is_a?(::String) && value.empty?)
        "Invalid entry for #{field_name}: #{explanation}."
      else

        "Invalid entry for #{field_name} (\"#{ERB::Util.html_escape(value)}\"): #{explanation}."
      end
    end

    def transaction_begin
      @errors = []
      @transaction = true
      @checks_passed = true
    end

    def transaction_end
      @transaction = false
      err_copy = @errors.dup
      @errors = []
      err_copy
    end
  end
end
