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
# Summary: SUSE High Availability Setup for SAP Products: In-memory logger class
# Authors: Ilya Manyugin <ilya.manyugin@suse.com>

require 'singleton'
require 'logger'
require 'stringio'
require 'socket'

module SapHA
  # Log info messages, warnings and errors into memory
  class NodeLogger
    include Singleton

    attr_reader :node_name

    def initialize
      @fd = StringIO.new
      @logger = Logger.new(@fd)
      @logger.level = Logger::INFO
      @node_name = Socket.gethostname
      @logger.formatter = proc do |severity, datetime, _progname, msg|
        date = datetime.strftime("%Y-%m-%d %H:%M:%S")
        "[#{@node_name}] #{date} #{severity}: #{msg}\n"
      end
    end

    def method_missing(method, *args)
      @logger.send(method, *args)
    end

    def set_debug
      @logger.level = Logger::DEBUG
    end

    def text
      @fd.flush
      @fd.string
    end

    def self.to_html(txt)
      time_rex = '\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}'
      rules = [
        { rex: /^\[(.*)\] (#{time_rex}) (DEBUG): (.*)$/,  color: 'grey'     },
        { rex: /^\[(.*)\] (#{time_rex}) (INFO): (.*)$/,   color: '#009900'  }, # green
        { rex: /^\[(.*)\] (#{time_rex}) (WARN): (.*)$/,   color: '#e6b800'  }, # yellow
        { rex: /^\[(.*)\] (#{time_rex}) (ERROR): (.*)$/,  color: '#800000'  }  # error
      ]
      lines = txt.split("\n").map do |line|
        rule = rules.find { |r| r[:rex].match(line) }
        if rule
          node, time, level, message = rule[:rex].match(line).captures
          # "[#{node}] #{time} #{level}: <font color=\"#{rule[:color]}\">#{message}</font>"
          "<font color=\"\#a6a6a6\">[#{node}] #{time}</font> <font color=\"#{rule[:color]}\">#{level.rjust(5,' ')}</font>: #{message}"
        else
          line
        end
      end
      lines.join("<br>\n")
    end
  end
end
