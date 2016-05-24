require 'open3'
require 'timeout'

module ShellCommands
  def exec_stdout(command)
    Open3.popen3(command) do |_, stdout, _, _|
        stdout
    end
  end

  # @return [Process::Status]
  def exec_status(command)
    # TODO: remove
    puts "exec_status: #{command}"
    Open3.popen3(command) { |_, _, _, wait_thr| wait_thr.value }
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

  def exec_status_stderr(command)
    Open3.popen3(command) { |_, _, stderr, wait_thr| [wait_thr.value, stderr.read] }
  end

  def exec_stderr(command)
    raise 'not implemented'
  end
end