#!/bin/bash -
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

# Create a Base Backup for 12
#  https://docs.aws.amazon.com/storagegateway/latest/APIReference/API_CreateNFSFileShare.html
#   File gateway does not support creating hard or symbolic links on a file share.

#PATH=/usr/bin:BINDIR export PATH
PATH=/usr/bin:/usr/local/bin export PATH

prog=`basename $0 .sh`
typeset fflg= Xflag= errflg= method=stream

while getopts "fX:" opt 2>&-
do
	case $opt in
	f)	fflg=y ;;
	X)	Xflg=y
		case "$method" in
		fetch|stream|none)	
			method="$OPTARG" ;;
		*)	errflg=y
		esac ;;
	\?)	errflg=y
	esac
done
shift $(( OPTIND - 1 ))

[ $# -eq 1 ] || errflg=y

[ $errflg ] && { echo "usage: $prog [-f] <rhost>" >&2; exit 2; }

bindir=`ls -d /usr/edb/efm-*/bin | sort -t\- -V -k2 -r | head -1`
PATH=$PATH:$bindir

rhost="$1"
if ! ent=`getent hosts $rhost`
then
	echo "$prog: cannot find remote host entry '$rhost'" >&2
	exit 1
fi

set -- $ent
rhostip=$1
eval rhost=\$$#
echo "rhost = $rhost [$rhostip]"

hostip=`hostname -i`
if ! ent=`getent hosts $hostip`
then
	echo "$prog: cannot find local host entry for '$hostip'" >&2
	exit 1
fi
set -- $ent
eval host=\$$#
echo "host = $host [$hostip]"

if [ "X$host" = "X$rhost" ]
then
	echo "$prog: host and remote host cannot be the same node"; exit 1
fi

# Find the Master node
eval `efm cluster-status-json efm | jq -r '.nodes |
        to_entries |
        map_values(.value + { node: .key }) | .[]  |
        select(.type | test("Master"; "ig")) |
        { item: "masterip=\(.node)" } | .[]'`

if [ "X$masterip" = "X" ]
then
	echo "$prog: cannot determine master node in cluster" >&2
	exit 1
fi

if ! ent=`getent hosts $masterip`
then
	echo "$prog: cannot find local host entry for '$masterip'" >&2
	exit 1
fi
set -- $ent
eval master=\$$#

if [ "X$rhostip" != "X$masterip" ]
then
	echo "$prog: remote host $rhost [$rhostip] is not the master node $master [$masterip]"; exit 1
fi

db="edb-as-12"

if status=`systemctl is-active $db`
then
	if [ "X$status" = "Xactive" ]
	then
		echo "$prog: service $db is running"; exit 1
	fi
fi

: ${PGDATA:=/pg/data}

if [ ! "$fflg" ] && sudo -u enterprisedb [ -d $PGDATA ]
then
	echo "$prog: directory '$PGDATA' already exists, override with -f" >&2
	exit 1
fi

sudo -i -u enterprisedb rm -rf ${PGDATA}

sudo -i -u enterprisedb /usr/edb/as12/bin/pg_basebackup \
	--host=$rhostip \
	--wal-method=$method \
	--progress \
	--pgdata=${PGDATA:=/pg/data} \
	--write-recovery-conf \
	--verbose \
	--username=efm

# pg_basebackup will change synchronous_standby_names
# however cluster_name and application_name must be changed
# synchronous_standby_names is also changed in readiness for this standby
# being promoted
# pg_basebackup will change host= in postgresql.auto.conf to the name of the primary
sudo -i -u enterprisedb  \
ex -s $PGDATA/postgresql.conf <<-!
	g/^[ 	]*cluster_name[ 	]*=/ s;=.*;= '$host';
	g/^[ 	]*synchronous_standby_names[ 	]*=/ s;=.*;= '$rhost';
	g/^[ 	]*primary_conninfo[ 	]*=/s;\(application_name\)=[^ 	']\{1,\};\1=$host;
	g/^[ 	]*primary_conninfo[ 	]*=/s;\(host\)=[^ 	']\{1,\};\1=$rhostip;
	w!
!

# Clear postgresql.auto.conf

# Set certificate to be the correct one - or change the location!
