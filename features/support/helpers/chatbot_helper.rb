require 'tempfile'

class ChatBot

  def initialize(account, password, otr_key)
    @account = account
    @password = password
    @otr_key = otr_key
    @pid = nil
    @otr_key_file = nil
  end

  def start
    @otr_key_file = Tempfile.new("otr_key.", $config["TMP_DIR"])
    @otr_key_file << @otr_key
    @otr_key_file.close

    job = IO.popen([
                    "#{GIT_DIR}/features/scripts/otr-bot.py",
                    @account,
                    @password,
                    @otr_key_file.path
                   ])
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
