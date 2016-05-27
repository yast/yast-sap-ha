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