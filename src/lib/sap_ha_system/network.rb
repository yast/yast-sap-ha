require 'yast'
require 'open3'
require 'timeout'

Yast.import 'NetworkInterfaces'

module Yast
  class HANetwork
    def self.list_all_interfaces
      NetworkInterfaces.Read
      NetworkInterfaces.List("")
    end
  end
end
