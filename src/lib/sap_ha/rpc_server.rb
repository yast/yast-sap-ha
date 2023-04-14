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
# Summary: SUSE High Availability Setup for SAP Products: XML RPC Server
# Authors: Ilya Manyugin <ilya.manyugin@suse.com>

ENV['Y2DIR'] = File.expand_path('../../../../src', __FILE__)

require 'yast'
require "xmlrpc/server"
require "sap_ha/configuration"
require "sap_ha/helpers"
require "sap_ha/system/shell_commands"
require 'psych'
require 'logger'
require 'socket'

Yast.import 'Service'

module SapHA
  # RPC Server for inter-node communication
  #
  # Exposes the following functions in the sapha.* namespace:
  # - Non-polled calls (block and return the value)
  #   + `sapha.import_config(yaml_string)` : recreates the marshalled config on the RPC Server's side
  #   + `sapha.config.start_setup()` : notify the node
  #   + `sapha.config.end_setup()` : notify the node
  #   + `sapha.config.collect_log()` : get the log
  #   + `sapha.busy()` : true if the node is busy with configuration
  #   + `sapha.shutdown()` : shut down the RPC server
  # - Polled calls:
  #   + `sapha.config_#{component}.apply(role)`
  #
  # Polled calls return immediately,
  class RPCServer
    include System::ShellCommands

    LOG_FILE_PATH = '/tmp/rpc_serv'

    def initialize(options = {})
      init_logger
      @logger.info "--- #{self.class}.#{__callee__} ---"
      if options[:local]
        @server = XMLRPC::Server.new(8080, '127.0.0.1', 50, @fh)
      else
        @server = XMLRPC::Server.new(8080, '0.0.0.0', 50, @fh)
      end
      @port_opened = false
      open_port
      install_handlers(options[:test])
      # Mutex for 'busy'
      @mutex = Mutex.new
      # If we are busy with configuration
      @busy = false
      # Worker thread
      @thread = nil
    end

    def init_logger
      begin
        @fh = File.open(LOG_FILE_PATH, File::WRONLY | File::APPEND | File::CREAT | File::EXCL)
      rescue Errno::EEXIST
        @fh = File.open(LOG_FILE_PATH, File::WRONLY | File::APPEND)
      end
      @fh.flock(File::LOCK_EX)
      @fh.sync = true
      @fh.flock(File::LOCK_UN)
      @logger = Logger.new('/tmp/rpc_serv')
      @logger.level = Logger::INFO
      @logger.formatter = proc do |severity, datetime, _progname, msg|
        date = datetime.strftime("%Y-%m-%d %H:%M:%S")
        "[#{Socket.gethostname}] #{date} #{severity.rjust(6)}: #{msg}\n"
      end
    end


    # Install method handlers
    def install_handlers(test_handlers = nil)
      @logger.info "--- #{self.class}.#{__callee__}: installing handlers ---"
      # Add system.listMethods if in test mode
      @server.add_introspection if test_handlers

      # Configuration import routine
      @server.add_handler('sapha.import_config') do |yaml_string|
        @logger.info "RPC sapha.import_config ---"
        begin
          SapHA::Helpers.write_var_file('sapha_config.yaml', yaml_string)
          begin
                  @config = Psych.unsafe_load(yaml_string)
          rescue NoMethodError
                  @config = Psych.load(yaml_string)
          end
          @server.add_handler('sapha.config', @config)

          # for every component, expose sapha.config_{component}.apply method
          @config.config_sequence.each do |component|
            obj = @config.instance_variable_get(component[:var_name])
            @server.add_handler(component[:rpc_method]) do |role|
              @logger.info "RPC #{component[:rpc_method]} ---"
              @mutex.synchronize { @busy = true }
              @thread = Thread.new {
                @logger.info "Thread #{component[:rpc_method]}(#{role}): started"
                begin
                  obj.apply(role)
                rescue StandardError => e
                  @logger.error "Error executing thread #{component[:rpc_method]}(#{role}): #{e.message}"
                  @logger << e.backtrace
                end
                @logger.info "Thread #{component[:rpc_method]}(#{role}): finished"
                @mutex.synchronize { @busy = false }
              }
              'wait'
            end
          end
        rescue StandardError => e
          @fh.write("#{e.message}\n")
        end
        true
      end

      if test_handlers
        @server.add_handler('sapha.test_apply') do |role|
          @logger.info "RPC sapha.test_apply ---"
          @thread = Thread.new {
            @mutex.synchronize { @busy = true }
            sleep 30
            @mutex.synchronize { @busy = false }
          }
        'wait'
        end
      end

      @server.add_handler('sapha.ping') do
        @logger.info "RPC sapha.ping ---"
        true
      end

      @server.add_handler('sapha.shutdown') do
        @logger.info "RPC sapha.shutdown ---"
        shutdown
      end

      @server.add_handler('sapha.busy') do
        @mutex.synchronize do
          @logger.info "RPC sapha.busy? = #{@busy} ---"
          if @busy
            @logger.info "Thread state = #{@thread.inspect}"
          end
          @busy
        end
      end

    end

    def start
      @logger.info "--- #{self.class}.#{__callee__} ---"
      @server.serve
    end

    def shutdown
      @logger.info "--- #{self.class}.#{__callee__} ---"
      Thread.new {
        sleep 3
        # if we have any tasks still running, wait until they are finished
        @thread.join if @thread
        @server.shutdown
      }
      true
    end

    # force server shutdown
    def immediate_shutdown
      @logger.info "--- #{self.class}.#{__callee__} ---"
      @server.shutdown
    end

    # open the RPC Server port by manipulating the iptables directly
    def open_port
      @logger.info "--- #{self.class}.#{__callee__} ---"
      out, status = exec_outerr_status('/usr/bin/firewall-cmd', '--status')
      return if status.exitstatus != 0
      _out, rc  = exec_output_status('/usr/bin/firewall-cmd', '--add-port', '8080/tcp')
      @port_opened = true
      rc.exitstatus == 0
    end

    # close the RPC Server port by manipulating the iptables directly
    def close_port
      @logger.info "--- #{self.class}.#{__callee__} ---"
      out, status = exec_outerr_status('/usr/bin/firewall-cmd', '--status')
      return if status.exitstatus != 0
      _out, rc  = exec_output_status('/usr/bin/firewall-cmd', '--remove-port', '8080/tcp')
      puts "close_port: rc=#{rc}, out=#{out}"
      @port_opened = false
      rc.exitstatus == 0
    end

  end
end

if __FILE__ == $PROGRAM_NAME
  server = SapHA::RPCServer.new
  at_exit { server.shutdown }
  server.start
  server.close_port
  # TODO: what if we demonize the process, by returning 0 at a successful server start?
end
