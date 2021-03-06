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

# The user invoking this script must be the "efm" user i.e. the owner of the
# cluster.

# Add user "efm" to the "wheel" group, this should have NOPASSWD
# or set NOPASSWD individually for the commands /usr/bin/systemctl and
# /usr/bin/ex and /usr/bin/sed. For example:
#
# cat /etc/sudoers.d/efm-local:
# efm    ALL=(ALL)           NOPASSWD:   /usr/bin/systemctl
# efm    ALL=(ALL)           NOPASSWD:   /usr/bin/ex
# OR
# efm    ALL=(ALL)           NOPASSWD:   /usr/bin/rvim -e
# efm    ALL=(ALL)           NOPASSWD:   /usr/bin/sed
# efm    ALL=(ALL)           NOPASSWD:   /usr/bin/umount
#
# First argument is new primary node (%p)

PATH=/usr/bin:BINDIR export PATH

prog=`basename $0 .sh`
typeset nflg= errflg=

: ${CLUSTER:=efm}
export CLUSTER

while getopts "n" opt 2>&-
do
	case $opt in
	n)	nflg=y ;;
	\?)	errflg=y
	esac
done
shift $(( OPTIND - 1 ))

[ $# -eq 1 ] || errflg=y

[ $errflg ] && { echo "usage: $prog [-n] <primary-address>" >&2; exit 2; }

# parameter passed as primary must be an IP address
if [[ "$1" =~ [a-z].* ]]
then
	primary=`dig "$1" +short`	
else
	primary=$1
fi

eval typeset -l `getprop -v syslog.facility`
eval `getprop -v db.data.dir`

#archive=`sudo -n sed -n '/^archive_command/ { s;.*[[:blank:]]/\([^[:blank:]]*\)/.*;/\1;p ; }' $db_data_dir/postgresql.conf`
#restore=`sudo -n sed -n '/^restore_command/ { s;.*[[:blank:]]/\([^[:blank:]]*\)/.*;/\1;p ; }' $db_data_dir/postgresql.conf`

logger -t $prog -p ${facility:=local1}.info "Invoked"

logger -t $prog -p ${facility}.info "New primary is: $primary"

primary=`dig -x $primary +short`	# hostname
if  [ "X$primary" = "X" ]
then
	logger -t $prog -p ${facility}.error "Unable to perform reverse lookup for: $1, exiting"
	exit 1
fi
primary=${primary%%.*}

# could edit the map directly and then do a reload - assuming we know the name
# of the map
# Otherwise as we cannot change global macro without restart of automount process
# we performa a restart
if [ $reload ]
then
	logger -t $prog -p ${facility}.info "Setting new primary in map: $primary"
	if sudo -n ex -s /etc/auto.shared <<-\!
		g%^[[:blank:]]*/restore%s;/[^[:blank:]/]\{1,\}[[:blank:]]*\\*$;/$NEWRHOST;
		w! /tmp/auto.new
	!
	then
		sudo -n systemctl reload autofs && \
			logger -t $prog -p ${facility}.info "Reload autofs" || \
			logger -t $prog -p ${facility}.error "Reload autofs failed"
	else
		logger -t $prog -p ${facility}.error "Failed to edit /etc/auto.shared"
	fi
else
	logger -t $prog -p ${facility}.info "Setting new primary as RHOST in autofs: $primary"
	if sudo -n ex -s /etc/sysconfig/autofs <<-!
		g/^[ 	]*OPTIONS=/s;-DRHOST=[^"' 	]\{1,\} *;;
		g/^[ 	]*OPTIONS=/s;=";="-DRHOST=$primary ;
		w!
	!
	then
		sudo -n systemctl restart autofs && \
			logger -t $prog -p ${facility}.info "Restart autofs" || \
			logger -t $prog -p ${facility}.error "Restart autofs failed"
	else
		logger -t $prog -p ${facility}.error "Failed to edit /etc/sysconfig/autofs"
	fi
fi
logger -t $prog -p ${facility:=local1}.info "Exited"
