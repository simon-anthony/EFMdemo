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

[ $errflg ] && { echo "usage: $prog [-n] [<failed-primary-address> [<new-primary-address>]]" >&2; exit 2; }

eval typeset -l `getprop -v syslog.facility`

logger -t $prog -p ${syslog_facility:=local1}.info "Invoked"

# Check default access key
if ! access_key=`aws configure get aws_access_key_id`
then
	logger -t $prog -p ${syslog_facility}.error "User `id -un` is not configured for AWS [$access_key], exiting"
	exit 1
fi

network_interface_id=`aws ec2 describe-instances --filter Name=private-dns-name,Values=\`hostname\` --query "Reservations[*].Instances[*].NetworkInterfaces[*].NetworkInterfaceId" --out text`
logger -t $prog -p ${syslog_facility}.info "NetworkInterfaceId $network_interface_id"

allocation_id=`aws ec2 describe-addresses --filter Name=tag:EFM,Values=vip --query "Addresses[*].AllocationId" --out text`
logger -t $prog -p ${syslog_facility}.info "AllocationId $allocation_id"

logger -t $prog -p ${syslog_facility}.info "Associating interface $network_interface_id with allocation $allocation_id"
aws ec2 associate-address --network-interface-id "$network_interface_id" --allocation-id "$allocation_id" --allow-reassociation

logger -t $prog  -p ${syslog_facility}.info "Status returned by associating-address: $?"

logger -t $prog -p ${syslog_facility}.info "Exited"
