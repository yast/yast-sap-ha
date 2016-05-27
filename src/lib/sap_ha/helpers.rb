require 'erb'

module Yast
  class SAPHAHelpers
    include Singleton
    include ERB::Util
    include Yast::Logger
    include Yast::I18n
    
    def initialize
      @storage = {}
      # TODO: change in production
      @data_path = 'data/' # '/usr/share/YaST2/data/sap-ha/'
    end

    def render_template(path, binding)
      if !@storage.key? path
        full_path = File.join(@data_path, path)
        template = ERB.new(read_file(full_path))
        @storage[path] = template
      end
      begin
        return @storage[path].result(binding)
      rescue StandardError => e
        log.error("Error while rendering template '#{full_path}': #{e.message}")
        raise _("Error rendering template.")
      end
    end

    # TODO: rename to load_help
    def load_html_help(path)
      if !@storage.key? path
        full_path = File.join(@data_path, path)
        contents = read_file(full_path)
        @storage[path] = contents
      end
      @storage[path]
    end

    def data_file_path(basename)
      File.join(@data_path, basename)
      # TODO error handling
    end
    private

    def read_file(path)
      File.read(path)
    rescue Errno::ENOENT => e
      log.error("Could not find the template file '#{path}': #{e.message}.")
      raise _("Program data could not be found. Please reinstall the package.")
    rescue Errno::EACCES => e
      log.error("Could not access the template file '#{path}': #{e.message}.")
      raise _("Program data could not be accessed. Please reinstall the package.")
    end
  end
end
