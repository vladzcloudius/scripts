#!/usr/bin/env python3

import argparse
import sys
import re

################################################################################
argp = argparse.ArgumentParser(description = "Find non-token-aware queries in traces.", formatter_class=argparse.RawDescriptionHelpFormatter,
                               epilog=
'''
Fetch tracing info using cqlsh as follows:

cqlsh -e "COPY system_traces.events (session_id,event_id,activity,scylla_parent_id,scylla_span_id,source,source_elapsed,thread) to '<events CSV file name'"
cqlsh -e "COPY system_traces.sessions (session_id,client,command,coordinator,duration,parameters,request,request_size,response_size,started_at) to '<sessions CSV file name>'"
''')
argp.add_argument('--sessions', help='CSV file with contents of system_traces.sessions content')
argp.add_argument('--events', help='CSV file with contents of system_traces.events content')

args = argp.parse_args()
if not args.sessions or not args.events:
    sys.exit("Please provide sessions and events CSV files. Exiting...")

sessionid_to_coordinator = {}
sessionid_to_query = {}
sessionid_to_events = {}
sessionid_to_natural_endpoints = {}

# Map sessionid to events
with open(args.events) as efile:
    for line in efile:
        sid = line.split(",")[0]
        if sid in sessionid_to_events:
            sessionid_to_events[sid].append(line)
        else:
            sessionid_to_events[sid] = [ line ]

# Map sessionid to coordinator
query_pattern = re.compile(".*\'query\'\: \'(.*)\'.*")
with open(args.sessions) as sfile:
    for line in sfile:
        line_split = line.split(",")
        sid = line_split[0]
        coordinator = line_split[3]
        sessionid_to_coordinator[sid] = coordinator

        res = query_pattern.match(line)
        if res:
            sessionid_to_query[sid] = res.group(1).split("'")[0]
        else: 
            sys.exit("No query for {}".format(sid))

# Map sessionid to replicas
for sid, lines in sessionid_to_events.items():
    for line in lines:
        if re.search("Creating write handler for token", line):
            natural = line.split(":")[2].split("}")[0].split("{")[1].split(",")
            natural = [ s.strip() for s in natural ]

            sessionid_to_natural_endpoints[sid] = natural

        if re.search("Creating read executor for token", line):
            natural = line.split(":")[1].split("}")[0].split("{")[1].split(",")
            sessionid_to_natural_endpoints[sid] = natural

for sid, coordinator in sessionid_to_coordinator.items():
    if sid in sessionid_to_natural_endpoints and not coordinator in sessionid_to_natural_endpoints[sid]:
        print("{} is not token aware: {}".format(sid, sessionid_to_query[sid]))
        
