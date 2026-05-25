divert(-1)changequote(`[', `]')dnl
dnl summary.m4 — plausible-quadlet-setup installer output templates
dnl Usage: printf '_macro()\n' | m4 -D VAR=val ... share/summary.m4 -
define([_preflight],[
    User:              PLAUSIBLE_USER (uid PLAUSIBLE_UID)
    Pool:              ZFS_POOL
    Container dataset: DS_CONTAINER -> MNT_CONTAINER
    User dataset:      DS_USER -> MNT_USER
    Podman:            PODMAN_VER
])dnl
define([_header],[
==> Plausible CE PLAUSIBLE_VERSION deployment complete

    Service account:   PLAUSIBLE_USER (uid PLAUSIBLE_RUNTIME_UID)
    ZFS home:          DS_USER -> MNT_USER
    ZFS data:          DS_CONTAINER -> MNT_CONTAINER
    Quadlet dir:       QUADLET_DIR
])dnl
define([_endpoints],[
    Analytics:         https://analytics.dapla.net
    HAProxy backend:   http://127.0.0.1:8000
])dnl
define([_ops],[
    Logs:   machinectl shell PLAUSIBLE_USER@ -- journalctl --user -u plausible.service -f
    Status: machinectl shell PLAUSIBLE_USER@ -- systemctl --user status plausible.service

    Edit secrets: MNT_CONTAINER/config/plausible.env
])dnl
divert(0)dnl
