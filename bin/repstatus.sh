#!/bin/bash -
# vim: syntax=psql:ts=4:sw=4:

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

PATH=/usr/bin:BINDIR export PATH

prog=`basename $0 .sh`
typeset errflg=

: ${CLUSTER:=efm}
export CLUSTER

while getopts "u:" opt 2>&-
do
	case $opt in
	u)	user="$OPTARG"	# user used for replication
		uflg=y ;;
	\?)	errflg=y
	esac
done
shift $(( OPTIND - 1 ))

[ $# -gt 1 ] && errflg=y

[ $errflg ] && { echo "usage: $prog [-u <user>]" >&2; exit 2; }

sg()
{
	typeset _pi= _p=
	while [ $1 ]
	do
		case ${1%%:*} in
		black)	_p=30 ;;
		red)	_p=31 ;;
		green)	_p=32 ;;
		yellow)	_p=33 ;;
		blue)	_p=34 ;;
		magen*)	_p=35 ;;
		cyan)	_p=36 ;;
		white)	_p=37 ;;
		ul|un*)	_p=4  ;;
		bold)	_p=1  ;;
		off)	_p=0  ;;
		*)		shift; continue ;;
		esac
		shift
		[ "$_pi" ] && _pi="$_pi;$_p" || _pi=$_p
	done
	echo -n "[${_pi}m"
}
off=$(sg off) bold=$(sg bold) master=$(sg green) standby=$(sg yellow)


sudo -n -i -u enterprisedb psql -XE -U ${user:=efm} postgres <<-! 

	select pg_is_in_recovery as var1
	\gset
	\if :var1
		\echo Database IS in recovery
		
		select setting as cluster_name from pg_settings where name = 'cluster_name'
		\gset
		\echo cluster_name = ''''${standby}:cluster_name${off}''''

		select conninfo as conninfo from pg_stat_wal_receiver
		\gset
		\echo conninfo = :conninfo

		select setting as synchronous_standby_names from pg_settings where name = 'synchronous_standby_names'
		\gset
		\echo * synchronous_standby_names = '''':synchronous_standby_names''''

		\echo
		\echo pg_stat_wal_receiver
		select pid,
			status,
			receive_start_lsn,
			receive_start_tli,
			received_lsn,
			received_tli,
			sender_host,
			sender_port
		from pg_stat_wal_receiver;

		\echo Recovery Information Functions
		select 
			pg_is_wal_replay_paused(),
			pg_last_wal_receive_lsn(),
			pg_last_wal_replay_lsn(),
			pg_last_xact_replay_timestamp();
	\else
		\echo Database IS NOT in recovery

		select setting as cluster_name from pg_settings where name = 'cluster_name'
		\gset
		\echo cluster_name = ''''${master}:cluster_name${off}''''

		select setting as synchronous_standby_names from pg_settings where name = 'synchronous_standby_names'
		\gset
		\echo synchronous_standby_names = '''':synchronous_standby_names''''

		select setting as synchronous_commit from pg_settings where name = 'synchronous_commit'
		\gset
		\echo synchronous_commit = '''':synchronous_commit''''

		\echo
		\echo pg_stat_replication
		select pid,
			usename,
			application_name,
			client_addr,
			state,
			sent_lsn,
				-- Last write-ahead log location sent on this connection.
			write_lsn,
				-- Last write-ahead log location written to disk by this standby server.
			flush_lsn,
				-- Last write-ahead log location flushed to disk by this standby server.
			replay_lsn,
				-- Last write-ahead log location replayed into the database on this
				-- standby server.
			--decode(':synchronous_commit', 'remote_write', write_lag, null) as write_lag,
				-- Time elapsed between flushing recent WAL locally and
				-- receiving notification that this standby server has written it
				-- (but not yet flushed it or applied it). This can be used to
				-- gauge the delay that synchronous_commit level REMOTE_WRITE
				-- incurred while committing if this server was configured as a
				-- synchronous standby.
			-- flush_lag, 
				-- Time elapsed between flushing recent WAL locally and
				-- receiving notification that this standby server has written
				-- and flushed it (but not yet applied it). This can be used to
				-- gauge the delay that synchronous_commit level ON incurred
				-- while committing if this server was configured as a
				-- synchronous standby.
			--decode(':synchronous_commit', 'remote_apply', replay_lag, null) as replay_lag,
				-- Time elapsed between flushing recent WAL locally and
				-- receiving notification that this standby server has
				-- written, flushed and applied it. This can be used to gauge the
				-- delay that synchronous_commit level REMOTE_APPLY incurred
				-- while committing if this server was configured as a
				-- synchronous standby.
			-- sync_priority,
				-- Priority of this standby server for being chosen as the
				-- synchronous standby in a priority-based synchronous
				-- replication. This has no effect in a quorum-based synchronous
				-- replication.
			sync_state
		from pg_stat_replication;

		\echo pg_stat_replication - pertaining to synchronous_commit = '''':synchronous_commit''''

		select decode(:'synchronous_commit', 'remote_write', 't', 'f') as remote_write
		\gset
		select decode(:'synchronous_commit', 'remote_apply', 't', 'f') as remote_apply
		\gset
		select decode(:'synchronous_commit', 'on', 't', 'f') as onmode
		\gset

		\if :remote_write
			select application_name, flush_lag, write_lag from pg_stat_replication where sync_state = 'sync';
		\elif :remote_apply
			select application_name, flush_lag, replay_lag from pg_stat_replication where sync_state = 'sync';
		\else
			select application_name, flush_lag from pg_stat_replication where sync_state = 'sync';
		\endif

		\echo Backup Control Functions
		select pg_current_wal_lsn(), pg_last_wal_replay_lsn();
	\endif
!
