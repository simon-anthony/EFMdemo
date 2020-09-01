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

# Get AWS Availability zone
# The user invoking this script (typically "efm") must have been authenticated
# to aws. You can configure credentials by running "aws configure" as this
# user.

PATH=/usr/bin:BINDIR export PATH

prog=`basename $0 .sh`
typeset nflg= zflg= errflg=

: ${CLUSTER:=efm}
export CLUSTER

while getopts "nz:" opt 2>&-
do
	case $opt in
	n)	nflg=y ;;
	z)	zone="$OPTARG"
		zflg=y ;;
	\?)	errflg=y
	esac
done
shift $(( OPTIND - 1 ))

[ $# -gt 1 ] && errflg=y
[ -n "$zflg" -a $# -gt 0 ] && errflg=y

[ $errflg ] && { 
	echo "usage: $prog [<node>]" >&2; 
	echo "       $prog -z <zone>" >&2; exit 2; }

if [ $# -eq 1 ]
then
	hostip=`getent hosts $1 | cut -d\  -f1`
else
	hostip=`hostname -i`
fi

# Check default access key
if ! access_key=`aws configure get aws_access_key_id`
then
	echo $prog: "User `id -un` is not configured for AWS [$access_key]" >&2
	exit 1
fi

if [ $zflg ]
then
	aws ec2 describe-instances  \
		--filter Name=tag:EFM,Values=s* \
				 Name=availability-zone,Values=$zone \
				 Name=tag:CLUSTER,Values=${CLUSTER} \
		--query 'Reservations[*].Instances[*].{Name:Tags[?Key==`EFM`]|[0].Value}'
		exit
fi

if ! ent=`getent hosts $hostip`
then
	echo "$prog: cannot find host entry for '$hostip'" >&2
	exit 1
fi
set -- $ent
eval host=\$$#


# Print the Availability Zone I am or $1 is in
aws ec2 describe-instances \
	--filter Name=tag:EFM,Values=$host \
			 Name=tag:CLUSTER,Values=${CLUSTER} \
	--query "Reservations[*].Instances[*].Placement.AvailabilityZone" --out text
