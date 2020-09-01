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
# Retrieve properties from ${CLUSTER}.properties

PATH=/usr/bin:BINDIR export PATH

prog=`basename $0 .sh`
typeset nflg= iflg= errflg=
typeset -l property

while getopts "vi:" opt 2>&-
do
	case $opt in
	v)	[ $iflg ] && errflg=y 
		vflg=y ;;
	i)	[ $vflg ] && errflg=y
		property="$OPTARG"
		iflg=y ;;
	\?)	errflg=y
	esac
done
shift $(( OPTIND - 1 ))

[ -n "$iflg" -a $# -gt 0 ] && errflg=y

[ $errflg ] && {
	echo "usage: $prog [-v] [<property>]" >&2
	echo "       $prog -i <property>" >&2; exit 2; }

: ${CLUSTER:=efm}
export CLUSTER

properties=`ls /etc/edb/efm-*/${CLUSTER}.properties | sort -t\- -V -k2 -r | head -1`
if [ ! -r "$properties" ] 
then
	echo $prog: "properties file not found for $cluster" >&2
	exit 1
fi

if [ $iflg ]
then
	sed -n "
		/#/ { H; }
		/^[ 	]*$/ { x; d; n; }
		/^$property=/ { x; p; q; }" $properties
	exit 0
fi

[ $# -eq 0 ] && set -- "[a-z\.0-9]*"

for i
do
	if [ $vflg ]
	then
		grep -i "^$i=" $properties | awk -F= '{ gsub("\\.", "_", $1); printf("%s=%s\n", $1, $2); }'
	else
		grep -i "^$i=" $properties 
	fi
done
