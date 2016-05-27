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

Yast.import 'IP'
Yast.import 'Hostname'

module Yast
  # Input validators and checks
  class SemanticChecks
    include Singleton
    include Yast::Logger

    attr_accessor :silent

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

    def hostname(value, field_name = '')
      flag = Hostname.Check(value)
      report_error(flag, Hostname.ValidHost, field_name, value)
    end

    def port(value, field_name = '')
      max_port_number = 65_535
      msg = "The port number must be in the interval from 1 to #{max_port_number}."
      if value.is_a?(::String) && value.empty?
        portn = 0
      else
        portn = Integer(value)
      end
      flag = 1 < portn && portn < 65_535
      report_error(flag, msg, field_name, value)
    end

    def equal(rvalue, lvalue, message = '', inverse = false)
      eq = rvalue == lvalue
      return eq if @silent
      return nil if eq ^ inverse
      return message unless @transaction
      @errors << message
    end

    def unique(message = '', inverse = false, *args)
      uniq = (args == (args & args))
      return uniq if @silent
      return nil if uniq ^ inverse
      return message unless @transaction
      @errors << message
    end

    def error_string(field_name, explanation, value = nil)
      field_name = field_name.strip
      explanation = explanation.strip
      explanation = explanation[0..-2] if explanation.end_with? '.'
      if field_name.empty?
        "Invalid input: #{explanation}"
      elsif value.nil? || (value.is_a?(::String) && value.empty?) || @transaction
        "Invalid entry for #{field_name}: #{explanation}."
      else
        "Invalid entry for #{field_name} [#{value}]: #{explanation}."
      end
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

    def report_error(flag, message, fiel_name, value)
      if @transaction
        @checks_passed &&= flag
        @errors << error_string(fiel_name, message, value) unless @silent || flag
      end
      return flag if @silent
      return error_string(fiel_name, message, value) unless flag
      nil
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
