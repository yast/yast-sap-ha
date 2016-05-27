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
# Summary: SUSE High Availability Setup for SAP Products: common routines
# Authors: Ilya Manyugin <ilya.manyugin@suse.com>

require 'erb'

module Yast
  # Common routines
  class SAPHAHelpers
    include Singleton
    include ERB::Util
    include Yast::Logger
    include Yast::I18n
    
    def initialize
      @storage = {}
      @data_path = if ENV['Y2DIR']
                     'data/' # tests or local run
                   else
                     '/usr/share/YaST2/data/sap_ha/' # production
                   end
    end

    # Render an ERB template by its name
    def render_template(basename, binding)
      if !@storage.key? basename
        full_path = File.join(@data_path, basename)
        template = ERB.new(read_file(full_path))
        @storage[basename] = template
      end
      begin
        return @storage[basename].result(binding)
      rescue StandardError => e
        log.error("Error while rendering template '#{full_path}': #{e.message}")
        raise _("Error rendering template.")
      end
    end

    # Load the help file by its name
    def load_help(basename)
      if !@storage.key? basename
        full_path = File.join(@data_path, basename)
        contents = read_file(full_path)
        @storage[basename] = contents
      end
      @storage[basename]
    end

    # Get the path to the file given its name
    def data_file_path(basename)
      File.join(@data_path, basename)
    end

    private

    # Read file's contents
    def read_file(path)
      File.read(path)
    rescue Errno::ENOENT => e
      log.error("Could not find the file '#{path}': #{e.message}.")
      raise _("Program data could not be found. Please reinstall the package.")
    rescue Errno::EACCES => e
      log.error("Could not access the file '#{path}': #{e.message}.")
      raise _("Program data could not be accessed. Please reinstall the package.")
    end
  end
end
