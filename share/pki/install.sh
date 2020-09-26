#!/bin/sh -

sudo cp ExampleRoot.cer /etc/pki/ca-trust/source/anchors
sudo update-ca-trust extract

hostip=`hostname -i`

if ! ent=`getent hosts $hostip`
then
	echo "$prog: cannot find local host entry for '$hostip'" >&2
	exit 1
fi
set -- $ent
eval host=\$$#

certs=/etc/pki/tls/certs
private=/etc/pki/tls/private

sudo cp -f servers/$host.crt $certs/server.crt
sudo cp -f servers/$host.key $private/server.key

sudo chown root:enterprisedb $certs/server.crt
sudo chown root:enterprisedb $private/server.key

sudo chmod 444 $certs/server.crt 
sudo chmod 440 $private/server.key
