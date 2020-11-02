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
typeset vflg= iflg= pflg= rflg= fflg= errflg=
typeset -l property
typeset regex=".*"

while getopts "vi:pr:f:" opt 2>&-
do
	case $opt in
	v)	[ "$iflg" -o "$pflg" -o "$rflg" ] && errflg=y
		vflg=y ;;					# return in shell variable form
	i)	[ "$vflg" -o "$pflg" -o "$rflg" ] && errflg=y
		property="$OPTARG"
		[ $fflg ] && errflg=y
		iflg=y ;;					# print information about property
	p)	[ "$iflg" -o "$vflg" -o "$rflg" ] && errflg=y
		[ $fflg ] && errflg=y
		pflg=y ;;					# print properties file name
	r)	[ "$pflg" -o "$iflg" ] && errflg=y
		regex="$OPTARG"
		rflg=y ;;					# search matching regex
	f)	[ "$pflg" -o "$iflg" ] && errflg=y
		properties="$OPTARG"
		fflg=y
		;;
	\?)	errflg=y
	esac
done
shift $(( OPTIND - 1 ))

[ -n "$iflg" -a $# -gt 0 ] && errflg=y
[ -n "$pflg" -a $# -gt 0 ] && errflg=y
[ -n "$rflg" -a $# -gt 0 ] && errflg=y

[ $errflg ] && {
	echo "usage: $prog [-v] [-f <file>] [<property>]" >&2;
	echo "       $prog [-v] [-f <file>] -r <regex>" >&2;
	echo "       $prog -i <property>" >&2;
	echo "       $prog -p" >&2; exit 2; }

: ${CLUSTER:=efm}
export CLUSTER

if [ ! "$fflg" ]
then
	properties=`ls /etc/edb/efm-*/${CLUSTER}.properties | sort -t\- -V -k2 -r | head -1`
fi
if [ ! -r "$properties" ] 
then
	echo $prog: "properties file not found for $cluster" >&2
	exit 1
fi

if [ $pflg ]
then
	echo $properties
	exit 0
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
	if [ $rflg ]
	then
		sed -n  "/^$i=/ { s;=.*;;p ; }" $properties | grep "${regex}" |
		while read j
		do
			if [ $vflg ]
			then
				grep -i "^$j=" $properties | awk -F= '{ gsub("\\.", "_", $1); printf("%s=%s\n", $1, $2); }'
			else
				grep "^$j=" $properties
			fi
		done
		exit
	fi
	if [ $vflg ]
	then
		grep -i "^$i=" $properties | awk -F= '{ gsub("\\.", "_", $1); printf("%s=%s\n", $1, $2); }'
	else
		grep -i "^$i=" $properties 
	fi
done
