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
# Summary: SUSE High Availability Setup for SAP Products: Base configuration class
# Authors: Ilya Manyugin <ilya.manyugin@suse.com>

require "yast"
require "sap_ha/exceptions"
require "sap_ha/semantic_checks"
require "sap_ha/node_logger"

module SapHA
  module Configuration
    # Base class for component configuration
    class BaseConfig
      include Yast::Logger
      include SapHA::Exceptions
      attr_reader :screen_name

      def initialize(global_config)
        @global_config = global_config
        log.debug "--- #{self.class}.#{__callee__} ---"
        raise BaseConfigException,
          "Cannot directly instantiate a BaseConfig" if self.class == BaseConfig
        @screen_name = "Base Component Configuration"
        @exception_type = BaseConfigException
        @nlog = SapHA::NodeLogger
        # Exclude these members from marshalling with YAML
        @yaml_exclude = [:@nlog]
      end

      def encode_with(coder)
        log.debug "--- #{self.class}.#{__callee__}(#{coder}) ---"
        instance_variables.each do |variable_name|
          next if !@yaml_exclude.nil? && @yaml_exclude.include?(variable_name)
          key = variable_name.to_s[1..-1]
          coder[key] = instance_variable_get(variable_name)
        end
        coder["instance_variables"] = instance_variables - @yaml_exclude if @yaml_exclude
      end

      def init_with(coder)
        log.debug "--- #{self.class}.#{__callee__}(#{coder}) ---"
        raise @exception_type,
          "The object has no field named `instance_variables`" if coder["instance_variables"].nil?
        coder["instance_variables"].each do |variable_name|
          key = variable_name.to_s[1..-1]
          instance_variable_set(variable_name, coder[key])
        end
        @nlog = SapHA::NodeLogger
      end

      # Read system parameters
      # Should be only called on a master node
      def read_system
        log.error "--- #{self.class}.#{__callee__} is not implemented yet ---"
        raise @exception_type, "#{self.class}.#{__callee__} is not implemented yet"
      end

      # Check if the user changed the configuration
      def configured?
        return validate
      rescue @exception_type => e
        # here we only rescue the designated exception type
        log.debug "Exception occured when validating #{self.class}: #{e.message}"
        return false
      end

      # Get an HTML description of the settings
      def description
        log.error "--- #{self.class}.#{__callee__} is not implemented yet ---"
        raise @exception_type, "#{self.class}.#{__callee__} is not implemented yet"
      end

      def import(hash)
        log.debug "--- #{self.class}.#{__callee__}: #{hash} ---"
        return if hash.nil? || hash.empty?
        hash.each do |k, v|
          name = k.to_s.start_with?("@") ? k : "@#{k}".to_sym
          instance_variable_set(name, v)
        end
      end

      def export
        log.debug "--- #{self.class}.#{__callee__} ---"
        Hash[instance_variables.map { |name| [name, instance_variable_get(name)] }]
      end

      # Apply the configuration
      # @param role [Symbol|String] either :master or "slave"
      def apply(role)
        log.error "--- #{self.class}.#{__callee__} (role=#{role}) is not implemented yet ---"
        raise @exception_type, "#{self.class}.#{__callee__} is not implemented yet"
      end

      # Validate model, raising an exception on error
      def validate(_verbosity = :verbose)
        log.error "--- #{self.class}.#{__callee__} is not implemented yet ---"
        raise @exception_type, "Validation failed"
      end

      def html_errors
        errors = validate(:verbose)
        tmpl = "<ul>
        <% errors.each do |error| %>
          <li> <%= error %> </li>
        <% end %>
        </ul>
        "
        ERB.new(tmpl, nil, "-").result(binding)
      end

      def prepare_description
        d = Description.new
        d.start
        yield d
        d.end
      end
    end

    class Description
      def initialize
        @lines = []
        @list_type = "ol"
        @ncurses = Yast::UI.TextMode
      end

      def start
        @lines = []
        @lines << "<table>" unless @ncurses
      end

      def end
        @lines << "</table>" unless @ncurses
        @lines.join("\n")
      end

      def header(value)
        @lines << "<tr><td><h4>#{value}</h4><td></tr>"
      end

      def parameter(name, value)
        if @ncurses
          @lines << "<b>#{name}</b>: #{value}" << "<br>"
        else
          @lines << "<tr>" << "<td>#{name}</td>" << "<td><code>#{value}</code></td>" << "</tr>"
        end
      end

      # immediate parameter value: return the decorated value
      def iparam(value)
        if @ncurses
          # avoid using <code> in ncurses mode, as it is almost unreadable
          value.to_s
        else
          "<code>#{value}</code>"
        end
      end

      def list_begin(name, opts = {})
        @list_type = opts[:type] ? opts[:type] : @list_type
        @lines << "<tr>\n<td  colspan=\"2\">" \
          << "<span class=\"list_hdr\">#{name}</span>" << "<#{@list_type}>"
      end

      def list_item(str)
        @lines << "<li>#{str}</li>"
      end

      def list_end
        @lines << "</#{@list_type}>" << "</td></tr>"
      end
    end
  end
end
