require 'tempfile'

class ChatBot

  def initialize(account, password, otr_key, rooms = nil)
    @account = account
    @password = password
    @otr_key = otr_key
    @rooms = rooms
    @pid = nil
    @otr_key_file = nil
  end

  def start
    @otr_key_file = Tempfile.new("otr_key.", $config["TMP_DIR"])
    @otr_key_file << @otr_key
    @otr_key_file.close

    cmd = [
           "#{GIT_DIR}/features/scripts/otr-bot.py",
           @account,
           @password,
           @otr_key_file.path
          ]
    cmd += @rooms if @rooms

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
