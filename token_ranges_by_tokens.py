#!/usr/bin/env python3

import argparse
import math

argp = argparse.ArgumentParser()
argp.add_argument('--tokens-file', help='output of concatenation of SELECT peers,tokens FROM system.peers and SELECT broadcast_address,tokens FROM system.local')

args = argp.parse_args()

node2tokens = {}

with open(args.tokens_file, "r") as f:
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
print(token2node[sorted_tokens[0]])

nodes_ranges = {}
for node in node2tokens.keys():
    nodes_ranges[node] = []

# First, add special token ranges to the owner of the smallest token
nodes_ranges[token2node[sorted_tokens[0]]].append([min_token, sorted_tokens[0]])
nodes_ranges[token2node[sorted_tokens[0]]].append([sorted_tokens[-1], max_token])

# Right boundary owner owns the range
for i, token in reversed(list(enumerate(sorted_tokens))):
    if i > 0:
        nodes_ranges[token2node[token]].append([sorted_tokens[i-1], token])

# Left boundary owner own the range
# for i, token in list(enumerate(sorted_tokens)):
#     if i < len(sorted_tokens) - 1:
#         nodes_ranges[token2node[token]].append([token, sorted_tokens[i+1]])

node2num_tokens = []

for node, ranges in nodes_ranges.items():
    s = 0
    for l, r in ranges:
        s = s + r - l - 1
    node2num_tokens.append([node, s])

total = sum([s for n, s in node2num_tokens])

sorted_node2num_tokens = sorted(node2num_tokens, key=lambda p: p[1] / total)

for node, num_tokens in reversed(sorted_node2num_tokens):
    print("{}: {}({}%)".format(node, num_tokens, num_tokens / total))





# for k in node2tokens.keys():
#     print("{}:{}".format(k, node2tokens[k]))
