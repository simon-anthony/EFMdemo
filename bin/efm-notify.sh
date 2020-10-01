#!/usr/bin/bash
# vim: syntax=sh:ts=4:sw=4:

# Copyright (C) 2020 EDB simon.anthony@enterprisedb.com
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation, either version 3 of the License or, (at your
# option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
# Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program. If not see <http://www.gnu.org/licenses/>>
#

# EFM Notification Program - forward messages to witness for onward
# submission.
# The user invoking this script must be the "efm" user i.e. the owner of the
# cluser.
# If SELinux is enabled:
#	The user "efm" will have a non-standard home directory if created by
#	default. Assuming that "efm" is the name of the owner of the EFM cluster.
#
#   For "efm" to be able to use ssh, the following will need to be done,
#   assuming /var/efm is "efm"'s home directory:
#
#     sudo semanage fcontext -a -t ssh_home_t /var/efm/.ssh/authorized_keys
#     sudo semanage fcontext -a -t ssh_home_t /var/efm/.ssh
#     sudo restorecon -R -v /var/efm/.ssh/

PATH=/usr/bin:BINDIR export PATH

prog=`basename $0 .sh`

: ${CLUSTER:=efm}
export CLUSTER

PATH=$PATH:`efmpath` || exit $?

eval typeset -l `getprop -v syslog.facility`
eval typeset -l `getprop -v is.witness`

logger -t $prog -p ${syslog_facility:=local1}.info "Invoked"

user=`id -un`
: ${ICON:=DATADIR/icons/edb/32x32/efm.png}

if [ "A$is_witness" = "Atrue" ]
then
	if [ "X$HOME" = "X" ]
	then
		HOME=`getent passwd $user | cut -d: -f6`
	fi
	if [ "X$HOME" = "X" ]
	then
		logger -p ${syslog_facility}.info -t $prog "Unable to determine HOME for $user"
	elif [ -f "$HOME"/.notify ]
	then
		notify=`cat "$HOME"/.notify`
		ssh $notify "
			eval \"export \$(egrep -z DBUS_SESSION_BUS_ADDRESS /proc/\$(pgrep -u \$LOGNAME gnome-session)/environ)\"
			notify-send -i $ICON \"$1\" \"$2\"
		"
	else
		notify-send -i $ICON "$1" "$2"
	fi	
else
	# Find the Witness node
	eval `efm cluster-status-json $CLUSTER | jq -r '.nodes |
		to_entries |
		map_values(.value + { node: .key }) | .[]  |
		select(.type | test("Witness"; "ig")) |
		{ item: "witnessip=\(.node)" } | .[]'`

	ssh $user@$witnessip /bin/sh "$0 '$1' '$2'"
fi
logger -t $prog -p ${syslog_facility}.info "Exited"
