export_gnome_env() {
    # Get LIVE_USERNAME
    . /etc/live/config.d/username.conf
    export DISPLAY=':0.0'
    export XAUTHORITY="`echo /var/run/gdm3/auth-for-${LIVE_USERNAME}-*/database`"
    GNOME_SHELL_PID="$(pgrep --newest --euid ${LIVE_USERNAME} gnome-shell)"
    export "$(tr '\0' '\n' < /proc/${GNOME_SHELL_PID}/environ | \
                      grep '^DBUS_SESSION_BUS_ADDRESS=')"
}
