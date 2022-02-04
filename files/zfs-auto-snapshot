PATH="/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin"

15,30,45 * * * * root which zfs-auto-snapshot > /dev/null || exit 0 ; zfs-auto-snapshot --quiet --syslog --label=15min --keep=20 //
0 * * * * root which zfs-auto-snapshot > /dev/null || exit 0 ; zfs-auto-snapshot --quiet --syslog --label=hourly --keep=24 //
7 0 * * * root which zfs-auto-snapshot > /dev/null || exit 0 ; zfs-auto-snapshot --quiet --syslog --label=daily --keep=14 //
14 0 * * 0 root which zfs-auto-snapshot > /dev/null || exit 0 ; zfs-auto-snapshot --quiet --syslog --label=weekly --keep=4 //
28 0 1 * * root which zfs-auto-snapshot > /dev/null || exit 0 ; zfs-auto-snapshot --quiet --syslog --label=monthly --keep=4 //

