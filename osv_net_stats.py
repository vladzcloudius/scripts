#!/usr/bin/env python3
# !
# ! Usage: osv_net_stats.py <Guest IP> <NIC>
# !

import urllib.request
import json
import time
import sys
import collections
import signal
import os

#
# get_stats
#
# Creates a map with the values that we need
def get_stats ():
    result_json = urllib.request.urlopen('http://' + guest_ip + ':8000/network/ifconfig/' + nic).read().decode()
    result = json.loads(result_json)
    out = {}
    out['tx_q_is_full']         = result['data']['ifi_oqueue_is_full']
    out['tx_kicks']             = result['data']['ifi_okicks']
    out['tx_packets']           = result['data']['ifi_opackets']
    out['rx_bh_wakeups']        = result['data']['ifi_ibh_wakeups']
    out['rx_packets']           = result['data']['ifi_ipackets']
    out['tx_worker_wakeups']    = result['data']['ifi_oworker_wakeups']
    out['tx_worker_packets']    = result['data']['ifi_oworker_packets']
    out['tx_worker_kicks']      = result['data']['ifi_oworker_kicks']

    return out

#
# print_div a b <field width>
#
# Prints the result of a/b
def print_div(a, b):
    if b != 0:
        print("%.2f" % (a / b), end='')
    else:
        print("nan", end='')

#
# print_ratio <Prefix> <"a" description> <"a" key> <"b" description> <"b" key>
#
def print_ratio (prefix, a_descr, a_key, b_descr, b_key):
    print("%s%-40s :%d(+%d)" % (prefix, a_descr, stats[a_key], \
                                (stats1[a_key] - stats[a_key])))
    print("%s%-40s :%d(+%d)" % (prefix, b_descr, stats[b_key], \
                                (stats1[b_key] - stats[b_key])))
    print("---------------------------------------------------------------------")
    #print("%s" % prefix + "%-40s :" % "Ratio", end='')
    print("%s%-40s :" % (prefix, "Ratio"), end='')
    print_div(stats1[a_key], stats1[b_key])
    print("(", end='')
    print_div(stats1[a_key] - stats[a_key], stats1[b_key] - stats[b_key])
    print(")", end='\n\n')

#
#  Python back trace silencer
#
def signal_handler(signal, frame):
    sys.exit(0)

################################################################################
if len(sys.argv) != 3:
    os.system("cat " + sys.argv[0] + " | grep ^\"# !\" | cut -d\"!\" -f2-");
    sys.exit(1)

guest_ip = sys.argv[1]
nic      = sys.argv[2]

signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)
signal.signal(signal.SIGHUP, signal_handler)

################################################################################
stats = get_stats()

while True:
    stats1 = get_stats()

    os.system('clear')
    #####################
    print_ratio('Rx: ', 'packets', 'rx_packets', 'bh_wakeups', 'rx_bh_wakeups')
    #####################
    print_ratio('Tx: ', 'packets', 'tx_packets', 'kicks', 'tx_kicks')
    #####################
    print_ratio('Tx: ', 'worker packets', 'tx_worker_packets', 'worker kicks', 'tx_worker_kicks')
    #####################
    print_ratio('Tx: ', 'worker packets', 'tx_worker_packets', 'worker wakeups', 'tx_worker_wakeups')
    #####################
    print_ratio('Tx: ', 'queue is full', 'tx_q_is_full', 'packets', 'tx_packets')

    stats = stats1
    time.sleep(1)
