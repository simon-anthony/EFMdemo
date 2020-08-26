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

# Get efm nodes for CLUSTER. The user invoking this script must be a member of
# the "efm" group. SUPERSEDED by getnodes

PATH=/usr/bin:BINDIR export PATH

prog=`basename $0 .sh`
typeset mflg= sflag= wflg= cflg= fflg= errflg= 
node=".*"
: ${CLUSTER:=efm}

while getopts "mswcfa" opt 2>&-
do
	case $opt in
	m)	[ "$sflg" -o "$wflg" -o "$cflg" -o "$fflg" -a "$aflg" ] && errflg=y
		node="master"
		fflg=y ;;
	s)	[ "$mflg" -o "$wflg" -o "$cflg" -o "$fflg" -a "$aflg" ] && errflg=y
		node="standby"
		sflg=y ;;
	w)	[ "$mflg" -o "$sflg" -o "$cflg" -o "$fflg" -a "$aflg" ] && errflg=y
		node="witness"
		wflg=y ;;
	c)	[ "$mflg" -o "$sflg" -o "$wflg" -o "$fflg" -a "$aflg" ] && errflg=y
		node="membershipcoordinator"
		cflg=y ;;
	f)	[ "$mflg" -o "$sflg" -o "$wflg" -o "$cflg" -a "$aflg" ] && errflg=y
		node="failoverpriority"
		fflg=y ;;
	a)	[ "$mflg" -o "$sflg" -o "$wflg" -o "$cflg" -a "$fflg" ] && errflg=y
		node="allowednodes"
		aflg=y ;;
	\?)	errflg=y
	esac
done
shift $(( OPTIND - 1 ))

[ $# -gt 1 ] && errflg=y
[ $# -eq 1 ] && CLUSTER="$1"

[ $errflg ] && { echo "usage: $prog [-m|s|w|c|f] [<cluster>]" >&2; exit 2; }

bindir=`ls -d /usr/edb/efm-*/bin | sort -t\- -V -k2 -r | head -1`
PATH=$PATH:$bindir

# Find the node(s)
if [ "$cflg" ]
then
	efm cluster-status-json $CLUSTER | jq -r '.membershipcoordinator'
elif [ "$fflg" ]
then
	efm cluster-status-json $CLUSTER | jq -r '.failoverpriority | .[]'
elif [ "$afflg" ]
then
	efm cluster-status-json $CLUSTER | jq -r '.allowednodes | .[]'
else
	efm cluster-status-json $CLUSTER | jq -r '.nodes |
        to_entries |
        map_values(.value + { node: .key }) | .[]  |
        select(.type | test("'$node'"; "ig")) |
        { item: "\(.node)" } | .[]'
fi
