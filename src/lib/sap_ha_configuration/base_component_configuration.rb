# Base class for component configuration

module Yast
  class BaseComponentConfiguration
    def initialize
      @storage = {}
    end

    def print
      inspect
    end

    def configured?
      false
    end

    def description
      ""
    end
  end
end