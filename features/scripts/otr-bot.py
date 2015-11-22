#!/usr/bin/python
import sys
import jabberbot
import xmpp
import potr
from argparse import ArgumentParser

class OtrContext(potr.context.Context):

    def __init__(self, account, peer):
        super(OtrContext, self).__init__(account, peer)

    def getPolicy(self, key):
        return True

    def inject(self, msg, appdata = None):
        mess = appdata["base_reply"]
        mess.setBody(msg)
        appdata["send_raw_message_fn"](mess)


class BotAccount(potr.context.Account):

    def __init__(self, jid, keyFilePath):
        protocol = 'xmpp'
        max_message_size = 10*1024
        super(BotAccount, self).__init__(jid, protocol, max_message_size)
        self.keyFilePath = keyFilePath

    def loadPrivkey(self):
        with open(self.keyFilePath, 'rb') as keyFile:
            return potr.crypt.PK.parsePrivateKey(keyFile.read())[0]


class OtrContextManager:

    def __init__(self, jid, keyFilePath):
        self.account = BotAccount(jid, keyFilePath)
        self.contexts = {}

    def start_context(self, other):
        if not other in self.contexts:
            self.contexts[other] = OtrContext(self.account, other)
        return self.contexts[other]

    def get_context_for_user(self, other):
        return self.start_context(other)


class OtrBot(jabberbot.JabberBot):

    PING_FREQUENCY = 60

    def __init__(self, account, password, otr_key_path, connect_server = None):
        self.__connect_server = connect_server
        self.__password = password
        super(OtrBot, self).__init__(account, password)
        self.__otr_manager = OtrContextManager(account, otr_key_path)
        self.send_raw_message_fn = super(OtrBot, self).send_message
        self.__default_otr_appdata = {
            "send_raw_message_fn": self.send_raw_message_fn
            }

    def __otr_appdata_for_mess(self, mess):
        appdata = self.__default_otr_appdata.copy()
        appdata["base_reply"] = mess
        return appdata

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

    # Wrap OTR encryption around Jabberbot's most low-level method for
    # sending messages.
    def send_message(self, mess):
        body = str(mess.getBody())
        user = str(mess.getTo().getStripped())
        otrctx = self.__otr_manager.get_context_for_user(user)
        if otrctx.state == potr.context.STATE_ENCRYPTED:
            otrctx.sendMessage(potr.context.FRAGMENT_SEND_ALL, body,
                               appdata = self.__otr_appdata_for_mess(mess))
        else:
            self.send_raw_message_fn(mess)

    # Wrap OTR decryption around Jabberbot's callback mechanism.
    def callback_message(self, conn, mess):
        body = str(mess.getBody())
        user = str(mess.getFrom().getStripped())
        otrctx = self.__otr_manager.get_context_for_user(user)
        if mess.getType() == "chat":
            try:
                appdata = self.__otr_appdata_for_mess(mess.buildReply())
                decrypted_body, tlvs = otrctx.receiveMessage(body,
                                                             appdata = appdata)
                otrctx.processTLVs(tlvs)
            except potr.context.NotEncryptedError:
                otrctx.authStartV2(appdata = appdata)
                return
            except (potr.context.UnencryptedMessage, potr.context.NotOTRMessage):
                decrypted_body = body
        else:
            decrypted_body = body
        if decrypted_body == None:
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
        self.send_raw_message_fn(mess.buildReply(args))
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
        self.__otr_manager.get_context_for_user(user).disconnect(appdata =
            self.__otr_appdata_for_mess(mess.buildReply()))
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
