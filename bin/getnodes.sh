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

# Get efm nodes. Use GNU getopt

PATH=/usr/bin:BINDIR export PATH

prog=`basename $0 .sh`

usage() {
	cat >&2 <<-! 
usage: $prog [OPTION] [<cluster>]
OPTION:
  -p, --primary              Print the primary node
  -s, --standby              List all standby nodes
  -w, --witness              Print the witness node
  -c, --coordinator          The current membership coordinator
      --membershipcoordinator        
  -f, --failoverpriority     Ordered priority list
  -a, --allowednodes         List of nodes allowed to join
  -?, --help                 Give this help list
	!
	exit 2
}

TEMP=`getopt -o mpswcfah --long primary,standby,witness,coordinator,failoverpriority,allowednodes,membershipcoordinator,help \
	 -n "$prog" -- "$@"`

[ $? != 0 ] && { usage; exit 1; }

# Note the quotes around `$TEMP': they are essential!
eval set -- "$TEMP"
typeset pflg= sflag= wflg= cflg= fflg= aflg= errflg= node=".*"

while true
do
	case "$1" in
	-m|-p|--primary)
		[ "$sflg" -o "$wflg" -o "$cflg" -o "$fflg" -o "$aflg" ] && errflg=y
		node="primary"
		pflg=y
		shift ;;
	-s|--standby)
		[ "$pflg" -o "$wflg" -o "$cflg" -o "$fflg" -o "$aflg" ] && errflg=y
		node="standby"
		sflg=y
		shift ;;
	-w|--witness)
		[ "$pflg" -o "$sflg" -o "$cflg" -o "$fflg" -o "$aflg" ] && errflg=y
		node="witness"
		wflg=y
		shift ;;
	-c|--coordinator|--membershipcoordinator)
		[ "$pflg" -o "$sflg" -o "$wflg" -o "$fflg" -o "$aflg" ] && errflg=y
		node="membershipcoordinator"
		cflg=y
		shift ;;
	-f|--failoverpriority)
		[ "$pflg" -o "$sflg" -o "$wflg" -o "$cflg" -o "$aflg" ] && errflg=y
		node="failoverpriority"
		fflg=y
		shift ;;
	-a|--allowednodes)
		[ "$pflg" -o "$sflg" -o "$wflg" -o "$cflg" -o "$fflg" ] && errflg=y
		node="allowednodes"
		aflg=y
		shift ;;
	-h|--help)
		errflg=y
		shift; break ;;
	--)	shift; break ;;
	*)	errflg=y; break ;;
	esac
done

###
: ${CLUSTER:=efm}
export CLUSTER

[ $# -gt 1 ] && errflg=y
[ $# -eq 1 ] && CLUSTER="$1"

[ $errflg ] && usage

PATH=$PATH:`efmpath` || exit $?

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
