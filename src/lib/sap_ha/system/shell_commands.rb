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
# Summary: SUSE High Availability Setup for SAP Products: Shell commands proxy mix-in
# Authors: Ilya Manyugin <ilya.manyugin@suse.com>

require 'open3'
require 'timeout'

module SapHA
  module System
    # Shell commands proxy mix-in
    module ShellCommands

      class FakeProcessStatus
        attr_reader :exitstatus
        def initialize(rc)
          @exitstatus = rc
        end
      end

      def exec_stdout(command)
        Open3.popen3(command) do |_, stdout, _, _|
          stdout
        end
      end

      # @return [Process::Status]
      def exec_status(command)
        Open3.popen3(command) { |_, _, _, wait_thr| wait_thr.value }
      end

      def exec_status_l(*params)
        Open3.popen3(*params) { |_, _, _, wait_thr| wait_thr.value }
      end

      def exec_status_lo(*params)
        # TODO: replace with Open3.capture2(params)
        # puts "exec_status: #{params}"
        Open3.popen3(*params) { |_, out, _, wait_thr| [wait_thr.value, out.read] }
      end

      # @return stdout_and_stderr, status
      def exec_outerr_status(*params)
        Open3.capture2e(*params)
      rescue SystemCallError => e
        return ["System call failed with ERRNO=#{e.errno}: #{e.message}", FakeProcessStatus.new(1)]
      end

      # @return stdout_and_stderr, status
      def su_exec_outerr_status(user_name, *params)
        Open3.capture2e('su', '-l', user_name, params.join(' '))
      rescue SystemCallError => e
        return ["System call failed with ERRNO=#{e.errno}: #{e.message}", FakeProcessStatus.new(1)]
      end

      def exec_status_to(command, timeout = 5)
        Open3.popen3(command) do |_, _, _, wait_thr|
          begin
            Timeout.timeout(timeout) { return wait_thr.value }
          rescue Timeout::Error
            Process.kill("KILL", wait_thr.pid)
          end
        end
        -1
      end

      def pipeline(cmd1, cmd2)
        Open3.pipeline_r(cmd1, cmd2, {err: "/dev/null"}) { |out, wait_thr| out.read }
      end

      def exec_status_stderr(command)
        Open3.popen3(command) { |_, _, stderr, wait_thr| [wait_thr.value, stderr.read] }
      end

      def exec_stderr(_command)
        # TODO
        raise 'not implemented'
      end
    end
  end
end
