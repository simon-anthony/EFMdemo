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
#PATH=/usr/bin:BINDIR export PATH
PATH=/usr/bin:/usr/local/bin export PATH
: ${CLUSTER:=efm}

prog=`basename $0 .sh`
properties=`ls /etc/edb/efm-*/${CLUSTER}.properties | sort -t\- -V -k2 -r | head -1`

if [ ! -r "$properties" ]
then
    echo $prog "properties file not found for $cluster" >&2
    exit 1
fi

for i
do
    grep -i "^$i=" $properties
done
