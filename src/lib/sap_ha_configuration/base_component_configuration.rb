# Base class for component configuration

module Yast
  class BaseComponentConfiguration
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
  end
end