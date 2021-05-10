import os
from typing import List, Callable
import socket

import gi
from tinyrpc.protocols.jsonrpc import JSONRPCProtocol
from tinyrpc.exc import BadReplyError

gi.require_version("GLib", "2.0")

from gi.repository import GObject  # noqa: E402
from gi.repository import GLib  # noqa: E402


class GJsonRpcClient(GObject.GObject):
    """
    Wrap a raw socket and uses JSON-RPC over it.

    Supports calling methods, but not receiving server-initiated messages (ie: signals)
    """

    __gsignals__ = {
        "connection-closed": (
            GObject.SIGNAL_RUN_LAST,
            GObject.TYPE_NONE,
            (),
        ),
        "response": (
            GObject.SIGNAL_RUN_LAST,
            GObject.TYPE_NONE,
            (GObject.TYPE_INT, GObject.TYPE_STRING),
        ),
        "response-error": (
            GObject.SIGNAL_RUN_LAST,
            GObject.TYPE_NONE,
            (GObject.TYPE_INT, GObject.TYPE_STRING),
        ),
    }

    MAX_LINESIZE = 1024

    def __init__(self, sock: socket.socket):
        GObject.GObject.__init__(self)
        self.protocol = JSONRPCProtocol()
        self.sock = sock
        self.buffer = b""

    def run(self):
        GLib.io_add_watch(self.sock.fileno(), GLib.IO_IN, self._on_data)
        GLib.io_add_watch(self.sock.fileno(), GLib.IO_HUP | GLib.IO_ERR, self._on_close)

    def call_async(self, method: str, args=[], kwargs={}):
        req = self.protocol.create_request(method, args, kwargs)
        print('call async', req.unique_id)
        output = req.serialize() + "\n"
        self.sock.send(output.encode("utf8"))

    def _on_close(self, *args):
        self.emit('connection-closed')

    def _on_data(self, *args):
        self.buffer += self.sock.recv(self.MAX_LINESIZE)
        while b"\n" in self.buffer:
            newline_pos = self.buffer.find(b"\n")
            msg = self.buffer[:newline_pos]
            self.buffer = self.buffer[newline_pos + 1 :]
            try:
                response = self.protocol.parse_reply(msg)
            except BadReplyError:
                return
            if hasattr(response, "error"):
                self.emit("response-error", response.unique_id, response.error)
            else:
                self.emit("response", response.unique_id, response.result)
        return True


class GAsyncSpawn(GObject.GObject):
    """ GObject class to wrap GLib.spawn_async().

    Use:
        s = GAsyncSpawn()
        s.connect('process-done', mycallback)
        s.run(command)
            #command: list of strings
    """

    __gsignals__ = {
        "process-done": (
            GObject.SIGNAL_RUN_LAST,
            GObject.TYPE_NONE,
            (GObject.TYPE_INT,),
        ),
        "stdout-data": (
            GObject.SIGNAL_RUN_LAST,
            GObject.TYPE_NONE,
            (GObject.TYPE_STRING,),
        ),
        "stderr-data": (
            GObject.SIGNAL_RUN_LAST,
            GObject.TYPE_NONE,
            (GObject.TYPE_STRING,),
        ),
    }

    def __init__(self):
        GObject.GObject.__init__(self)

    def run(self, cmd):
        r = GLib.spawn_async(
            cmd,
            flags=GLib.SPAWN_DO_NOT_REAP_CHILD,
            standard_output=True,
            standard_error=True,
        )
        self.pid, idin, idout, iderr = r
        fout = os.fdopen(idout, "r")
        ferr = os.fdopen(iderr, "r")

        self.event_sources = []

        self.event_sources.append(GLib.child_watch_add(self.pid, self._on_done))
        self.event_sources.append(GLib.io_add_watch(fout, GLib.IO_IN, self._on_stdout))
        self.event_sources.append(GLib.io_add_watch(ferr, GLib.IO_IN, self._on_stderr))
        return self.pid

    def _on_done(self, pid, retval, *argv):
        self.emit("process-done", retval)
        for evt in self.event_sources:
            GLib.source_remove(evt)

    def _emit_std(self, name, value):
        self.emit(name + "-data", value)

    def _on_stdout(self, fobj, cond):
        self._emit_std("stdout", fobj.readline())
        return True

    def _on_stderr(self, fobj, cond):
        self._emit_std("stderr", fobj.readline())
        return True


def idle_add_chain(functions: List[Callable]):
    """
    Wrap GLib.idle_add allowing chains of functions.

    Use case: idle_add is very cool, but modifications to widgets aren't applied until the whole method add.
    A simple solution to this shortcoming is split your function in many small ones, and call them in a chain.

    Using idle_add_chain, you can write each step as a separate function, then call idle_add_chain with a list
    of those functions. The chain will continue ONLY if you return True.
    """
    if not functions:
        return
    first = functions.pop(0)

    def wrapped_fn():
        ret = first()
        if ret is True and functions:
            idle_add_chain(functions)

    GLib.idle_add(wrapped_fn)
