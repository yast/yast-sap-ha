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
require 'sap_ha/node_logger'

module SapHA
  module Configuration
    # Base class for component configuration
    class BaseConfig
      include Yast::Logger
      include SapHA::Exceptions
      attr_reader :screen_name

      def initialize
        log.debug "--- #{self.class}.#{__callee__} ---"
        raise BaseConfigException,
          "Cannot directly instantiate a BaseConfig" if self.class == BaseConfig
        @screen_name = "Base Component Configuration"
        @exception_type = BaseConfigException
        @nlog = SapHA::NodeLogger
        @yaml_exclude = [:@yaml_exclude, :@nlog]
      end

      def encode_with(coder)
        instance_variables.each do |variable_name|
          next if @yaml_exclude.include? variable_name
          key = variable_name.to_s[1..-1]
          coder[key] = instance_variable_get(variable_name)
        end
        coder['instance_variables'] = instance_variables - @yaml_exclude
      end

      def init_with(coder)
        raise @exception_type,
          "The object has no field named `instance_variables`" if coder['instance_variables'].nil?
        coder['instance_variables'].each do |variable_name|
          key = variable_name.to_s[1..-1]
          instance_variable_set(variable_name, coder[key])
        end
        @nlog = SapHA::NodeLogger
      end

      # Read system parameters
      # Should be only called on a master node
      def read_system
        log.error "--- #{self.class}.#{__callee__} is not implemented yet ---"
        raise @exception_type, "#{self.class}.#{__callee__} is not implemented yet"
      end

      # Check if the user changed the configuration
      def configured?
        return validate
      rescue @exception_type => e
        # here we only rescue the designated exception type
        log.debug "Exception occured when validating #{self.class}: #{e.message}"
        return false
      end

      # Get an HTML description of the settings
      def description
        log.error "--- #{self.class}.#{__callee__} is not implemented yet ---"
        raise @exception_type, "#{self.class}.#{__callee__} is not implemented yet"
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

      # Apply the configuration
      # @param role [Symbol|String] either :master or "slave"
      def apply(role)
        log.error "--- #{self.class}.#{__callee__} (role=#{role}) is not implemented yet ---"
        raise @exception_type, "#{self.class}.#{__callee__} is not implemented yet"
      end

      # Validate model, raising an exception on error
      def validate
        log.error "--- #{self.class}.#{__callee__} is not implemented yet ---"
        raise @exception_type, "Validation failed"
      end
    end
  end
end
