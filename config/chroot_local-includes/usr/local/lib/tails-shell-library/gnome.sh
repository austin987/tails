# shellcheck shell=sh
GNOME_ENV_VARS="
DBUS_SESSION_BUS_ADDRESS
DISPLAY
LANG
XAUTHORITY
XDG_RUNTIME_DIR
XDG_CURRENT_DESKTOP
"

export_gnome_env() {
    # Get LIVE_USERNAME
    . /etc/live/config.d/username.conf
    local gnome_shell_pid
    gnome_shell_pid="$(pgrep --newest --euid "${LIVE_USERNAME}" --exact gnome-shell)"
    if [ -z "${gnome_shell_pid}" ]; then
        return
    fi
    local tmp_env_file
    tmp_env_file="$(mktemp)"
    local vars
    # shellcheck disable=SC2086
    vars="($(echo ${GNOME_ENV_VARS} | tr ' ' '|'))"
    tr '\0' '\n' < "/proc/${gnome_shell_pid}/environ" | \
        grep -E "^${vars}=" > "${tmp_env_file}"
    # shellcheck disable=SC2163
    while read -r line; do export "${line}"; done < "${tmp_env_file}"
    rm "${tmp_env_file}"
}
