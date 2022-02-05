PATH="/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin"

15,30,45	*	*	*	*	root	zfs-auto-snapshot.ruby2.5 15min 20
0	*	*	*	*	root	zfs-auto-snapshot.ruby2.5 hourly 24
7	0	*	*	*	root	zfs-auto-snapshot.ruby2.5 daily 14
14	0	*	*	0	root	zfs-auto-snapshot.ruby2.5 weekly 4
28	0	1	*	*	root	zfs-auto-snapshot.ruby2.5 monthly 4
