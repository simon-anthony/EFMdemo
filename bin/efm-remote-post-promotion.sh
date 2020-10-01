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

# Add user "efm" to the "wheel" group, this should have NOPASSWD
# or set NOPASSWD individually for the commands /usr/bin/systemctl and
# /usr/bin/ex
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

logger -t $prog -p ${facility:=local1}.info "Invoked"

logger -t $prog -p ${facility}.info "New primary is: $primary"

primary=`dig -x $primary +short`	# hostname
if  [ "X$primary" = "X" ]
then
	logger -t $prog -p ${facility}.error "Unable to perform reverse lookup for: $1, exiting"
	exit 1
fi
primary=${primary%%.*}

logger -t $prog -p ${facility}.info "Setting new primary in autofs: $primary"
if sudo -n ex -s /etc/sysconfig/autofs <<-!
	g/^[ 	]*OPTIONS=/s;-DRHOST=[^"' 	]\{1,\} *;;
	g/^[ 	]*OPTIONS=/s;=";="-DRHOST=$primary ;
	w!
!
then
	sudo -n systemctl reload autofs
	logger -t $prog -p ${facility}.info "Reloaded autofs"
else
	logger -t $prog -p ${facility}.error "Failed to edit /etc/sysconfig/autofs"
fi
logger -t $prog -p ${facility:=local1}.info "Exited"
