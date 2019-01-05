#!/usr/bin/env python3

import argparse
import statistics
import sys

from cassandra.cluster import Cluster
from cassandra.auth import PlainTextAuthProvider
from cassandra.policies import RoundRobinPolicy

########################################################################################################################
def read_tokens_file(fname):
    node2tokens = {}

    with open(fname, "r") as f:
        for line in f:
            line = line.strip("\n")
            # print("line: {}".format(line))
            if line:
                line_parts = line.split("|")
                tokens_str = line_parts[1].strip().strip("{}")
                # print(tokens_str)
                tokens_str_arr = tokens_str.split(",")
                token_int_arr = [int(t.strip().strip("'")) for t in tokens_str_arr]
                # print(token_int_arr)
                node2tokens[line_parts[0].strip()] = token_int_arr

    return node2tokens


def read_tokens_from_cluster(session):
    node2tokens = {}

    peers_tokens = session.execute("select peer, tokens from system.peers")
    for peer, tokens in peers_tokens:
        node2tokens[peer] = [int(t) for t in tokens]

    # Load balancing is DcAwareRoundRobin - we shell eventually connect to the node from where we collected system.peers
    # data.
    while True:
        local_addr, tokens = list(session.execute("select broadcast_address, tokens from system.local"))[0]
        if local_addr not in node2tokens:
            node2tokens[local_addr] = [int(t) for t in tokens]
            break

    return node2tokens


########################################################################################################################
argp = argparse.ArgumentParser(description='Calculate various statistics about a given token ring')
argp.add_argument('--tokens-file', help='output of concatenation of SELECT peers,tokens FROM system.peers and SELECT '
                                        'broadcast_address,tokens FROM system.local (for debug purposes)')
argp.add_argument('--user', '-u')
argp.add_argument('--password', '-p', default='none')
argp.add_argument('--node', default='127.0.0.1', help='Node to connect to.')
argp.add_argument('--port', default='9042', help='Port to connect to.')

args = argp.parse_args()


if args.tokens_file:
    node2tokens = read_tokens_file(args.tokens_file)
else:
    if args.user:
        auth_provider = PlainTextAuthProvider(username=args.user, password=args.password)
        cluster = Cluster(auth_provider=auth_provider, contact_points=[args.node], port=args.port)
    else:
        cluster = Cluster(contact_points=[args.node], port=args.port)

    try:
        session = cluster.connect()
        node2tokens = read_tokens_from_cluster(session)
    except Exception:
        print("ERROR: {}".format(sys.exc_info()))
        sys.exit(1)

min_token = -pow(2, 63)
max_token = pow(2, 63) - 1
token2node = {}

for node, tokens in node2tokens.items():
    for token in tokens:
        token2node[token] = node

sorted_tokens = []
for tkns in node2tokens.values():
    sorted_tokens += tkns

sorted_tokens.sort()
print("Owner of the left-most token: {}".format(token2node[sorted_tokens[0]]))

nodes_ranges = {}
for node in node2tokens.keys():
    nodes_ranges[node] = []

# First, add special token ranges to the owner of the smallest token
nodes_ranges[token2node[sorted_tokens[0]]].append([min_token, sorted_tokens[0]])
nodes_ranges[token2node[sorted_tokens[0]]].append([sorted_tokens[-1], max_token])

# Right boundary token owner owns the range
for i, token in reversed(list(enumerate(sorted_tokens))):
    if i > 0:
        nodes_ranges[token2node[token]].append([sorted_tokens[i-1], token])

node2num_tokens = {}

for node, ranges in nodes_ranges.items():
    node2num_tokens[node] = sum([r - l - 1 for l, r in ranges])

total = sum(node2num_tokens.values())
average = int(total / len(node2num_tokens))

all_ranges_sizes = [r - l - 1 for l, r in ranges for node, ranges in nodes_ranges.items()]
all_ranges_sizes_average = statistics.mean(all_ranges_sizes)
all_ranges_sizes_stdev = statistics.pstdev(all_ranges_sizes, mu=all_ranges_sizes_average)

# Sort by the amount of owned tokens
sorted_node2num_tokens = sorted(node2num_tokens.items(), key=lambda p: p[1])

for node, num_tokens in reversed(sorted_node2num_tokens):
    node_ranges = [r - l - 1 for l, r in nodes_ranges[node]]
    node_average = node2num_tokens[node] / len(node_ranges)
    node_cv = statistics.pstdev(node_ranges, mu=node_average) / node_average

    print("{}: ranges: {} tokens: {}({}%) CV: {}%".format(node, len(node2tokens[node]), num_tokens, round(100 * num_tokens / total, 2), round(100 * node_cv, 2)))

print("average: {}({}%)".format(average, round(100 * average / total, 2)))
print("CV: {}%".format(round(100 * all_ranges_sizes_stdev / all_ranges_sizes_average, 2)))




# for k in node2tokens.keys():
#     print("{}:{}".format(k, node2tokens[k]))
