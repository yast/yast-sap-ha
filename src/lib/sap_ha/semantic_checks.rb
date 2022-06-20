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

module SapHA
  # Input validators and checks
  class SemanticChecks
    include Singleton
    include Yast::Logger

    attr_accessor :silent
    attr_reader :checks_passed

    #Site identifier regexp. That is what SAP allows. All ASCII charactest from 33 until 125
    #expect of '*' and '/'. The identifier can be 256 character long
    #IDENTIFIER_REGEXP = Regexp.new('^[\x22-\x29\x2B-\x2E\x30-\x7E]{1,256}$')
    #However, for security and technical reasons, we only allow alphanumeric characters as well as '-' and '_'.
    #The identifier must not be longer than 30 characters and it must be minimum 2 long.
    IDENTIFIER_REGEXP = Regexp.new('^[a-zA-Z0-9][a-zA-Z0-9_\-]{1,29}$')
    SAP_SID_REGEXP = Regexp.new('^[A-Z][A-Z0-9]{2}$')
    RESERVED_SAP_SIDS = %w(ADD ALL AND ANY ASC COM DBA END EPS FOR GID IBM INT KEY LOG MON NIX
                           NOT OFF OMS RAW ROW SAP SET SGA SHG SID SQL SYS TMP UID USR VAR).freeze

    def initialize
      @transaction = false
      @errors = []
      @checks_passed = true
      @silent = true
    end

    # Check if the string is a valid IPv4 address
    # @param value [String] IP address
    # @param field_name [String] name of the field in the form
    def ipv4(value, field_name = '')
      flag = Yast::IP.Check4(value)
      report_error(flag, Yast::IP.Valid4, field_name, value)
    end

    # Check if the string is a valid IPv4 netmask
    # @param value [String] network mask
    # @param field_name [String] name of the field in the form
    def ipv4_netmask(value, field_name = '')
      flag = Yast::Netmask.Check4(value)
      report_error(flag, 'A valid network mask consists of 4 octets separated by dots.',
        field_name, value)
    end

    # Check if the string is a valid IPv4 multicast address
    # @param value [String] IP address
    # @param field_name [String] name of the field in the form
    def ipv4_multicast(value, field_name = '')
      flag = Yast::IP.Check4(value) && value.start_with?('239.')
      msg = 'A valid IPv4 multicast address should belong to the 239.* network.'
      report_error(flag, msg, field_name, value)
    end

    # Check if the IP belongs to the specified network given along with a CIDR netmask
    # @param ip [String] IP address
    # @param network [String] IP address
    # @param field_name [String] name of the field in the form
    def ipv4_in_network_cidr(ip, network, field_name = '')
      begin
        flag = IPAddr.new(network).include?(ip)
      rescue StandardError
        flag = false
      end
      msg = "IP address has to belong to the network #{network}."
      report_error(flag, msg, field_name, ip)
    end

    # Check if the provided IPs belong to the network
    # @param ips [Array[String]]
    # @param network [String]
    # @param message [String] custom error message
    # @param field_name [String] name of the related field in the form
    def ipsv4_in_network_cidr(ips, network, message = '', field_name = '')
      message = "IP addresses have to belong to the network #{network}" \
        if message.nil? || message.empty?
      begin
        net = IPAddr.new(network)
      rescue IPAddr::InvalidAddressError
        return
      end
      flag = ips.map { |ip| net.include?(ip) }.all?
      report_error(flag, message, field_name, '')
    end

    # Check if the provided value is a valid hostname
    # @param value [String] hostname to check
    # @param field_name [String] name of the field in the form
    def hostname(value, field_name = '')
      flag = Yast::Hostname.Check(value)
      report_error(flag, Yast::Hostname.ValidHost, field_name, value)
    end

    # Check if the provided value is a valid port number
    # @param value [String] port number to check
    # @param field_name [String] name of the field in the form
    def port(value, field_name = '')
      max_port_number = 65_535
      msg = "The port number must be in between 1 and #{max_port_number}."
      begin
        portn = Integer(value)
        flag = 1 <= portn && portn <= 65_535
      rescue ArgumentError, TypeError
        return report_error(false, msg, field_name, value)
      end
      report_error(flag, msg, field_name, value)
    end

    # Check if the provided value is a non-negative integer
    # @param value [Integer] value to check
    # @param field_name [String] name of the field in the form
    def nonneg_integer(value, field_name = '')
      flag = true
      begin
        int_ = Integer(value)
        flag &= int_ >= 0
      rescue ArgumentError
        flag = false
      end
      report_error(flag, 'The value must be a non-negative integer.', field_name, value)
    end

    # Check if the element belongs to the set
    # @param element [Any]
    # @param set [Array[Any]]
    # @param message [String] custom error message
    # @param field_name [String] name of the field in the form
    def element_in_set(element, set, message = '', field_name = '')
      flag = set.include? element
      message = "The value must be in the set [#{set.join(', ')}]" if message.nil? || message.empty?
      report_error(flag, message, field_name, element)
    end

    # Check if the intersection of two sets is not empty
    # @param set1 [Array]
    # @param set2 [Array]
    # @param message [String] custom error message
    # @param field_name [String] name of the related field in the form
    def intersection_not_empty(set1, set2, message = '', field_name = '')
      flag = !(set1 & set2).empty?
      report_error(flag, message, field_name, '')
    end

    # Check if the values match
    # @param rvalue [Any]
    # @param lvalue [Any]
    # @param message [String] custom error message
    # @param field_name [String] name of the related field in the form
    def equal(rvalue, lvalue, message = '', field_name = '')
      eq = rvalue == lvalue
      report_error(eq, message, field_name, nil)
    end

    # Check if the values don't match
    # @param rvalue [Any]
    # @param lvalue [Any]
    # @param message [String] custom error message
    # @param field_name [String] name of the related field in the form
    def not_equal(rvalue, lvalue, message = '', field_name = '')
      neq = rvalue != lvalue
      report_error(neq, message, field_name, nil)
    end

    # Check if the set has only unique elements
    # @param set [Array]
    # @param message [String] custom error message
    # @param field_name [String] name of the related field in the form
    def unique(set, message = '', field_name = '')
      uniq = (set == (set & set))
      report_error(uniq, message, field_name, nil)
    end

    # Check if the set has non-unique elements
    # @param set [Array]
    # @param message [String] custom error message
    # @param field_name [String] name of the related field in the form
    def not_unique(set, message = '', field_name = '')
      uniq = (set != (set & set))
      report_error(uniq, message, field_name, nil)
    end

    # Check if the provided value is a valid identifier (i.e., a name)
    # @param value [String]
    # @param message [String] custom error message
    # @param field_name [String] name of the related field in the form
    def identifier(value, message = '', field_name = '')
      flag = !IDENTIFIER_REGEXP.match(value).nil?
      message = 'The value should be a valid identifier' if message.nil? || message.empty?
      report_error(flag, message, field_name, value)
    end

    # Check if the provided integer is in the range [low, high]
    # @param value [Integer]
    # @param low [Integer]
    # @param high [Integer]
    # @param message [String] custom error message
    # @param field_name [String] name of the related field in the form
    def integer_in_range(value, low, high, message = '', field_name = '')
      message = "The value must be in the range between #{low} and #{high}." \
        if message.nil? || message.empty?
      begin
        int = Integer(value)
        flag = low <= int && int <= high
      rescue ArgumentError, TypeError
        return report_error(false, message, field_name, value)
      end
      report_error(flag, message, field_name, value)
    end

    # Check if the provided value is a correct SAP System ID
    # @param value [String]
    # @param message [String] custom error message
    # @param field_name [String] name of the related field in the form
    def sap_sid(value, message = '', field_name = '')
      message = "A valid SAP System ID consists of three characters, starts with a letter, and "\
      " must not collide with one of the reserved IDs" if message.nil? || message.empty?
      flag = !SAP_SID_REGEXP.match(value).nil? && !RESERVED_SAP_SIDS.include?(value)
      report_error(flag, message, field_name, value)
    end

    # Check if the provided value is a correct SAP Instance number
    # @param value [String]
    # @param message [String] custom error message
    # @param field_name [String] name of the related field in the form
    def sap_instance_number(value, message, field_name)
      return report_error(false, 'The SAP Instance number must be a string of exactly two digits',
        field_name, value) unless value.is_a?(::String) && value.length == 2
      integer_in_range(value, 0, 99, message, field_name)
    end

    # Check if the provided value is a non-empty string
    # @param value [String]
    # @param message [String] custom error message
    # @param field_name [String] name of the related field in the form
    def non_empty_string(value, message, field_name, hide_value = false)
      flag = value.is_a?(::String) && !value.empty?
      shown_value = hide_value ? '' : value
      report_error(flag, message || "The value must be a non-empty string", field_name, shown_value)
    end

    # Check if string is a block device
    # @param value [String] device path
    def block_device(value, field_name)
      msg = "The provided path does not point to a block device."
      begin
        flag = File::Stat.new(value).blockdev?
      rescue StandardError
        flag = false
      end
      log.error "BLK: #{value}.blockdev? = #{flag}"
      report_error(flag, msg, field_name, value)
    end

    # Start a transactional check
    def check(verbosity)
      old_silent = @silent
      @silent = if verbosity == :verbose
                  false
                else
                  true
                end
      transaction_begin
      yield self
      return transaction_end if verbosity == :verbose
      transaction_end
      return @checks_passed
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

    # Check the values entered in the popup dialog
    # @param method [Method] validation routine
    # @param hash [Hash] values to validate
    def check_popup(method, hash)
      check(:verbose) do |check|
        method.call(check, hash)
      end
    end

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

    private

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
