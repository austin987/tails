#!/usr/bin/python
import sys
import jabberbot
import xmpp
import otr
from argparse import ArgumentParser

# Minimal implementation of the OTR callback store that only does what
# we absolutely need.
class OtrCallbackStore():

    def inject_message(self, opdata, accountname, protocol, recipient, message):
        mess = opdata["message"]
        mess.setTo(recipient)
        mess.setBody(message)
        opdata["send_raw_message_fn"](mess)

    def policy(self, opdata, context):
        return opdata["default_policy"]

    def create_privkey(self, **kwargs):
        raise Exception(
            "We should have loaded a key already! Most likely the 'name' " +
            "and/or 'protocol' fields are wrong in the key you provided.")

    def account_name(self, opdata, account, protocol):
        return account

    def protocol_name(self, opdata, protocol):
        return protocol

    def is_logged_in(self, **kwargs):
        return 1

    def max_message_size(self, **kwargs):
        return 0

    def display_otr_message(self, **kwargs):
        return 0

    # The rest we don't care at all about
    def write_fingerprints(self, **kwargs): pass
    def notify(self, **kwargs): pass
    def update_context_list(self, **kwargs): pass
    def new_fingerprint(self, **kwargs): pass
    def gone_secure(self, **kwargs): pass
    def gone_insecure(self, **kwargs): pass
    def still_secure(self, **kwargs): pass
    def log_message(self, **kwargs): pass

class OtrBot(jabberbot.JabberBot):

    PING_FREQUENCY = 60

    def __init__(self, account, password, otr_key_path, connect_server = None):
        self.__connect_server = connect_server
        self.__password = password
        super(OtrBot, self).__init__(account, password)
        self.__protocol = "xmpp"
        self.__otr_ustate = otr.otrl_userstate_create()
        otr.otrl_privkey_read(self.__otr_ustate, otr_key_path)
        self.__opdata = {
            "send_raw_message_fn": super(OtrBot, self).send_message,
            "default_policy": otr.OTRL_POLICY_MANUAL
            }
        self.__otr_callback_store = OtrCallbackStore()

    # Unfortunately Jabberbot's connect() is not very friendly to
    # overriding in subclasses so we have to re-implement it
    # completely (copy-paste mostly) in order to add support for using
    # an XMPP "Connect Server".
    def connect(self):
        if not self.conn:
            conn = xmpp.Client(self.jid.getDomain(), debug=[])
            if self.__connect_server:
                try:
                    conn_server, conn_port = self.__connect_server.split(":", 1)
                except ValueError:
                    conn_server = self.__connect_server
                    conn_port = 5222
                conres = conn.connect((conn_server, int(conn_port)))
            else:
                conres = conn.connect()
            if not conres:
                return None
            authres = conn.auth(self.jid.getNode(), self.__password, self.res)
            if not authres:
                return None
            self.conn = conn
            self.conn.sendInitPresence()
            self.roster = self.conn.Roster.getRoster()
            for (handler, callback) in self.handlers:
                self.conn.RegisterHandler(handler, callback)
        return self.conn

    def __otr_callbacks(self, more_data = None):
        opdata = self.__opdata.copy()
        if more_data:
            opdata.update(more_data)
        return (self.__otr_callback_store, opdata)

    def __get_otr_user_context(self, user):
        context, _ = otr.otrl_context_find(
            self.__otr_ustate, user, self.jid.getNode(), self.__protocol, 1)
        return context

    # Wrap OTR encryption around Jabberbot's most low-level method for
    # sending messages.
    def send_message(self, mess):
        body = str(mess.getBody())
        user = str(mess.getTo().getStripped())
        encrypted_body = otr.otrl_message_sending(
            self.__otr_ustate, self.__otr_callbacks(), self.jid.getNode(),
            self.__protocol, user, body, None)
        otr.otrl_message_fragment_and_send(
            self.__otr_callbacks({"message": mess}),
            self.__get_otr_user_context(user), encrypted_body,
            otr.OTRL_FRAGMENT_SEND_ALL)

    # Wrap OTR decryption around Jabberbot's callback mechanism.
    def callback_message(self, conn, mess):
        body = str(mess.getBody())
        user = str(mess.getFrom().getStripped())
        is_internal, decrypted_body, _ = otr.otrl_message_receiving(
            self.__otr_ustate, self.__otr_callbacks({"message": mess}),
            self.jid.getNode(), self.__protocol, user, body)
        context = self.__get_otr_user_context(user)
        if context.msgstate == otr.OTRL_MSGSTATE_FINISHED:
            otr.otrl_context_force_plaintext(context)
        if is_internal:
            return
        if mess.getType() == "groupchat":
            bot_prefix = self.jid.getNode() + ": "
            if decrypted_body.startswith(bot_prefix):
                decrypted_body = decrypted_body[len(bot_prefix):]
            else:
                return
        mess.setBody(decrypted_body)
        super(OtrBot, self).callback_message(conn, mess)

    # Override Jabberbot quitting on keep alive failure.
    def on_ping_timeout(self):
        self.__lastping = None

    @jabberbot.botcmd
    def ping(self, mess, args):
        """Why not just test it?"""
        return "pong"

    @jabberbot.botcmd
    def say(self, mess, args):
        """Unleash my inner parrot"""
        return args

    @jabberbot.botcmd
    def clear_say(self, mess, args):
        """Make me speak in the clear even if we're in an OTR chat"""
        self.__opdata["send_raw_message_fn"](mess.buildReply(args))
        return ""

    @jabberbot.botcmd
    def start_otr(self, mess, args):
        """Make me *initiate* (but not refresh) an OTR session"""
        if mess.getType() == "groupchat":
            return
        return "?OTRv2?"

    @jabberbot.botcmd
    def end_otr(self, mess, args):
        """Make me gracefully end the OTR session if there is one"""
        if mess.getType() == "groupchat":
            return
        user = str(mess.getFrom().getStripped())
        otr.otrl_message_disconnect(
            self.__otr_ustate, self.__otr_callbacks({"message": mess}),
            self.jid.getNode(), self.__protocol, user)
        return ""

if __name__ == '__main__':
    parser = ArgumentParser()
    parser.add_argument("account",
                        help = "the user account, given as user@domain")
    parser.add_argument("password",
                        help = "the user account's password")
    parser.add_argument("otr_key_path",
                        help = "the path to the account's OTR key file")
    parser.add_argument("-c", "--connect-server", metavar = 'ADDRESS',
                        help = "use a Connect Server, given as host[:port] " +
                        "(port defaults to 5222)")
    parser.add_argument("-j", "--auto-join", nargs = '+', metavar = 'ROOMS',
                        help = "auto-join multi-user chatrooms on start")
    args = parser.parse_args()
    otr_bot_opt_args = dict()
    if args.connect_server:
        otr_bot_opt_args["connect_server"] = args.connect_server
    otr_bot = OtrBot(args.account, args.password, args.otr_key_path,
                     **otr_bot_opt_args)
    if args.auto_join:
        for room in args.auto_join:
            otr_bot.join_room(room)
    otr_bot.serve_forever()
