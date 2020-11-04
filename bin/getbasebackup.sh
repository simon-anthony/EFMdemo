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

PATH=/usr/bin:BINDIR export PATH

prog=`basename $0 .sh`
typeset fflg= iflg= Xflag= errflg= method=stream

: ${CLUSTER:=efm}
export CLUSTER

while getopts "fiX:" opt 2>&-
do
	case $opt in
	f)	fflg=y ;;	# force removal of existing PGDATA
	i)	iflg=y ;;	# ignore EFM status
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

[ $errflg ] && { echo "usage: $prog [-fi] [-X <method>] <rhost>" >&2; exit 2; }

properties=`getprop -p`

if [ "X$properties" = "X" ]
then
	echo "$prog: cannot find properties file for EFM" >&2
	exit 1
fi
version=${properties##*-} version=${version%%/*}
maj=${version%.*} min=${version#*.}

PATH=$PATH:`efmpath` || exit $?

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

# Get all properties at the start so that we can inform the user if any are
# missing.
err=
for property in db.service.name db.service.owner db.data.dir db.bin db.user application.name 
do
    eval `getprop -v $property`
    rval=`eval echo \\$\${property//./_}`
    if [ "X$rval" = "X" ]
    then
        echo "$prog: no value for $property found" >&2
		err=y
    fi
done
[ $err ] && exit 1

eval `getprop -v is.witness`	# I know I have a properties file at this point

if [ "X$is_witness" = "Xtrue" ]
then
	echo "$prog: current node is witness" >&2
	exit 1
fi

if [ ! "$iflg" ]
then
	if ! status=`systemctl is-active edb-efm-\*`
	then
		 echo "$prog: EFM systemd service is not started${iflg:+, ignored}" >&2
		 [ $iflg ] || exit 1
		 efm=n
	fi

	# Check if agent is contactable
	if [ \( $maj -eq 3 -a $min -ge 10 \) -o $maj -gt 3 ] # 3.10+ offers this
	then
		# cluster-status(-json) will return non-zero if not all nodes are active
		# so we use node-status
		if ! efm node-status-json $CLUSTER > /dev/null 2>&1
		then
			agent=`efm node-status-json $CLUSTER | jq -r '.agent'`
			if [ "X$agent" != "XUP" ]
			then
				echo "$prog: EFM agent is not up, check service is started${iflg:+, ignored}" >&2
				[ $iflg ] || exit 1
				efm=n
			fi
		fi
	fi

	# Find the Primary node
	eval `efm cluster-status-json $CLUSTER | jq -r '.nodes |
			to_entries |
			map_values(.value + { node: .key }) | .[]  |
			select(.type | test("Master|Primary"; "ig")) |
			{ item: "primaryip=\(.node)" } | .[]'`

	if [ "X$primaryip" = "X" ]
	then
		echo "$prog: cannot determine primary node in cluster" >&2; exit 1
	fi

	if ! ent=`getent hosts $primaryip`
	then
		echo "$prog: cannot find local host entry for '$primaryip'" >&2; exit 1
	fi
	set -- $ent
	eval primary=\$$#

	if [ "X$rhostip" != "X$primaryip" ]
	then
		echo "$prog: remote host $rhost [$rhostip] is not the primary node $primary [$primaryip]"; exit 1
	fi
fi

if status=`systemctl is-active $db_service_name`
then
	if [ "X$status" = "Xactive" ]
	then
		echo "$prog: service $db_service_name is running"; exit 1
	fi
fi

if [ -z "$db_data_dir" ]
then
		echo "$prog: db.data.dir is null"; exit 1
fi

empty="`sudo -n -i -u $db_service_owner find $db_data_dir -prune -empty`"

if [ ! "$fflg" ] && [ ! "$empty" ]
then
	echo "$prog: directory '$db_data_dir' already exists, override with -f" >&2; exit 1
fi

if [ ! "$empty" ]
then
	if [ $iflg ]
	then
		if ! sudo -i -n -u $db_service_owner [ -f $db_data_dir/standby.signal ]
		then
			echo "$prog: directory '$db_data_dir' is not a standby, cannot remove" >&2; exit 1
		fi
	fi

	# Is pg_wal somewhere other than PGDATA?
	target=`sudo -n -i -u $db_service_owner sh -c "ls -l ${db_data_dir}/pg_wal" | awk '$(NF-1) == "->" { print $(NF) }'`
	if [ -n "$target" ]
	then
		echo "$prog: removing $target/*"
		sudo -n -i -u $db_service_owner sh -c "rm -rf ${target}/*"
	fi
	echo "$prog: removing $db_data_dir/*"
	sudo -n -i -u $db_service_owner sh -c "rm -rf ${db_data_dir}/*"
fi

sudo -n -i -u $db_service_owner $db_bin/pg_basebackup \
	--host=$rhostip \
	--wal-method=$method \
	--progress \
	--pgdata=${db_data_dir} \
	--write-recovery-conf \
	--verbose \
	--username=${db_user:=efm} || exit $?

# pg_basebackup will change synchronous_standby_names
# however cluster_name and application_name must be changed
# synchronous_standby_names is also changed in readiness for this standby
# being promoted
# pg_basebackup will change host= in postgresql.auto.conf to the name of the primary

sudo -n -i -u $db_service_owner  \
ex -s $db_data_dir/postgresql.conf <<-!
	g/^[ 	]*cluster_name[ 	]*=/ s;=.*;= '$host';
	g/^[ 	]*synchronous_standby_names[ 	]*=/ s;=.*;= '$rhost';
	g/^[ 	]*primary_conninfo[ 	]*=/s;\(application_name\)=[^ 	']\{1,\};\1=${application_name:-$host};
	g/^[ 	]*primary_conninfo[ 	]*=/s;\(host\)=[^ 	']\{1,\};\1=$rhostip;
	w!
!

# Clear postgresql.auto.conf of primary_conninfo which is added by
# pg_basebackup
sudo -n -i -u $db_service_owner  \
ex -s $db_data_dir/postgresql.auto.conf <<-!
	g/^[ 	]*primary_conninfo[ 	]*=/d
	w!
!
# Set certificate to be the correct one - or change the location!

# Is pg_wal somewhere other than PGDATA?
target=`sudo -n -i -u $db_service_owner ssh $rhostip "ls -l ${db_data_dir}/pg_wal" | awk '$(NF-1) == "->" { print $(NF) }'`
if [ -n "$target" ]
then
	sudo -n -i -u $db_service_owner sh -c "
		mv ${db_data_dir}/pg_wal/* $target && \
		rmdir ${db_data_dir}/pg_wal && \
		ln -fs $target ${db_data_dir}/pg_wal"
fi
