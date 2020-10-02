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
# Retrieve EFM bin path from systemd(1)

PATH=/usr/bin:BINDIR export PATH

prog=`basename $0 .sh`

: ${CLUSTER:=efm}
export CLUSTER

typeset eflg= errflg=

while getopts "e" opt 2>&-
do
	case $opt in
	e)	eflg=y ;;	# insist unit is enabled
	\?)	errflg=y
	esac
done
shift $(( OPTIND - 1 ))

[ $# -eq 0 ] || errflg=y
[ $errflg ] && {
	echo "usage: $prog [-e]" >&2; exit 2; }

# get unit file(s) for this cluster
typeset service=


while read unit state
do
	if [ "$state" = "enabled" ]
	then
		if [ -n "$enabled" ]
		then
			  echo "$prog: ERROR: multiple services are enabled for EFM for cluster '$CLUSTER'" >&2
            exit 1
        fi
        enabled=$unit
	else
		disabled="$unit" # this will be the last one i.e. the highest version
    fi
done < <(
		while read -r unit state
		do
			cluster=`systemctl show --property=Environment $unit | sed 's;.*CLUSTER=\([^[:space:]]*\);\1;'`
			[ "$cluster" = $CLUSTER ] && echo $unit $state
		done < <(systemctl --type=service --no-pager --no-legend list-unit-files edb-efm*))

if [ -n "$eflg" -a -z "$enabled" ]
then
	echo "$prog: no services are enabled for EFM for cluster '$CLUSTER'" >&2
	exit 1
fi	

if [ -n "$enabled" ]
then
	systemctl --no-pager --no-legend show --property=ExecStart $enabled | sed 's;.*\(/usr/edb/[^ ]*/bin\)/.*;\1;'
elif [ -n "$disabled" ]
then
	systemctl --no-pager --no-legend show --property=ExecStart $disabled | sed 's;.*\(/usr/edb/[^ ]*/bin\)/.*;\1;'
else
	exit 1
fi

exit 0
