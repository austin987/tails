GNOME_ENV_VARS="
DBUS_SESSION_BUS_ADDRESS
DISPLAY
XAUTHORITY
XDG_RUNTIME_DIR
"

export_gnome_env() {
    # Get LIVE_USERNAME
    . /etc/live/config.d/username.conf
    local gnome_shell_pid="$(pgrep --newest --euid ${LIVE_USERNAME} gnome-shell)"
    if [ -z "${gnome_shell_pid}" ]; then
        return
    fi
    local tmp_env_file="$(tempfile)"
    local vars="($(echo ${GNOME_ENV_VARS} | tr ' ' '|'))"
    tr '\0' '\n' < "/proc/${gnome_shell_pid}/environ" | \
        grep -E "^${vars}=" > "${tmp_env_file}"
    while read line; do export "${line}"; done < "${tmp_env_file}"
    rm "${tmp_env_file}"
}
