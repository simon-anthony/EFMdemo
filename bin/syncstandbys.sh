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

# Set synchronous_standby_names

PATH=/usr/bin export PATH

prog=`basename $0 .sh`

typeset -i num_standbys=0 num_sync=0
typeset sflg= nflg= aflg= errflg=

while getopts "n:s:a" opt 2>&-
do
    case $opt in
    s)  num_standbys=$OPTARG	# number of standby nodes
		sflg=y
		;;
    n)  num_sync=$OPTARG		# num_sync
		nflg=y		
		;;
	a)	method="ANY"			# change method from FIRST to ANY
		aflg=y
		;;
    \?) errflg=y
    esac
done
shift $(( OPTIND - 1 ))

[ $# -eq 0 ] && {
	echo -n "synchronous_standby_names = "
	sudo -i -u enterprisedb psql -A -t postgres -c "show synchronous_standby_names"
	exit 0
}
[[ $num_sync -gt $num_standbys ]] && {
	echo "$prog: ERROR num_sync ($num_sync) greater than standbys ($num_standbys)" >&2
	exit 1
}
[ $sflg ] || errflg=y
[ $nflg ] || num_sync=$num_standbys	# default all standbys are sync

[ $errflg ] && { echo "usage: $prog [ -s <num_standbys> [-n <num_sync>]]" >&2; exit 2; }

(( n = num_standbys + 1 ))
hostip=`hostname -i`
if ! ent=`getent hosts $hostip`
then
	echo "$prog: cannot find local host entry for '$hostip'" >&2
	exit 1
fi
set -- $ent
eval host=\$$#
prefix=${host%%[0-9]*}

standby_names=
i=1

string="'${method:=FIRST} $((n - 1)) ("
while [[ $i -le $n ]]
do
	if [[ $prefix$i != $host ]] 
	then
		[[ $i -gt 1 ]] && string="$string, "
		string="$string$prefix$i"
	fi
	(( i = i + 1 ))
done

string="$string)'"

sudo -i -u enterprisedb psql postgres -c "ALTER SYSTEM SET synchronous_standby_names = $string"
sudo systemctl reload edb-as-12
