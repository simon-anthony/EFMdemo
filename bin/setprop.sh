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
# Set properties in ${CLUSTER}.properties

PATH=/usr/bin:BINDIR export PATH

prog=`basename $0 .sh`
typeset errflg=
typeset -l property

while getopts "f:" opt 2>&-
do
	case $opt in
	f)	fflg=y 
		file="$OPTARG";;
	\?)	errflg=y
	esac
done
shift $(( OPTIND - 1 ))

[ -z "$fflg" -a $# -eq 0 ] && errflg=y
[ -n "$fflg" -a $# -gt 0 ] && errflg=y

[ $errflg ] && {
	echo "usage: $prog <property>=<value> [<property>=<value>...]" >&2; 
	echo "       $prog -f <file>" >&2; exit 2; }

: ${CLUSTER:=efm}
export CLUSTER

properties=`ls /etc/edb/efm-*/${CLUSTER}.properties | sort -t\- -V -k2 -r | head -1`
if [ ! -r "$properties" ] 
then
	echo $prog: "properties file not found for $cluster" >&2; exit 1
fi

if [ ! -w "$properties" ] 
then
	echo $prog: "properties file '$properties' not writable" >&2; exit 1
fi

tmpfile=`mktemp`

writeprop() {
	local fflg= errflg= tmpfile=
	local property= value=
	local prog=writeprop
	OPTIND=1
	while getopts "f:" opt 2>&-
	do
		case $opt in
		f)	fflg=y 
			tmpfile="$OPTARG";;
		\?)	errflg=y
		esac
	done
	shift $(( OPTIND - 1 ))
	[ $fflg ] || errflg=y
	[ $# -eq 1 ] || errflg=y
	[ $errflg ] && { echo "usage: $prog -f <file> <arg>"; return 2; }

	if [[ "$1" =~ [a-zA-Z\.*]+= ]]
	then
		property=${1%=*}
		if getprop $property >/dev/null 2>&1
		then
			value="${1#*=}"
			echo "g/^$property=/s;=.*;=$value;" >> $tmpfile
		else
			echo "$prog: invalid property: '$property'" >&2
		fi
	else
		echo "$prog: bad format: '$1'" >&2
	fi
}

while [ $# -ne 0 ]
do
	writeprop -f $tmpfile "$1"
	shift	
done

if [ $fflg ]
then
	while read line
	do
		writeprop -f $tmpfile "$line"
	done < $file
fi

if [ ! -s $tmpfile ] # there are no edits to make
then
	echo "$prog: no edits to make" >&2
	exit 1
fi

echo "w!" >> $tmpfile

# lock file and update
flock -w 10 $properties ex -s $properties < $tmpfile
