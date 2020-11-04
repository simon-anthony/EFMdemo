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

# Using GSS-TSIG to update DNS record for VIP
# * Using a client keytab
#   Required is a client keytab created on Windows:
#     ktpass -princ host/efm.example.com@EXAMPLE.COM 
#       -ptype KRB5_NT_PRINCIPAL -crypto AES256-SHA1 
#       -mapop set -pass * -mapuser efm@example.com -out efm.keytab
#   This is then installed:
#     mkdir -p /var/kerberos/krb5/user/efm
#     cp -f efm.keytab /var/kerberos/krb5/user/efm/client.keytab
#     chown efm:efm /var/kerberos/krb5/user/efm/client.keytab
#     chmod 600 /var/kerberos/krb5/user/efm/client.keytab
# kinit -ki
#
# * Using PKINIT
#   Copy the certificate (efm.crt) and key (efm.key) to /etc/pki/tls/certs
#   and /etc/pki/tls/private, respectively
# X509_PROXY=FILE:/etc/pki/tls/certs/efm.crt,/etc/pki/tls/private/efm.key
# kinit -X X509_user_identity=ENV:X509_PROXY

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

if [ $# -ne 2 ]
then
	logger -t $prog -p ${syslog_facility:=local1}.info "New primary address not passed as parameter"
	logger -t $prog -p ${syslog_facility:=local1}.info "Exited"
	exit 0
fi

host=`dig -x $2 +short` host=${host%.} shost=${host%%.*} domain=${host#*.}
ns=`dig ns $domain +short` ns=${ns%.}

if kinit -ki
then
	logger -t $prog -p ${syslog_facility:=local1}.info "kinit with client keytab succeeded"
else
	user=`id -un`
	X509_PROXY=FILE:/etc/pki/tls/certs/$user.crt,/etc/pki/tls/private/$user.key
	if kinit -X X509_user_identity=ENV:X509_PROXY
	then
		logger -t $prog -p ${syslog_facility:=local1}.info "kinit with X509 certificate succeeded"
	else
		logger -t $prog -p ${syslog_facility:=local1}.info "kinit failed"
	fi
fi

logger -t $prog -p ${syslog_facility}.info "virtual.ip is $virtual_ip"

if [ "X$virtual_ip" != "X" ]
then
	# Update the Address record - could do CNAME but with Address can change
	# PTR record also
	if nsupdate -g <<-!
		server $ns
		update delete vip.$domain A
		update add vip.$domain 86400 A $virtual_ip
		send
	!
	then
		logger -t $prog -p ${syslog_facility}.info "DNS A record successfully changed to $virtual_ip"
	else
		logger -t $prog -p ${syslog_facility}.error "DNS A change failed"
	fi
fi

# There must be ~efm/.pgpass set up for this purpose (or GSSAPI or other
# method obviating need for password entry)
eval `grep ^pem_host= /usr/edb/pem/agent/etc/agent.cfg`
eval `grep ^pem_port= /usr/edb/pem/agent/etc/agent.cfg`

# Get addresses and names of standby nodes to restrict SQL update (in case
# there are multiple clusters with the same name
a=(`getnodes -s`)
addresses=`echo ${a[@]@Q} | sed 's/ /, /g'`	# format for SQL

b=(`for i in ${a[@]}; do dig -x $i +short; done`)
b=(${b[@]/%./}) 	# remove trailing '.'
names=`echo ${b[@]@Q} | sed 's/ /, /g'` # format for SQL

logger -t $prog -p ${syslog_facility}.info "Setting primary to $host [$2] in PEM"
psql -Xwq -h $pem_host -p $pem_port -U postgres -d pem <<-!
	UPDATE pem.server 
	SET description = substring(description from '^[^ ]*')
	WHERE efm_cluster_name = '$CLUSTER'
	AND (server IN ($addresses) OR server IN ($names));

	UPDATE pem.server 
	SET description = description ||' - primary'
	WHERE efm_cluster_name = '$CLUSTER'
	AND (server = '$shost' OR server = '$host' OR server = '$2');
!

logger -t $prog -p ${syslog_facility}.info "Exited"
