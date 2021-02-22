import os
from typing import List, Callable

import gi

gi.require_version("GLib", "2.0")

from gi.repository import GObject  # noqa: E402
from gi.repository import GLib  # noqa: E402



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

        GLib.child_watch_add(self.pid, self._on_done)
        GLib.io_add_watch(fout, GLib.IO_IN, self._on_stdout)
        GLib.io_add_watch(ferr, GLib.IO_IN, self._on_stderr)
        return self.pid

    def _on_done(self, pid, retval, *argv):
        self.emit("process-done", retval)

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
    this is a wrapper over GLib.idle_add

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
