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

# The user invoking this script (typically "efm") must have been authenticated
# to gcp. You can configure credentials by running "gcloud auth login
# --no-launch-browser" and then "gcloud init" as this user.

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

[ $errflg ] && { echo "usage: $prog [-n] [<failed-primary-address> [<new-primary-address>]]" >&2; exit 2; }

eval typeset -l `getprop -v syslog.facility`

logger -t $prog -p ${syslog_facility:=local1}.info "Invoked"

# There must be ~efm/.pgpass set up for this purpose
shost=`dig -x $2 +short` shost=${shost%%.*}

psql -Xwq -h pemserver -p 5432 -U postgres -d pem <<-!
	UPDATE pem.server 
	SET description = server
	WHERE efm_cluster_name = '$CLUSTER';

	UPDATE pem.server 
	SET description = server ||' - primary'
	WHERE efm_cluster_name = '$CLUSTER'
	AND (server = '$shost' OR server = '$2') ;
!
logger -t $prog -p ${syslog_facility}.info "Exited"
