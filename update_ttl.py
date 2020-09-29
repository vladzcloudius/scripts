#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# Copyright 2017 ScyllaDB
#
#
# This file is part of Scylla.
#
# Scylla is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Scylla is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Scylla.  If not, see <http://www.gnu.org/licenses/>.
#
import argparse
import cassandra
import itertools
import sys
import time

from cassandra.cluster import Cluster
from cassandra.auth import PlainTextAuthProvider

################################################################################
# FIXME: make this all a class and make all these parameters class members
def process_one_page(args, session, row, del_prepared, update_prepared, pr_key_names_len):
    now = time.time()
    write_time_seconds = int(row[0]) / 1000000
    row_age_seconds = int(now - write_time_seconds)
    #print("{}: written {} seconds ago".format(row[0], now - write_time_seconds))

    print("# In process_one_page")


    if (row_age_seconds >= args.ttl):
        last_key_idx = 2 + pr_key_names_len
        print("## going to delete this key: {}".format(key_vals))
        session.execute(del_prepared, row[2:last_key_idx])
    elif row[1] is None:
        print("## Updating")
        new_ttl = args.ttl - row_age_seconds
        session.execute(update_prepared, list(itertools.chain(row[2:], [ new_ttl ])))
        
def update_ttl(args):
    res = True
    if args.user:
        auth_provider = PlainTextAuthProvider(username=args.user, password=args.password)
        cluster = Cluster(auth_provider=auth_provider, contact_points=[args.node], port=args.port)
    else:
        cluster = Cluster(contact_points=[args.node], port=args.port)

    try:
        session = cluster.connect()
        cluster_meta = session.cluster.metadata
        
        if args.keyspace not in cluster_meta.keyspaces:
            print("Keyspace \"{}\" is unknown".format(args.keyspace))
            sys.exit(1)

        if args.table not in cluster_meta.keyspaces[args.keyspace].tables:
            print("Table \"{}.{}\" is unknown".format(args.keyspace, args.table))
            sys.exit(1)

        ks_meta = cluster_meta.keyspaces[args.keyspace]
        table_meta = ks_meta.tables[args.table]

        pr_key_names = [ tm.name for tm in table_meta.primary_key ]
        print("{}".format(pr_key_names))

        non_key_columns = []
        for cl in table_meta.columns:
            if cl not in pr_key_names:
                non_key_columns.append(cl)
        
        if not non_key_columns:
            sys.exit("Can't find non key column. We will not be able to update TTLs.")

        qstring = "SELECT WRITETIME(\"{}\"),TTL(\"{}\"),{} FROM {}.{}".format(non_key_columns[0], non_key_columns[0], ",".join([ "\"{}\"".format(cl) for cl in pr_key_names + non_key_columns ]), args.keyspace, args.table)
        del_qstring = "DELETE FROM {}.{} WHERE {}".format(args.keyspace, args.table, " AND ".join([ "\"{}\" = ?".format(pcl) for pcl in pr_key_names ]))
        update_qstring = "INSERT INTO {}.{} ({}) VALUES ({}) USING TTL ?".format(args.keyspace, args.table, ",".join([ "\"{}\"".format(cl) for cl in pr_key_names + non_key_columns ]), ",".join([ "?" for cl in pr_key_names + non_key_columns]))

        print("preparing del_statement")

        del_prepared = session.prepare(del_qstring)
        # FIXME: use user provided values
        del_prepared.consistency_level = cassandra.ConsistencyLevel.ALL

        print("preparing update_statement")
        update_prepared = session.prepare(update_qstring)
        # FIXME: use user provided values
        update_prepared.consistency_level = cassandra.ConsistencyLevel.LOCAL_QUORUM

        print("qstring: {}\ndel_string: {}\nupdate_str: {}".format(qstring, del_qstring, update_qstring))

        pr_key_names_len = len(pr_key_names)

        print("going to execute QUERY")
        for row in session.execute(qstring):
            process_one_page(args, session, row, del_prepared, update_prepared, pr_key_names_len)

    except Exception:
        print("ERROR: {}".format(sys.exc_info()))
        sys.exit(1)

################################################################################
argp = argparse.ArgumentParser(description='Update TTLs for all records in a given table')
argp.add_argument('--user', '-u')
argp.add_argument('--password', '-p', default='none')
argp.add_argument('--node', default='127.0.0.1', help='Node to connect to.')
argp.add_argument('--port', default=9042, help='Port to connect to.', type=int)
argp.add_argument('--keyspace', help='Keyspace name')
argp.add_argument('--table', help='Table name')
argp.add_argument('--ttl', help='TTL to set', type=int)
#argp.add_argument('--delete_cl', default="ALL", help="Consistency level of the DELETE operation")
#argp.add_argument('--update_cl', help='Consistency level of the INSERT operation')

args = argp.parse_args()
if (not (args.keyspace and args.table and args.ttl)):
    sys.exit("Keyspace and table names, and TTL are obligatory parameters")

# TODO: implement an enum class that translates from delete_cl value into the cassandra.ConsistencyLevel value

res = update_ttl(args)
if res:
    sys.exit(0)
else:
    sys.exit(1)
