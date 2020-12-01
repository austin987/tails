#!/usr/bin/python3
import slixmpp
import sys
import potr
import logging
from argparse import ArgumentParser

class OtrContext(potr.context.Context):

    def __init__(self, account, peer):
        super(OtrContext, self).__init__(account, peer)

    def getPolicy(self, key):
        return True

    def inject(self, msg, appdata = None):
        mess = appdata["base_reply"]
        mess["body"] = str(msg)
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


class OtrBot(slixmpp.ClientXMPP):

    def __init__(self, account, password, otr_key_path,
                 rooms = [], connect_server = None, log_file = None):
        self.__connect_server = connect_server
        self.__password = password
        self.__log_file = log_file
        self.__rooms = rooms
        super().__init__(account, password)
        self.__otr_manager = OtrContextManager(account, otr_key_path)
        self.send_raw_message_fn = self.raw_send
        self.__default_otr_appdata = {
            "send_raw_message_fn": self.send_raw_message_fn
            }
        self.add_event_handler("session_start", self.start)
        self.add_event_handler("message", self.handle_message)
        self.register_plugin("xep_0045") # Multi-User Chat
        self.register_plugin("xep_0394") # Message Markup

    def __otr_appdata_for_mess(self, mess):
        appdata = self.__default_otr_appdata.copy()
        appdata["base_reply"] = mess
        return appdata

    def connect(self):
        address = ()
        if self.__connect_server:
            address = (self.__connect_server, self.default_port)
        super().connect(address)

    async def start(self, event):
        self.send_presence()
        await self.get_roster()
        for room in self.__rooms:
            self.join_room(room)

    def join_room(self, room):
        self.plugin["xep_0045"].join_muc(room, self.boundjid.user)

    def raw_send(self, mess):
        mess.send()

    def get_reply(self, command):
        if command.strip() == "ping":
            return "pong"
        return None

    def handle_message(self, mess):
        mess = self.decrypt(mess)
        reply = None
        if mess["type"] == "chat":
            if mess["html"]["body"].startswith("<p>?OTRv"):
                return
            reply = self.get_reply(mess["body"])
        elif mess["type"] == "groupchat":
            try:
                recipient, command = mess["body"].split(":", 1)
            except ValueError:
                recipient, command = None, mess["body"]
            if mess["mucnick"] == self.boundjid.user or recipient != self.boundjid.user:
                return
            response = self.get_reply(command)
            if response:
                reply = "%s: %s" % (mess["mucnick"], response)
        else:
            return
        if reply:
            self.send_message(mess.reply(reply))

    def send_message(self, mess):
        otrctx = self.__otr_manager.get_context_for_user(mess["to"])
        if otrctx.state == potr.context.STATE_ENCRYPTED:
            otrctx.sendMessage(potr.context.FRAGMENT_SEND_ALL,
                               mess["body"].encode("utf-8"),
                               appdata = self.__otr_appdata_for_mess(mess))
        else:
            self.raw_send(mess)

    def decrypt(self, mess):
        if mess["type"] == "groupchat":
            return mess
        otrctx = self.__otr_manager.get_context_for_user(mess["from"])
        if mess["type"] == "chat":
            try:
                appdata = self.__otr_appdata_for_mess(mess.reply())
                plaintext, tlvs = otrctx.receiveMessage(mess["body"].encode("utf-8"),
                                                        appdata = appdata)
                if plaintext:
                    decrypted_body = plaintext.decode("utf-8")
                else:
                    decrypted_body = ""
                otrctx.processTLVs(tlvs)
            except potr.context.NotEncryptedError:
                otrctx.authStartV2(appdata = appdata)
                return mess
            except (potr.context.UnencryptedMessage, potr.context.NotOTRMessage):
                decrypted_body = mess["body"]
        else:
            decrypted_body = mess["body"]
        mess["body"] = decrypted_body
        return mess

if __name__ == '__main__':
    logging.basicConfig(level=logging.DEBUG,
                        format="%(levelname)-8s %(message)s")
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
                        help = "auto-join multi-user chatrooms on start",
                        default = [])
    parser.add_argument("-l", "--log-file", metavar = 'LOGFILE',
                        help = "Log to file instead of stderr")
    args = parser.parse_args()
    otr_bot = OtrBot(args.account,
                     args.password,
                     args.otr_key_path,
                     rooms = args.auto_join,
                     connect_server = args.connect_server,
                     log_file = args.log_file)
    try:
        otr_bot.connect()
        otr_bot.process()
    except KeyboardInterrupt:
        otr_bot.disconnect()
