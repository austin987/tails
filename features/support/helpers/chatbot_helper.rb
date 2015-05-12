require 'tempfile'

class ChatBot

  def initialize(account, password, otr_key, opts = Hash.new)
    @account = account
    @password = password
    @otr_key = otr_key
    @opts = opts
    @pid = nil
    @otr_key_file = nil
  end

  def start
    @otr_key_file = Tempfile.new("otr_key.", $config["TMPDIR"])
    @otr_key_file << @otr_key
    @otr_key_file.close

    # XXX: Once #9066 we should remove the convertkey.py script from
    # our tree and use the one bundled in python-potr instead.
    cmd_helper("#{GIT_DIR}/features/scripts/convertkey.py #{@otr_key_file.path}")
    cmd_helper("mv #{@otr_key_file.path}3 #{@otr_key_file.path}")

    cmd = [
           "#{GIT_DIR}/features/scripts/otr-bot.py",
           @account,
           @password,
           @otr_key_file.path
          ]
    cmd += ["--connect-server", @opts["connect_server"]] if @opts["connect_server"]
    cmd += ["--auto-join"] + @opts["auto_join"] if @opts["auto_join"]

    job = IO.popen(cmd)
    @pid = job.pid
  end

  def stop
    @otr_key_file.delete
    begin
      Process.kill("TERM", @pid)
    rescue
      # noop
    end
  end

  def active?
    begin
      ret = Process.kill(0, @pid)
    rescue Errno::ESRCH => e
      if e.message == "No such process"
        return false
      else
        raise e
      end
    end
    assert_equal(1, ret, "This shouldn't happen")
    return true
  end

end
