import stem
from stem.control import Controller

CONTROL_SOCKET_PATH = '/var/run/tor/control'


def tor_has_bootstrapped():
    try:
        c = Controller.from_socket_file(CONTROL_SOCKET_PATH)
    except stem.SocketError:
        # Socket is not available
        return False
    c.authenticate()
    info = c.get_info("status/bootstrap-phase")
    return "PROGRESS=100" in info.split()
