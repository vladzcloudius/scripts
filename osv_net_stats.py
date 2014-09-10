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
    result_json = urllib.request.urlopen('http://' + guest_ip + \
                                         ':8000/network/ifconfig/' + \
                                         nic).read().decode()
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

    rx_wakeup_stats = {}
    tx_wakeup_stats = {}

    rx_wakeup_stats = result['data']['ifi_iwakeup_stats']
    tx_wakeup_stats = result['data']['ifi_owakeup_stats']

    return (out, tx_wakeup_stats, rx_wakeup_stats)

#
# print_div a b
#
# Returns a string with (a / b) value truncated to 2 signs after the point or
# 'nan' if b equals to 0.
def div_str(a, b):
    val_str = ""
    if b != 0:
        val_str = "{0}".format(round(a / b, 2))
    else:
        val_str = 'nan'

    return val_str

#
# print_ratio <Prefix> <"a" description> <"a" key> <"b" description> <"b" key>
#
def print_ratio (prefix, a_descr, a_key, b_descr, b_key):
    dif_str = "(+{0})".format(stats1[a_key] - stats[a_key])
    print("%s%-25s :%-10d%14s" % (prefix, a_descr, stats[a_key], dif_str))

    dif_str = "(+{0})".format(stats1[b_key] - stats[b_key])
    print("%s%-25s :%-10d%14s" % (prefix, b_descr, stats[b_key], dif_str))
    print("---------------------------------------------------------------------")

    print("%s%-25s :" % (prefix, "Ratio"), end='')

    val_str = div_str(stats1[a_key], stats1[b_key])
    print("%-10s" % val_str, end='')

    val_str = div_str(stats1[a_key] - stats[a_key], \
                      stats1[b_key] - stats[b_key])
    val_str = "({0})".format(val_str)
    print("%14s" % val_str)

    print("")

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
(stats, tx_wakeup_stats, rx_wakeup_stats) = get_stats()

while True:
    (stats1, tx_wakeup_stats1, rx_wakeup_stats1) = get_stats()

    os.system('clear')
    #####################
    print_ratio('Rx: ', 'packets', 'rx_packets', 'bh_wakeups', 'rx_bh_wakeups')
    #####################
    print_ratio('Tx: ', 'packets', 'tx_packets', 'kicks', 'tx_kicks')
    #####################
    print_ratio('Tx: ', 'worker packets', 'tx_worker_packets', \
                'worker kicks', 'tx_worker_kicks')
    #####################
    print_ratio('Tx: ', 'worker packets', 'tx_worker_packets', \
                'worker wakeups', 'tx_worker_wakeups')
    #####################
    print_ratio('Tx: ', 'queue is full', 'tx_q_is_full', 'packets', \
                'tx_packets')

    print("%-30s%-30s" % ('Rx wakeups for >X packets', \
                          'Tx wakeups for >X packets'))
    for i in ['8', '16', '64', '128', '256']:
        key = 'packets_' + i
        rx_dif_str = "(+{0})".format(rx_wakeup_stats1[key] - \
                                     rx_wakeup_stats[key])
        print("%3s:%-10d%11s" % (i, rx_wakeup_stats1[key], rx_dif_str), end='')

        tx_dif_str = "(+{0})".format(tx_wakeup_stats1[key] - \
                                     tx_wakeup_stats[key])
        print("     %-13d%12s" % (tx_wakeup_stats1[key], tx_dif_str))

    (stats, tx_wakeup_stats, rx_wakeup_stats) = \
                                    (stats1, tx_wakeup_stats1, rx_wakeup_stats1)
    time.sleep(1)
