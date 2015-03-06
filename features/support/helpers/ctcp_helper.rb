require 'net/irc'

class CtcpSpammer < Net::IRC::Client

  # PING and VERSION must be last so they are tried last below. It's
  # ugly, but the bot will exit once it has received the expected
  # replies for both of them, and since it shouldn't get anything from
  # any other command, we have no reliable way to ACK that a command
  # didn't work.
  KNOWN_CTCP_COMMANDS = [
    "FINGER", "SOURCE", "USERINFO", "CLIENTINFO", "TIME", "DATE",
    "ERRMSG", "PING", "VERSION"
  ]
  EXPECTED_CTCP_REPLIES = {
    "VERSION" => "Purple IRC",
    "PING" => /^\d+$/
  }
  CTCP_SPAM_DELAY = 2

  def initialize(host, port, opts)
    @spam_target = opts[:spam_target]
    @ctcp_replies = Set.new
    super(host, port, opts)
  end

  def spam(spam_target)
    post(NOTICE, spam_target, "Hi! I'm gonna test your CTCP capabilities now.")
    KNOWN_CTCP_COMMANDS.each do |cmd|
      sleep CTCP_SPAM_DELAY
      case cmd
      when "PING"
        cmd += " #{Time.now.to_i}"
      when "ACTION"
        cmd += " barfs on the floor."
      when "ERRMSG"
        cmd += " Pidgin should not respond to this."
      end
      post(PRIVMSG, spam_target, ctcp_encode(cmd))
    end
  end

  def on_rpl_welcome(m)
    super
    Thread.new { spam(@spam_target) }
  end

  def on_message(m)
    if m.ctcp?
      m.ctcps.each do |ctcp_ret|
        reply_type, _, reply_args = ctcp_ret.partition(" ")
        if EXPECTED_CTCP_REPLIES.has_key?(reply_type) && \
           EXPECTED_CTCP_REPLIES[reply_type].match(reply_args)
          @ctcp_replies << reply_type
        else
          raise "It looks like Pidgin responded to some CTCP command other " \
                "than PING or VERSION. We got the response:\n#{m.to_s}"
        end
      end
    end
    finish if Set.new(EXPECTED_CTCP_REPLIES.keys) == @ctcp_replies
  end
end
