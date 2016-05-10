require 'erb'

module Yast
  class SAPHAHelpersClass
    
    include ERB::Util
    include Yast::Logger
    include Yast::I18n
    
    def initialize
      @storage = {}
    end

    def render_template(path, binding)
      if not @storage.key? path
        # TODO: figure out the path
        full_path = File.join('data/', path)
        template = ERB.new(read_file(full_path))
        @storage[path] = template
      end
      begin
        return @storage[path].result(binding)
      rescue Exception => e
        log.error("Error while rendering template '#{full_path}': #{e.message}")
        raise RuntimeError, _("Error rendering template.")
      end
    end

    def load_html_help(path)
      if not @storage.key? path
        # TODO: figure out the path
        full_path = File.join('data/', path)
        contents = read_file(full_path)
        @storage[path] = contents
      end
      return @storage[path]
    end

    private

    def read_file(path)
      begin
        File.read(path)
      rescue Errno::ENOENT => e
        log.error("Could not find the template file '#{path}'.")
        raise RuntimeError, _("Program data could not be found. Please reinstall the package.")
      rescue Errno::EACCES => e
        log.error("Could not access the template file '#{path}'.")
        raise RuntimeError, _("Program data could not be accessed. Please reinstall the package.")
      end
    end
  end
  SAPHAHelpers = SAPHAHelpersClass.new
end
