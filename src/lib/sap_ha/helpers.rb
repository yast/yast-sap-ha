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
# Authors: Peter Varkoly <varkoly@suse.com>

require "yast/i18n"
require 'erb'
require 'tmpdir'
require 'sap_ha/exceptions'
require 'net/http'

module SapHA
  # Common routines
  class HelpersClass
    include Singleton
    include ERB::Util
    include Yast::Logger
    include Yast::I18n
    include SapHA::Exceptions

    attr_reader :rpc_server_cmd

    FILE_DATE_TIME_FORMAT = '%Y%m%d_%H%M%S'.freeze

    def initialize
      textdomain "hana-ha"
      @storage = {}
      if ENV['Y2DIR'] # tests/local run
        @data_path = 'data/'
        @var_path = File.join(Dir.tmpdir, 'yast-sap-ha-tmp')
        begin
          Dir.mkdir(@var_path)
        rescue StandardError => e
          log.debug "Cannot create the tmp_dir: #{e.message}"
        end
        # We get the Y2DIR relative RPC Server location as it is running on dev mode.
        y2dir_path = File.expand_path("../", __FILE__)
        @rpc_server_cmd = 'systemd-cat /usr/bin/ruby '\
          "#{y2dir_path}/rpc_server.rb"
      else # production
        @data_path = '/usr/share/YaST2/data/sap_ha'
        @var_path = '/var/lib/YaST2/sap_ha'
        # /sbin/yast in SLES, /usr/sbin/yast in OpenSuse
        # @rpc_server_cmd = 'yast sap_ha_rpc'
        # TODO: fix it
        @rpc_server_cmd = 'systemd-cat /usr/bin/ruby '\
          '/usr/share/YaST2/lib/sap_ha/rpc_server.rb'
      end
    end

    # Render an ERB template by its name
    def render_template(basename, binding)
      log.debug "--- called #{self.class}.#{__callee__}(#{basename}) ---"
      full_path = data_file_path(basename)
      if !@storage.key? basename
        template = ERB.new(read_file(full_path), nil, '-')
        @storage[basename] = template
      end
      begin
        return @storage[basename].result(binding)
      rescue StandardError => e
        log.error("Error while rendering template '#{full_path}': #{e.message}")
        exc = TemplateRenderException.new("Error rendering template.")
        exc.renderer_message = e.message
        raise exc
      end
    end

    # Load the help file by its name
    def load_help(basename, platform="")
      log.debug "--- called #{self.class}.#{__callee__}(#{basename}) ---"
      if platform == "bare-metal" || platform.to_s.strip.empty?
        file_name = "help_#{basename}.html"
      else
        file_name = "help_#{basename}_#{platform}.html"
      end
      if !@storage.key? file_name
        full_path = File.join(@data_path, file_name)
        # TODO: apply the CSS
        contents = read_file(full_path)
        @storage[file_name] = contents
      end
      @storage[file_name]
    end

    # Get the path to the file given its name
    def data_file_path(basename)
      log.debug "--- called #{self.class}.#{__callee__}(#{basename}) ---"
      File.join(@data_path, basename)
    end

    def var_file_path(basename)
      log.debug "--- called #{self.class}.#{__callee__}(#{basename}) ---"
      File.join(@var_path, basename)
    end

    # Write a file to /var/lib/YaST2/sap_ha
    # Use it for logs and intermediate configuration files
    def write_var_file(basename, data, options = {})
      log.debug "--- called #{self.class}.#{__callee__}(#{basename}, #{data}, #{options}) ---"
      basename = timestamp_file(basename, options[:timestamp])
      file_path = var_file_path(basename)
      write_file(file_path, data)
      log.debug "--- called #{self.class}.#{__callee__}: Wrote file #{file_path} ---"
      file_path
    end

    # Get configuration files from the previous runs
    # Pass parameters for filtering or pass
    # @param product_id [String]
    # @param scenario_name [String]
    def get_configuration_files(product_id = nil, scenario_name = nil)
      log.debug "--- called #{self.class}.#{__callee__}(#{product_id}, #{scenario_name}) ---"
      files = Dir.chdir(@var_path) { Dir.glob('configuration_*.yml') }
      configs = files.map { |fn| YAML.load(read_file(var_file_path(fn))) }
      selected = configs.select do |c|
        (product_id.nil? || c.product_id == product_id) &&
          (scenario_name.nil? || c.scenario_name == scenario_name) &&
          (c.completed.nil? || c.completed == false)
      end
      selected.map { |c| ["#{c.product_name} Installation [#{c.timestamp.utc}]", c] }
    end

    def write_file(path, data)
      log.debug "--- called #{self.class}.#{__callee__}(#{path}, #{data}) ---"
      begin
        File.open(path, 'wb') do |fh|
          fh.write(data)
        end
      rescue RuntimeError => e
        log.error "Error writing file #{path}: #{e.message}"
        return false
      end
      true
    end

    def open_url(url)
      log.debug "--- called #{self.class}.#{__callee__}(#{url}) ---"
      require 'yast'
      Yast.import 'UI'
      Yast::UI.BusyCursor
      system("xdg-open #{url}")
      sleep 5
      Yast::UI.NormalCursor
    end

    def timestamp_file(basename, timestamp = nil)
      log.debug "--- called #{self.class}.#{__callee__}(#{basename}, #{timestamp}) ---"
      return basename if timestamp.nil?
      ext = File.extname(basename)
      name = File.basename(basename, ext)
      basename = "#{name}_#{Time.now.strftime('%Y%m%d_%H%M%S')}#{ext}"
    end

    def version_comparison(version_target, version_current, cmp = '>=')
      log.debug "--- called #{self.class}.#{__callee__}(#{version_target}, #{version_current}, #{cmp}) ---"
      Gem::Dependency.new('', cmp + version_target).match?('', version_current)
    rescue StandardError => e
      log.error "HANA version comparison failed: target=#{version_target},"\
      " current=#{version_current}, cmp=#{cmp}."
      log.error "Gem::Dependency.match? :: #{e.message}"
      return false
    end

    # Set platform according to it's environment (default is bare-metal)
    def platform_check
      if is_azure?
        return "azure"
      else
        return "bare-metal"
      end
    end

    # Check if environment is running on Microsoft Azure by
    # looking if instance metadata service is available
    def is_azure?
      result = Yast::SCR.Execute(Yast::Path.new(".target.bash_output"), "dmidecode -t system | grep Manufacturer")
      if result["stdout"].strip.to_s == "Manufacturer: Microsoft Corporation"
        url_metadata = URI.parse("http://169.254.169.254/metadata/instance?api-version=2017-04-02")
        meta_service = Net::HTTP.new(url_metadata.host)
        meta_service.read_timeout = 2
        meta_service.open_timeout = 2
        request = Net::HTTP::Get.new(url_metadata.request_uri)
        request["Metadata"] = "true"
        begin
          response = meta_service.request(request)
          case response
            when Net::HTTPSuccess then
              return true
            else
              return false
          end
        rescue Net::OpenTimeout => e
          log.error("Network timeout checking Azure metadata service: #{e.message}.")
          return false
        end
      else
        return false
      end
    end

    private

    # Read file's contents
    def read_file(path)
      log.debug "--- called #{self.class}.#{__callee__}(#{path}) ---"
      File.read(path)
    rescue Errno::ENOENT => e
      log.error("Could not find the file '#{path}': #{e.message}.")
      raise _("Program data could not be found. Please reinstall the package.")
    rescue Errno::EACCES => e
      log.error("Could not access the file '#{path}': #{e.message}.")
      raise _("Program data could not be accessed. Please reinstall the package.")
    end
  end

  Helpers = HelpersClass.instance
end
