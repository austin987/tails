require 'net/irc'
require 'timeout'

class CtcpChecker < Net::IRC::Client

  CTCP_SPAM_DELAY = 5

  # `spam_target`: the nickname of the IRC user to CTCP spam.
  # `ctcp_cmds`: the Array of CTCP commands to send.
  # `expected_ctcp_replies`: Hash where the keys are the exact set of replies
  # we expect, and their values a regex the reply data must match.
  def initialize(host, port, spam_target, ctcp_cmds, expected_ctcp_replies)
    @spam_target = spam_target
    @ctcp_cmds =  ctcp_cmds
    @expected_ctcp_replies = expected_ctcp_replies
    nickname = self.class.random_irc_nickname
    opts = {
      :nick => nickname,
      :user => nickname,
      :real => nickname,
    }
    opts[:logger] = Logger.new("/dev/null") if !$config["DEBUG"]
    super(host, port, opts)
  end

  # Makes sure that only the expected CTCP replies are received.
  def verify_ctcp_responses
    @sent_ctcp_cmds = Set.new
    @received_ctcp_replies = Set.new

    # Give 60 seconds for connecting to the server and other overhead
    # beyond the expected time to spam all CTCP commands.
    expected_ctcp_spam_time = @ctcp_cmds.length * CTCP_SPAM_DELAY
    timeout = expected_ctcp_spam_time + 60

    begin
      Timeout::timeout(timeout) do
        start
      end
    rescue Timeout::Error
      # Do nothing as we'll check for errors below.
    ensure
      finish
    end

    ctcp_cmds_not_sent = @ctcp_cmds - @sent_ctcp_cmds.to_a
    expected_ctcp_replies_not_received =
      @expected_ctcp_replies.keys - @received_ctcp_replies.to_a
    if !ctcp_cmds_not_sent.empty? || !expected_ctcp_replies_not_received.empty?
      raise "Failed to spam all CTCP commands and receive the expected " +
            "replies within #{timeout} seconds.\n" +
            (ctcp_cmds_not_sent.empty? ? "" :
            "CTCP commands not sent: #{ctcp_cmds_not_sent}\n") +
            (expected_ctcp_replies_not_received.empty? ? "" :
            "Expected CTCP replies not received: " +
            expected_ctcp_replies_not_received.to_s)
    end

  end

  # Generate a random IRC nickname, in this case an alpha-numeric
  # string with length 10 to 15. To make it legal, the first character
  # is forced to be alpha.
  def self.random_irc_nickname
    alpha_set = ('A'..'Z').to_a + ('a'..'z').to_a
    alnum_set = alpha_set + (0..9).to_a.map { |n| n.to_s }
    length = (10..15).to_a.sample
    nickname = alpha_set.sample
    nickname += (0..length-2).map { |n| alnum_set.sample }.join
    return nickname
  end

  def spam(spam_target)
    post(NOTICE, spam_target, "Hi! I'm gonna test your CTCP capabilities now.")
    @ctcp_cmds.each do |cmd|
      sleep CTCP_SPAM_DELAY
      full_cmd = cmd
      case cmd
      when "PING"
        full_cmd += " #{Time.now.to_i}"
      when "ACTION"
        full_cmd += " barfs on the floor."
      when "ERRMSG"
        full_cmd += " Pidgin should not respond to this."
      end
      post(PRIVMSG, spam_target, ctcp_encode(full_cmd))
      @sent_ctcp_cmds << cmd
    end
  end

  def on_rpl_welcome(m)
    super
    Thread.new { spam(@spam_target) }
  end

  def on_message(m)
    if m.command == ERR_NICKNAMEINUSE
      finish
      new_nick = self.class.random_irc_nickname
      @opts.marshal_load({
                           :nick => new_nick,
                           :user => new_nick,
                           :real => new_nick,
                         })
      start
      return
    end

    if m.ctcp? and /^:#{@spam_target}!/.match(m)
      m.ctcps.each do |ctcp_reply|
        reply_type, _, reply_data = ctcp_reply.partition(" ")
        if @expected_ctcp_replies.has_key?(reply_type)
          if @expected_ctcp_replies[reply_type].match(reply_data)
            @received_ctcp_replies << reply_type
          else
            raise "Received expected CTCP reply '#{reply_type}' but with " +
                  "unexpected data '#{reply_data}' "
          end
        else
          raise "Received unexpected CTCP reply '#{reply_type}' with " +
                "data '#{reply_data}'"
        end
      end
    end
    if Set.new(@ctcp_cmds) == @sent_ctcp_cmds && \
       Set.new(@expected_ctcp_replies.keys) == @received_ctcp_replies
      finish
    end
  end
end
