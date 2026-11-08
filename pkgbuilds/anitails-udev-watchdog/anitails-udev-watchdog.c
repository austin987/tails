/*
 * anitails-udev-watchdog.c
 * Emergency boot-media removal monitor for AniTails (Arch Linux / archiso).
 *
 * Ported & hardened from Tails config/chroot_local-includes/usr/src/udev-watchdog.c
 * (GPLv2+, originally derived from udev by Kay Sievers).
 *
 * Security & correctness improvements over legacy Tails udev-watchdog.c:
 * 1. Fixes uninitialized `filter_action` UB when argv[2] is neither "cd" nor "disk".
 * 2. Fixes potential NULL dereference on malformed uevent fields.
 * 3. Enforces slash-anchored DEVPATH suffix matching so `/devices/.../sdb` never
 *    falsely triggers on `/devices/.../xsdb` or `/devices/.../sdb1` (unless exact).
 * 4. Locks process pages into RAM via mlockall(MCL_CURRENT | MCL_FUTURE) so the
 *    watchdog binary can never be evicted from page cache after USB yank.
 * 5. Parses kernel NETLINK_KOBJECT_UEVENT datagrams directly (zero runtime shared-lib
 *    bloat) and supports `--test-fd <fd>` for deterministic unit testing.
 */

#define _GNU_SOURCE
#include <errno.h>
#include <linux/netlink.h>
#include <signal.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <unistd.h>

static volatile sig_atomic_t g_exit_state = 0; /* 0=run, 1=matched_removal, 2=signal */

static void on_signal(int sig) {
    if (sig == SIGINT || sig == SIGTERM) {
        g_exit_state = 2;
    }
}

/*
 * Slash-anchored suffix match:
 * `devpath` (e.g. "/devices/pci0000:00/usb1/1-1/block/sdb") matches `target_suffix`
 * (e.g. "/devices/pci0000:00/usb1/1-1/block/sdb" or "/block/sdb") iff `devpath`
 * ends with `target_suffix` AND either lengths are equal or the boundary is '/'.
 */
static bool devpath_matches_suffix(const char *devpath, const char *target_suffix) {
    if (devpath == NULL || target_suffix == NULL || target_suffix[0] == '\0') {
        return false;
    }
    size_t d_len = strlen(devpath);
    size_t t_len = strlen(target_suffix);
    if (d_len < t_len) {
        return false;
    }
    const char *tail = devpath + (d_len - t_len);
    if (strcmp(tail, target_suffix) != 0) {
        return false;
    }
    if (d_len == t_len || target_suffix[0] == '/') {
        return true;
    }
    return devpath[d_len - t_len - 1] == '/';
}

/*
 * Parse a NUL-delimited kernel uevent datagram:
 *   remove@/devices/.../block/sdb\0ACTION=remove\0DEVPATH=/devices/.../block/sdb\0SUBSYSTEM=block\0...
 */
static bool match_uevent_datagram(
    const char *buf,
    ssize_t len,
    const char *expected_action,
    const char *expected_devsuffix
) {
    if (buf == NULL || len <= 0) {
        return false;
    }
    const char *action = NULL;
    const char *devpath = NULL;
    const char *subsystem = NULL;

    ssize_t pos = 0;
    while (pos < len) {
        const char *nul = memchr(buf + pos, '\0', (size_t)(len - pos));
        size_t tok_len = (nul != NULL) ? (size_t)(nul - (buf + pos)) : (size_t)(len - pos);
        /* Copy token into bounded stack buffer to ensure NUL termination */
        char line[1024];
        if (tok_len < sizeof(line)) {
            memcpy(line, buf + pos, tok_len);
            line[tok_len] = '\0';
            if (strncmp(line, "ACTION=", 7) == 0) {
                action = strdup(line + 7);
            } else if (strncmp(line, "DEVPATH=", 8) == 0) {
                devpath = strdup(line + 8);
            } else if (strncmp(line, "SUBSYSTEM=", 10) == 0) {
                subsystem = strdup(line + 10);
            }
        }
        pos += (ssize_t)tok_len + 1;
    }

    bool matched = false;
    if (subsystem != NULL && strcmp(subsystem, "block") == 0 &&
        action != NULL && strcmp(action, expected_action) == 0 &&
        devpath != NULL && devpath_matches_suffix(devpath, expected_devsuffix)) {
        fprintf(stdout, "MATCH action=%s devpath=%s\n", action, devpath);
        fflush(stdout);
        matched = true;
    }

    free((void *)action);
    free((void *)devpath);
    free((void *)subsystem);
    return matched;
}

static int open_uevent_netlink_socket(void) {
    int fd = socket(AF_NETLINK, SOCK_DGRAM | SOCK_CLOEXEC, NETLINK_KOBJECT_UEVENT);
    if (fd < 0) {
        return -1;
    }
    struct sockaddr_nl addr;
    memset(&addr, 0, sizeof(addr));
    addr.nl_family = AF_NETLINK;
    addr.nl_pid = 0;      /* let kernel assign unique port id */
    addr.nl_groups = 1U;  /* kernel uevent multicast group */

    int rcvbuf = 2 * 1024 * 1024;
    (void)setsockopt(fd, SOL_SOCKET, SO_RCVBUFFORCE, &rcvbuf, sizeof(rcvbuf));
    (void)setsockopt(fd, SOL_SOCKET, SO_RCVBUF, &rcvbuf, sizeof(rcvbuf));

    if (bind(fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        close(fd);
        return -1;
    }
    return fd;
}

int main(int argc, char *argv[]) {
    int test_fd = -1;
    int arg_idx = 1;

    if (argc >= 3 && strcmp(argv[1], "--test-fd") == 0) {
        char *endp = NULL;
        long parsed = strtol(argv[2], &endp, 10);
        if (endp == argv[2] || *endp != '\0' || parsed < 0 || parsed > 65535) {
            fprintf(stderr, "error: invalid --test-fd value\n");
            return 2;
        }
        test_fd = (int)parsed;
        arg_idx = 3;
    }

    if (argc - arg_idx != 2) {
        fprintf(stderr, "Usage: %s [--test-fd FD] <devpath-suffix> <disk|cd>\n", argv[0]);
        return 2;
    }

    const char *filter_devsuffix = argv[arg_idx];
    const char *filter_devtype = argv[arg_idx + 1];
    const char *filter_action = NULL;

    if (strcmp(filter_devtype, "cd") == 0) {
        filter_action = "change";
    } else if (strcmp(filter_devtype, "disk") == 0) {
        filter_action = "remove";
    } else {
        fprintf(stderr, "error: unsupported device type '%s' (expected 'disk' or 'cd')\n", filter_devtype);
        return 2;
    }

    /* Best-effort lock into RAM so removal of live USB never faults binary pages */
    (void)mlockall(MCL_CURRENT | MCL_FUTURE);

    struct sigaction act;
    memset(&act, 0, sizeof(act));
    act.sa_handler = on_signal;
    sigemptyset(&act.sa_mask);
    sigaction(SIGINT, &act, NULL);
    sigaction(SIGTERM, &act, NULL);

    int sock_fd = (test_fd >= 0) ? test_fd : open_uevent_netlink_socket();
    if (sock_fd < 0) {
        fprintf(stderr, "error: unable to open uevent socket: %s\n", strerror(errno));
        return 3;
    }

    char buf[8192];
    while (g_exit_state == 0) {
        fd_set rfds;
        FD_ZERO(&rfds);
        FD_SET(sock_fd, &rfds);

        int ready = select(sock_fd + 1, &rfds, NULL, NULL, NULL);
        if (ready < 0) {
            if (errno == EINTR) {
                continue;
            }
            fprintf(stderr, "error: select failed: %s\n", strerror(errno));
            break;
        }
        if (ready > 0 && FD_ISSET(sock_fd, &rfds)) {
            ssize_t n = recv(sock_fd, buf, sizeof(buf) - 1, 0);
            if (n <= 0) {
                if (n < 0 && errno == EINTR) {
                    continue;
                }
                /* EOF on test socket without match -> return non-zero */
                if (test_fd >= 0) {
                    close(sock_fd);
                    return 4;
                }
                continue;
            }
            if (match_uevent_datagram(buf, n, filter_action, filter_devsuffix)) {
                g_exit_state = 1;
            }
        }
    }

    if (test_fd < 0) {
        close(sock_fd);
    }
    return (g_exit_state == 1) ? 0 : 1;
}
