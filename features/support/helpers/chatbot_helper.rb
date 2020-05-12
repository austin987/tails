require 'tempfile'

class ChatBot
  def initialize(account, password, otr_key, **opts)
    @account = account
    @password = password
    @otr_key = otr_key
    @opts = opts
    @pid = nil
    @otr_key_file = nil
  end

  def start
    @otr_key_file = Tempfile.new('otr_key.', $config['TMPDIR'])
    @otr_key_file << @otr_key
    @otr_key_file.close

    cmd_helper(['/usr/bin/convertkey', @otr_key_file.path])
    cmd_helper(['mv', "#{@otr_key_file.path}3", @otr_key_file.path])

    cmd = [
      "#{GIT_DIR}/features/scripts/otr-bot.py",
      @account,
      @password,
      @otr_key_file.path,
    ]
    if @opts[:connect_server]
      cmd += ['--connect-server', @opts[:connect_server]]
    end
    cmd += ['--auto-join'] + @opts[:auto_join] if @opts[:auto_join]
    cmd += ['--log-file', DEBUG_LOG_PSEUDO_FIFO]

    job = IO.popen(cmd)
    @pid = job.pid
  end

  def stop
    @otr_key_file.delete
    begin
      Process.kill('TERM', @pid)
      Process.wait(@pid)
    rescue StandardError
      # noop
    end
  end

  def active?
    begin
      ret = Process.kill(0, @pid)
    rescue Errno::ESRCH => e
      return false if e.message == 'No such process'

      raise e
    end
    assert_equal(1, ret, "This shouldn't happen")
    true
  end
end
