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
module Yast
  # Base class for component configuration
  class BaseComponentConfiguration
    include Yast::Logger
    def initialize
      @storage = {}
    end

    def print
      inspect
    end

    # Check if the user changed the configuration
    def configured?
      false
    end

    # Get an HTML description of the settings
    def description
      ""
    end

    # Check the settings for consistency
    def consistent?
      false
    end

    def unsafe_import(hash)
      log.info "--- #{self.class}.#{__callee__}: #{hash} ---"
      hash.each { |k, v| instance_variable_set("@#{k}".to_sym, v) }
    end
  end
end
