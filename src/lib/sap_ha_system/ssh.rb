require 'yast'
require_relative 'shell_commands.rb'

module Yast
  class SSHException < StandardError
  end

  class SSHConnectionException < SSHException
  end

  class SSHAuthException < SSHException
  end

  class SSHPassException < SSHException
  end

  class SSHKeyException < SSHException
  end

  class SSH
    include Singleton
    include ShellCommands
    include Yast::Logger

    # Warning: can block for a while
    def can_ssh?(host)
      (exec_status_to "ssh root@#{host} -oStrictHostKeyChecking=no 'true'").exitstatus == 0
    end

    def can_ping?(host)
      (exec_status_to "ping -c 1 #{host}").exitstatus == 0
    end

    def check_ssh(host)
      # TODO: this file path should be relative
      stat = exec_status("/usr/bin/expect -f data/check_ssh.expect check #{host}")
      fortune_teller(binding)
    end

    def copy_keys_from(host, password, path)
      stat = exec_status("/usr/bin/expect -f data/check_ssh.expect copy #{host} #{password} #{path}")
      fortune_teller(binding)
    end

    # Copy SSH keys from the host to the local machine
    # @param password [String] SSH password or "''" for an empty string
    def copy_keys(host, overwrite = false, password = "''")
      # Create the .shh directory
      log.info "SSH::copy_keys(#{host}, overwrite=#{overwrite})"
      begin
        ssh_dir = File.join(Dir.home, '.ssh')
        Dir.mkdir(ssh_dir, 0700)
      rescue Errno::EEXIST
        log.debug "#{ssh_dir} already exists"
      end
      # Create a temporary directory for the keys
      tmpdir = Dir.mktmpdir('sap-ha-keys-')
      log.debug "Created tmp directory #{tmpdir}"

      log.info "Retrieving SSH keys from node #{host}"
      unless can_ssh? host
        if !can_ping? host
          log.warn "Could not ping host #{host}."
          raise SSHConnectionException, "Unable to establish a connection to the host #{host}."
        end
        raise SSHAuthException, "Could not connect to host #{host}: check authentication"
      end
      cmdline = "scp -oStrictHostKeyChecking=no root@#{host}:'/root/.ssh/id_*' #{tmpdir}"
      log.error "CMD #{cmdline}"
      status, err = exec_status_stderr cmdline
      unless status == 0
        raise SSHKeyException, "Could not copy the keys from host #{host}: #{err}"
      end
      keys_copied = 0
      Dir.glob(File.join(tmpdir, "id_{rsa,dsa,ecdsa,ed25519}{.pub}")) do |source_path|
        basename = File.basename(source_path)
        puts "Copied key #{basename}"
        target_path = File.join(ssh_dir, basename)
        if File.exist?(target_path) && !overwrite
          log.info "Key #{basename} was skipped, as #{target_path} already exists."
          next
        end
        ::FileUtils.mv source_path, target_path
        keys_copied += 1
        source_pub_key = source_path + '.pub'
        target_pub_key = target_path + '.pub'
        if File.exist? source_pub_key
          ::FileUtils.mv source_pub_key, target_pub_key, force: true
          authorize_key target_pub_key
        else
          log.err "Public key #{source_pub_key} wasn't found."
        end
        puts "Copied #{keys_copied} keys."
        ::FileUtils.rm_rf tmpdir
      end
      # make sure the target host has its own keys in authorized_keys
      if exec_status_to("ssh root@$#{host} ha-cluster-init ssh_remote").to_i != 0
        log.error "Executing ha-cluster-init ssh_remote on host #{host} failed"
      end
    end

    private

    def authorize_key(path)
      auth_keys_path = File.join(Dir.home, '.ssh', 'authorized_keys')
      if exec_status("grep -q -s #{path} #{auth_keys_path}").to_i != 0
        key = File.read(path)
        File.open(auth_keys_path, mode: 'a') do |fh|
          fh << "\n"
          fh << key
        end
      end
      true
    end

    def fortune_teller(binding)
      stat = binding.local_variable_get('stat')
      host = binding.local_variable_get('host')
      case stat.exitstatus
      when 0
        true
      when 5 # timeout
        raise SSHException, "Could not connect to #{host}: Connection time out"
      when 10
        raise SSHAuthException, "Could not connect to #{host}: Password is required"
      when 11
        raise SSHPassException, "Could not connect to #{host}: Password is incorrect"
      when 51
        raise SSHException, "Could not connect to #{host}: Remote host reset the connection"
      when 52
        raise SSHException, "Could not connect to #{host}: Cannot resolve the host"
      when 53
        raise SSHException, "Could not connect to #{host}: No route to host"
      when 54
        raise SSHException, "Could not connect to #{host}: Connection refused"
      when 55
        raise SSHException, "Could not connect to #{host}: Unknown connection error."
      else
        log.error "Could not connect to #{host}: check_ssh returned rc=#{stat.exitstatus}"
        raise SSHException, "Could not connect to #{host} (rc=#{stat.exitstatus})."
      end
      true
    end
  end
end
