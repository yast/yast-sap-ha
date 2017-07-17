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
# Summary: SUSE High Availability Setup for SAP Products: HANA configuration
# Authors: Ilya Manyugin <ilya.manyugin@suse.com>

require 'yast'
require 'sap_ha/exceptions'
require 'sap_ha/helpers'
require 'sap_ha/node_logger'
require 'sap_ha/system/ssh'
require_relative 'shell_commands'

module SapHA
  module System
    # HANA configuration routines
    class HanaClass
      include Singleton
      include ShellCommands
      include SapHA::Exceptions
      include Yast::Logger

      HANA_GLOBAL_INI = "/hana/shared/%s/global/hdb/custom/config/global.ini".freeze

      # Check if HBD daemon is running
      # @param system_id [String] SAP SID of the HANA instance
      # @param instance_number [String] HANA instance number
      def check_hdb_daemon_running(system_id, instance_number)
        log.info "--- called #{self.class}.#{__callee__}(#{system_id}, #{instance_number}) ---"
        procname = "hdb.sap#{system_id.upcase}_HDB#{instance_number}"
        _out, status = exec_outerr_status('pidof', procname)
        status.exitstatus == 0
      end

      # Make initial HANA backup for the system replication
      # @param system_id [String] SAP SID of the HANA instance
      # @param user_name [String] Secure user storage username to perform the backup on behalf of
      # @param file_name [String] HANA backup file
      # @param instance_number [String] HANA instance number
      def make_backup(system_id, secstore_user, file_name, _instance_number)
        log.info "--- called #{self.class}.#{__callee__}(#{system_id}, #{secstore_user},"\
          " #{file_name}, #{_instance_number}) ---"
        user_name = "#{system_id.downcase}adm"
        # do backup differently for HANA 2.0
        version = version(system_id)
        if SapHA::Helpers.version_comparison('2.00.010', version, '>=')
          command = 'hdbsql', '-U', secstore_user, '-d', 'SYSTEMDB',
            "\"BACKUP DATA FOR FULL SYSTEM USING FILE ('#{file_name}')\""
        else
          command = 'hdbsql', '-U', secstore_user, "\"BACKUP DATA USING FILE ('#{file_name}')\""
        end
        out, status = su_exec_outerr_status(user_name, *command)
        NodeLogger.log_status(
          status.exitstatus == 0,
          "Created an initial HANA backup for user #{secstore_user} into file #{file_name}",
          "Could not perform an initial HANA backup for user #{secstore_user} into file #{file_name}",
          out,
          true
        )
      end

      # Start HANA by issuing the `HDB start` command as `<sid>adm` user
      # @param system_id [String] SAP SID of the HANA instance
      def hdb_start(system_id)
        log.info "--- called #{self.class}.#{__callee__}(#{system_id}) ---"
        user_name = "#{system_id.downcase}adm"
        command = ['HDB', 'start']
        out, status = su_exec_outerr_status(user_name, *command)
        s = NodeLogger.log_status(status.exitstatus == 0,
          "Started HANA #{system_id}",
          "Could not start HANA #{system_id}, will retry.",
          out
        )
        return true if s
        out, status = su_exec_outerr_status(user_name, *command)
        NodeLogger.log_status(status.exitstatus == 0,
          "Started HANA #{system_id}",
          "Could not start HANA #{system_id}, bailing out.",
          out
        )
      end

      # Get the HANA version as a string
      # @param system_id [String] SAP SID of the HANA instance
      # @return [String, nil] version string or nil on failure
      def version(system_id)
        log.info "--- called #{self.class}.#{__callee__}(#{system_id}) ---"
        user_name = "#{system_id.downcase}adm"
        command = ['HDB', 'version']
        out, status = su_exec_outerr_status(user_name, *command)
        unless status.exitstatus == 0
          NodeLogger.error("Could not retrieve HANA version, assuming legacy version")
          NodeLogger.output(out)
          return nil
        end
        match = /version:\s+(\d+.\d+.\d+)/.match(out)
        return nil if match.nil?
        match.captures.first
      end

      # Start HANA by issuing the `HDB start` command as `<sid>adm` user
      # @param system_id [String] SAP SID of the HANA instance
      def hdb_stop(system_id)
        log.info "--- called #{self.class}.#{__callee__}(#{system_id}) ---"
        user_name = "#{system_id.downcase}adm"
        command = ['HDB', 'stop']
        out, status = su_exec_outerr_status(user_name, *command)
        s = NodeLogger.log_status(status.exitstatus == 0,
          "Stopped HANA #{system_id}",
          "Could not stop HANA #{system_id}, will retry.",
          out
        )
        return true if s
        out, status = su_exec_outerr_status(user_name, *command)
        NodeLogger.log_status(status.exitstatus == 0,
          "Stopped HANA #{system_id}",
          "Could not stop HANA #{system_id}, bailing out.",
          out
        )
      end

      # Enable System Replication on the primary HANA system
      # @param system_id [String] HANA System ID
      # @param site_name [String] HANA site name of the primary instance
      def enable_primary(system_id, site_name)
        log.info "--- called #{self.class}.#{__callee__}(#{system_id}, #{site_name}) ---"
        user_name = "#{system_id.downcase}adm"
        command = ['hdbnsutil', '-sr_enable', "--name=#{site_name}"]
        out, status = su_exec_outerr_status(user_name, *command)
        NodeLogger.log_status(status.exitstatus == 0,
          "Enabled HANA (#{system_id}) System Replication on the primary site #{site_name}",
          "Could not enable HANA (#{system_id}) System Replication on the primary site #{site_name}",
          out
        )
      end

      # Enable System Replication on the secondary HANA system
      # @param system_id [String] HANA System ID
      # @param site_name [String] HANA site name of the secondary instance
      # @param host_name_primary [String] host name of the primary node
      # @param instance [String] instance number of the primary
      # @param rmode [String] replication mode
      # @param omode [String] operation mode
      def enable_secondary(system_id, site_name, host_name_primary, instance, rmode, omode)
        log.info "--- called #{self.class}.#{__callee__}(#{system_id}, #{site_name},"\
          " #{host_name_primary}, #{instance}, #{rmode}, #{omode}) ---"
        user_name = "#{system_id.downcase}adm"
        version = version(system_id)
        # Select an appropriate command-line switch for replication mode
        # Assume legacy `mode` by default (pre-SPS12)
        rmode_string = if SapHA::Helpers.version_comparison('1.00.120', version, '>=')
                         "--replicationMode=#{rmode}"
                       else
                         "--mode=#{rmode}"
                       end
        omode_string = if SapHA::Helpers.version_comparison('1.00.110', version, '>=')
                         "--operationMode=#{omode}"
                       else
                         nil
                       end
        command = ['hdbnsutil', '-sr_register', "--remoteHost=#{host_name_primary}",
                   "--remoteInstance=#{instance}", rmode_string, omode_string,
                   "--name=#{site_name}"].reject(&:nil?)
        out, status = su_exec_outerr_status(user_name, *command)
        NodeLogger.log_status(status.exitstatus == 0,
          "Enabled HANA (#{system_id}) System Replication on the secondary host #{site_name}",
          "Could not enable HANA (#{system_id}) System Replication on the secondary host",
          out
        )
      end

      # List the keys out of the HANA secure user store
      # @param system_id [String] HANA System ID
      def check_secure_store(system_id)
        log.info "--- called #{self.class}.#{__callee__}(#{system_id}) ---"
        regex = /^KEY (\w+)$/
        user_name = "#{system_id.downcase}adm"
        command = ['hdbuserstore', 'list']
        out, status = su_exec_outerr_status(user_name, *command)
        unless status.exitstatus == 0
          log.error "Could not get the list of keys in the HANA secure user store"\
            " (status=#{status.exitstatus}): #{out}"
          return []
        end
        out.scan(regex).flatten
      end

      def set_secute_store(system_id, key_name, env, user_name, password)
        log.info "--- called #{self.class}.#{__callee__}(#{system_id}, #{key_name}, ...) ---"
        su_name = "#{system_id.downcase}adm"
        command = ['hdbuserstore', 'set', key_name, env, user_name, password]
        out, status = su_exec_outerr_status(su_name, *command)
        NodeLogger.log_status(status.exitstatus == 0,
          "Successfully set key #{key_name} in the secure user store on system #{system_id}",
          "Could not set key #{key_name} in the secure user store on system #{system_id}",
          out
        )
      end

      # Write the takeover hook script
      # @param system_id [String] HANA System ID (production)
      # @param hook_script [String] HANA takeover hook script
      def write_sr_hook(system_id, hook_script)
        log.info "--- called #{self.class}.#{__callee__}(#{system_id}, #{hook_script.inspect}) ---"
        hook_dir = "/hana/shared/#{system_id.upcase}/srHook"
        begin
          Dir.mkdir(hook_dir) unless Dir.exist?(hook_dir)
        rescue StandardError => e
          log.error "Error creating directory #{hook_dir}: #{e.message}"
          NodeLogger.error("Could not create directory #{hook_dir}")
          NodeLogger.output(e.message)
          return false
        end
        begin
          hook_path = File.join(hook_dir, 'srTakeover.py')
          File.open(hook_path, 'wb') do |fh|
            fh.write(hook_script)
          end
        rescue StandardError => e
          log.error "Error writing file #{hook_path}: #{e.message}"
          NodeLogger.error("Could not write the system replication hook script to #{hook_path}")
          NodeLogger.output(e.message)
          return false
        end
        NodeLogger.info("Wrote system replication hook script to #{hook_path}")
        true
      end

      # Implement adjustments to the production system, so that a non-production
      # HANA could be run along it
      # @param system_id [String] HANA System ID (production)
      # @param options [Hash] production system options
      def adjust_production_system(system_id, options = {})
        log.info "--- called #{self.class}.#{__callee__}(#{system_id}, #{options.inspect}) ---"
        begin
          require 'cfa/augeas_parser'
          require 'cfa/base_model'
          require 'cfa/matcher'
        rescue LoadError => e
          log.error "Error loading the CFA parser: #{e.message}"
          NodeLogger.error "Could not adjust global.ini for the production system:"
          NodeLogger.output e.message
          return false
        end
        # Change the global.ini
        global_ini_path = HANA_GLOBAL_INI % system_id.upcase
        unless File.exist?(global_ini_path)
          NodeLogger.error "Could not adjust global.ini for the production system:"
          NodeLogger.output "File #{global_ini_path} does not exist"
          return false
        end
        begin
          parser = CFA::AugeasParser.new('sapini.lns')
          bm = CFA::BaseModel.new(parser, global_ini_path)
          bm.load
          bm.generic_set('ha_dr_provider_srTakeover/provider', 'srTakeover')
          bm.generic_set('ha_dr_provider_srTakeover/path',
            "/hana/shared/#{system_id.upcase}/srHook/srTakeover.py")
          bm.generic_set('ha_dr_provider_srTakeover/execution_order', options[:execution_order])
          bm.generic_set('memorymanager/global_allocation_limit', options[:global_alloc_limit])
          bm.generic_set('system_replication/preload_column_tables',
            options[:preload_column_tables])
          bm.save
        rescue StandardError => e
          NodeLogger.error "Could not adjust global.ini for the production system:"
          NodeLogger.output e.message
          return false
        else
          NodeLogger.info "Successfully adjusted global.ini for the production system #{system_id}"
          true
        end
      end

      # Implement adjustments to the non-production system
      # @param system_id [String] HANA System ID (production)
      # @param options [Hash] production system options
      def adjust_non_production_system(system_id, options = {})
        log.info "--- called #{self.class}.#{__callee__}(#{system_id}, #{options.inspect}) ---"
        begin
          require 'cfa/augeas_parser'
          require 'cfa/base_model'
          require 'cfa/matcher'
        rescue LoadError => e
          log.error "Error loading the CFA parser: #{e.message}"
          NodeLogger.error "Could not adjust global.ini for the non-production system:"
          NodeLogger.output e.message
          return false
        end
        # Change the global.ini
        global_ini_path = HANA_GLOBAL_INI % system_id.upcase
        unless File.exist?(global_ini_path)
          NodeLogger.error "Could not adjust global.ini for the non-production system:"
          NodeLogger.output "File #{global_ini_path} does not exist"
          return false
        end
        begin
          parser = CFA::AugeasParser.new('sapini.lns')
          bm = CFA::BaseModel.new(parser, global_ini_path)
          bm.load
          bm.generic_set('memorymanager/global_allocation_limit', options[:global_alloc_limit])
          bm.save
        rescue StandardError => e
          NodeLogger.error "Could not adjust global.ini for the non-production system:"
          NodeLogger.output e.message
          return false
        else
          NodeLogger.info "Successfully adjusted global.ini"\
          " for the non-production system #{system_id}"
          true
        end
      end

      # Create a user for monitoring the non-production HANA on the secondary node
      # @param system_id [String] HANA System ID (production)
      # @param options [Hash] production system options
      def create_monitoring_user(system_id, instance_number)
        log.info "--- called #{self.class}.#{__callee__}(#{system_id}, #{instance_number}) ---"
        user_name = "#{system_id.downcase}adm"
        command_prefix = ['hdbsql', '-u', 'system', '-i', instance_number.to_s,
          '-n', 'localhost:31013']
        command = command_prefix.clone << '"CREATE USER SC PASSWORD L1nuxLab"'
        out, status = su_exec_outerr_status(user_name, *command)
        NodeLogger.log_status(status.exitstatus == 0,
          "Created user SC for HANA instance #{system_id}/#{instance_number}",
          "Could not create user SC for HANA instance #{system_id}/#{instance_number}",
          out
        )
        command = command_prefix.clone << '"GRANT MONITORING TO SC"'
        out, status = su_exec_outerr_status(user_name, *command)
        NodeLogger.log_status(status.exitstatus == 0,
          "Granted MONITORING to user SC on HANA instance #{system_id}/#{instance_number}",
          "Could not grant MONITORING to user SC on HANA instance #{system_id}/#{instance_number}",
          out
        )
        command = command_prefix.clone << '"ALTER USER SC DISABLE PASSWORD LIFETIME"'
        out, status = su_exec_outerr_status(user_name, *command)
        NodeLogger.log_status(status.exitstatus == 0,
          "Disabled password lifetime for user SC on HANA instance #{system_id}/#{instance_number}",
          "Could not disable password lifetime for user"\
          " SC on HANA instance #{system_id}/#{instance_number}",
          out
        )
        command_prefix = ['hdbsql', '-u', 'sc', '-i', instance_number.to_s, '-n', 'localhost:31013']
        command = command_prefix << '"SELECT * FROM DUMMY"'
        out, status = su_exec_outerr_status(user_name, *command)
      end

      # Execute an HDBSQL command
      # @param system_id [String] HANA System ID
      # @param user_name [String] HANA user name
      # @param instance number [String] HANA instance number
      # @param password [String] HANA password
      # @param environment [String] HANA host:port specification (can be empty)
      # @param statement [String] SQL statement
      def hdbsql_command(system_id, user_name, instance_number, password, environment, statement)
        log.info "--- called #{self.class}.#{__callee__}(#{system_id}, #{user_name},"\
          " #{instance_number}, password, #{environment}, #{statement}) ---"
        su_name = "#{system_id.downcase}adm"
        cmd = 'hdbsql', '-x', '-u', user_name, '-i', instance_number.to_s, '-p', password
        cmd << '-n' << environment unless environment.empty?
        cmd << '"' << statement.gsub('"', "\\\"") << '"'
        out, status = su_exec_outerr_status_mask_password([7], su_name, *cmd)
        if status.exitstatus != 0
          # remove the password from the command line
          pass_index = (cmd.index('-p') || 0) + 1
          cmd[pass_index] = "*" * cmd[pass_index].length
          NodeLogger.error "Error executing command #{cmd.join(" ")}"
          NodeLogger.output out
          return
        end
        out
      end

      # Copy PKI SSFS key files from primary to secondary
      # @param system_id [String] HANA System ID
      # @param user_name [String] HANA user name 
      def copy_ssfs_keys(system_id, secondary_host_name, password)
        log.info "--- called #{self.class}.#{__callee__}(#{system_id}, #{secondary_host_name} ---"
        # TODO: check the paths, ideally taking them from the ENV
        # according to the docs, they should be:
        #   $DIR_INSTANCE/../global/security/rsecssfs/data/SSFS_<SID>.DAT
        #   $DIR_INSTANCE/../global/security/rsecssfs/key/SSFS_<SID>.KEY
        # but those paths are invalid
        file_list = [
          "/usr/sap/#{system_id}/SYS/global/security/rsecssfs/data/SSFS_#{system_id}.DAT",
          "/usr/sap/#{system_id}/SYS/global/security/rsecssfs/key/SSFS_#{system_id}.KEY"
        ]
        file_list.each do |file_path|
          begin
            SapHA::System::SSH.instance.copy_file_to(file_path, secondary_host_name, password)
          rescue SSHException => e
            NodeLogger.error "Could not copy HANA PKI SSFS file #{file_path}"
            NodeLogger.output e.message
          else
            NodeLogger.info "Copied HANA PKI SSFS file #{file_path} to node #{secondary_host_name}"
          end          
        end
      end
    end # HanaClass
    Hana = HanaClass.instance
  end # namespace System
end # namespace SapHA