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
# Summary: SUSE High Availability Setup for SAP Products: Base configuration class
# Authors: Ilya Manyugin <ilya.manyugin@suse.com>

require 'yast'
require 'sap_ha/exceptions'
require 'sap_ha/semantic_checks'

module Yast
  # Base class for component configuration
  class BaseComponentConfiguration
    include Yast::Logger

    attr_reader :screen_name

    def initialize
      log.debug "--- #{self.class}.#{__callee__} ---"
      @screen_name = "Base Component Configuration"
      @exception_type = SAPHAException
    end

    # Read system parameters
    # Should be only called on a master node
    def read_system
    end

    # Check if the user changed the configuration
    def configured?
      begin
        return validate
      rescue @exception_type => e
        # here we only rescue the designated exception type
        return false
      end
    end


    # Get an HTML description of the settings
    def description
      ""
    end

    # Check the settings for consistency
    def consistent?
      false
    end

    def import(hash)
      log.debug "--- #{self.class}.#{__callee__}: #{hash} ---"
      hash.each do |k, v|
        name = k.to_s.start_with?('@') ? k : "@#{k}".to_sym
        instance_variable_set(name, v)
     end
    end

    def export
      Hash[instance_variables.map { |name| [name, instance_variable_get(name)] }]
    end

    def apply(role)
      log.error "#{self.class}.#{__callee__} (role=#{role}) is not implemented yet"
      raise SAPHAException, '#{self.class}.#{__callee__} is not implemented yet'
    end

    def bogus_apply
      sleep 0.5
      true
    end

    # Validate model, raising an exception on error
    def validate
      raise @exception_type, "Validation failed"
    end
  end
end
