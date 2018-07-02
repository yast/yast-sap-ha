# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2018 SUSE Linux GmbH, Nuernberg, Germany.
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
# Summary: SUSE High Availability Setup for SAP Products: unattended installation
# Authors: Ilya Manyugin <ilya.manyugin@suse.com>

require 'yast'
require 'sap_ha/helpers'
require 'sap_ha/exceptions'
require 'sap_ha/node_logger'
require 'sap_ha/wizard/gui_installation_page'
require 'sap_ha/configuration'

# YaST module
module Yast
  # Main client class
  class SAPHAClass < Client
    attr_reader :sequence

    Yast.import 'Sequencer'
    include Yast::UIShortcuts
    include Yast::Logger
    include SapHA::Exceptions

    def initialize
      log.warn "--- called #{self.class}.#{__callee__}: CLI arguments are #{WFM.Args} ---"
      log.warn "--- ARGV is #{ARGV} ---"
    end

    def main
      begin
        parse_command_line
        validate_config
      rescue UnattendedModeException, ConfigValidationException => e
        puts e.message
        log.error e.message
        # FIXME: y2start overrides return code, therefore exit prematurely without shutting down
        # Yast properly, see bsc#1099871
        exit!(1)
      end
      begin
        SapHA::SAPHAInstallation.new(@config, ui).run
      rescue StandardError => e
        log.error "An error occured during the installation"
        log.error e.message
        log.error e.backtrace.to_s
        # Let Yast handle the exception
        raise e
      end
    end

    private

    def parse_command_line
      raise UnattendedModeException, "Client called with wrong command line parameters.\n"\
        "Usage: yast2 sap_ha_unattended <configuration_file>"\
        if WFM.Args.include?('help') || WFM.Args.length != 1
      begin
        @config = YAML.load(File.read(WFM.Args.first))
      rescue Errno::ENOENT => e
        raise UnattendedModeException, "Could not locate configuration file "\
        "'#{WFM.Args.first}': #{e.message}"
      rescue Psych::SyntaxError => e
        raise UnattendedModeException, "Malformed configuration file: #{e.message}"
      end
      raise UnattendedModeException, "Malformed configuration file"\
        if !@config.is_a?(SapHA::HAConfiguration)
    end

    def validate_config
      errors = @config.verbose_validate
      unless errors.empty?
        puts "Errors were detected in the configuration:"
        errors.each { |e| puts "- #{e}" }
        puts "Please fix the errors in the configuration file and try again"
        raise ConfigValidationException, "Errors detected in the configuration"
      end
      # TODO: check if passwords are present in the config
    end

    SAPHA = SAPHAClass.new
    SAPHA.main
  end
end
