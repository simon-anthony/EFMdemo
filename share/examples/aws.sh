#!/bin/bash -
# AWS Examples
# The user invoking this script (typically "efm") must have been authenticated
# to aws. You can configure credentials by running "aws configure" as this
# First argument is failed master (%f), second argument is new primary (%p)

#PATH=/usr/bin:BINDIR export PATH
PATH=/usr/bin:/usr/local/bin export PATH

prog=`basename $0 .sh`
typeset nflg= errflg=

while getopts "n" opt 2>&-
do
	case $opt in
	n)	nflg=y ;;
	\?)	errflg=y
	esac
done
shift $(( OPTIND - 1 ))

[ $errflg ] && { echo "usage: $prog [-n]" >&2; exit 2; }

properties=`ls /etc/edb/efm-*/${CLUSTER:=efm} | sort -t\- -V -k2 -r | head -1`

if [ -r "$properties" ] 
then
	typeset -l facility=`sed -n '/syslog.facility=/ { s/.*=[ 	]*// ; p }' $properties`
fi

logger -t $prog -p ${facility:=local1}.info "Invoked"

# Check default access key
if ! access_key=`aws configure get aws_access_key_id`
then
	logger -t $prog -p ${facility}.error "User `id -un` is not configured for AWS [$access_key], exiting"
	exit 1
fi

aws ec2 describe-instances  --filter Name=tag:EFM,Values=s* --query 'Reservations[*].Instances[*].{AZ:Placement.AvailabilityZone,Name:Tags[?Key==`EFM`]|[0].Value}'

# AZ
aws ec2 describe-instances --filter Name=tag:EFM,Values=s1 --query "Reservations[*].Instances[*].Placement.AvailabilityZone" --out text

network_interface_id=`aws ec2 describe-instances --filter Name=private-dns-name,Values=\`hostname\` --query "Reservations[*].Instances[*].NetworkInterfaces[*].NetworkInterfaceId" --out text`
logger -t $prog -p ${facility}.info "NetworkInterfaceId $network_interface_id"

allocation_id=`aws ec2 describe-addresses --filter Name=tag:EFM,Values=vip --query "Addresses[*].AllocationId" --out text`
logger -t $prog -p ${facility}.info "AllocationId $allocation_id"

logger -t $prog -p ${facility}.info "Associating interface $network_interface_id with allocation $allocation_id"
aws ec2 associate-address --network-interface-id "$network_interface_id" --allocation-id "$allocation_id" --allow-reassociation

logger -t $prog  -p ${facility}.info "Status returned by associating-address: $?"

logger -t $prog -p ${facility:=local1}.info "Exited"

# list instances
aws ec2 describe-instances  --filter Name=tag:Name,Values=* --query 'Reservations[*].Instances[*].{Instance:InstanceId,Name:Tags[?Key==`Name`]|[0].Value}'
