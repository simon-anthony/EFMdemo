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

typeset -i enabled=`systemctl --type=service --no-pager --no-legend --state=enabled list-unit-files edb-efm* | wc -l`
if [ $enabled -eq 1 ]
then
	# simple case
	unit=`systemctl --type=service --no-pager --no-legend --state=enabled list-unit-files edb-efm* | cut -f1 -d\ `
elif [ $enabled -gt 1 ]
then
	echo "$prog: ERROR: multiple services are enabled for EFM:" >&2
	systemctl --type=service --no-pager --no-legend --state=enabled >&2
	exit 1
elif [ $enabled -eq 0 ]
then
	if [ $eflg ]
	then
		echo "$prog: no services are enabled for EFM" >&2
		exit 1
	fi
	# consider installed how many are installed
	typeset -i installed=`systemctl --type=service --no-pager --no-legend list-unit-files edb-efm* | wc -l`
	if [ $installed -eq 0 ]
	then
		echo "$prog: no services are installed for EFM" >&2
		exit 1
	elif [ $installed -eq 1 ]
	then
		unit=`systemctl --type=service --no-pager --no-legend --state=disabled list-unit-files edb-efm* | cut -f1 -d\ `
	else # more than one installed - choose highest version
		unit=`systemctl --type=service --no-pager --no-legend --state=disabled list-unit-files edb-efm* | tail -1 | cut -f1 -d\ `
	fi
fi

[ "X$unit" = "X" ] && exit 1
systemctl --no-pager --no-legend show --property=ExecStart $unit | sed 's;.*\(/usr/edb/[^ ]*/bin\)/.*;\1;'
