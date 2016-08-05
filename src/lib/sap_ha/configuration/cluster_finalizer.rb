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
# Summary: SUSE High Availability Setup for SAP Products: Cluster members configuration
# Authors: Ilya Manyugin <ilya.manyugin@suse.com>

require 'yast'
require 'erb'
require 'socket'
require_relative 'base_config'
require 'sap_ha/system/local'
require 'sap_ha/exceptions'

Yast.import 'UI'

module SapHA
  module Configuration
    # Cluster members configuration finalizer
    class ClusterFinalizer < BaseConfig
      def initialize(global_config)
        super
        @screen_name = "Cluster Configuration Finalizer"
      end

      def configured?
        true
      end

      def description
        ""
      end

      def apply(role)
        if role == :master
          SapHA::System::Local.cluster_maintenance(:off)
        else
          true
        end
      end
    end
  end
end
