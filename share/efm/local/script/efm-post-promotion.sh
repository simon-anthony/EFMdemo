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

# The user invoking this script (typically "efm") must have been authenticated
# to aws. You can configure credentials by running "aws configure" as this
# user.
# First argument is failed primary (%f), second argument is new primary (%p)

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

[ $# -gt 2 ] && errflg=y

[ $errflg ] && { echo "usage: $prog [-n] [<failed-primary-address> [<new-primary-address>]]" >&2; exit 2; }

eval typeset -l `getprop -v syslog.facility`

logger -t $prog -p ${syslog_facility:=local1}.info "Invoked"
eval `getprop -v virtual.ip`
klist

logger -t $prog -p ${syslog_facility}.info "virtual.ip is $virtual_ip"

if [ "X$virtual_ip" != "X" ]
then
	logger -t $prog -p ${syslog_facility}.info "setting CNAME to $virtual_ip"
	if nsupdate -g <<-!
		server windows.example.com
		update delete vip.example.com A
		update add vip.example.com 86400 A $virtual_ip
		send
	!
	then
		logger -t $prog -p ${syslog_facility}.info "CNAME successfully changed"
	else
		logger -t $prog -p ${syslog_facility}.error "CNAME change failed"
	fi
fi

# There must be ~efm/.pgpass set up for this purpose (or GSSAPI or other
# method obviating need for password entry)
host=`dig -x $2 +short` host=${host%.} shost=${host%%.*}
eval `grep ^pem_host= /usr/edb/pem/agent/etc/agent.cfg`
eval `grep ^pem_port= /usr/edb/pem/agent/etc/agent.cfg`

logger -t $prog -p ${syslog_facility}.info "Setting primary to $host [$2] in PEM"
psql -Xwq -h $pem_host -p $pem_port -U postgres -d pem <<-!
	UPDATE pem.server 
	SET description = substring(description from '^[^ ]*')
	WHERE efm_cluster_name = '$CLUSTER';

	UPDATE pem.server 
	SET description = description ||' - primary'
	WHERE efm_cluster_name = '$CLUSTER'
	AND (server = '$shost' OR server = '$host' OR server = '$2');
!

logger -t $prog -p ${syslog_facility}.info "Exited"
