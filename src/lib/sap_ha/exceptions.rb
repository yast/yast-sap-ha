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
# Summary: SUSE High Availability Setup for SAP Products: Base exceptions
# Authors: Ilya Manyugin <ilya.manyugin@suse.com>

module SapHA
  module Exceptions
    # Base exceptions
    class BaseException < StandardError
    end

    # Configuration component base exception
    class BaseConfigException < BaseException
    end

    class TemplateRenderException < BaseException
      attr_accessor :renderer_message
    end

    class ModelValidationGUIException < BaseException
      attr_accessor :error_messages
    end

    class LocalSystemException < BaseException
    end

    # Base model validation exception
    class ModelValidationException < BaseException
    end

    class HAConfigurationException < BaseException
    end

    class ProductNotFoundException < HAConfigurationException
    end

    class ScenarioNotFoundException < HAConfigurationException
    end

    class SSHException < BaseException
    end

    class SSHConnectionException < SSHException
    end

    class SSHAuthException < SSHException
    end

    class SSHPassException < SSHException
    end

    class SSHKeyException < SSHException
    end

    # An exception that will display a message to the user
    class GUIException < BaseException
    end

    class GUIWarning < GUIException
    end

    class GUIError < GUIException
    end

    class GUIFatal < GUIException
    end

    class WatchdogConfigurationException < BaseException
    end

    class ClusterConfigurationException < ModelValidationException
    end
  end
end
