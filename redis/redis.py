#!/usr/bin/env python

import sys
import time
import argparse
import subprocess
import string
import numpy
import os

argp = argparse.ArgumentParser(description =
                               'Perform redis tests set: PING, SET, GET, INCR, \
                               LPUSH, LPOP, SADD, SPOP, LRANGE_100, LRANGE_300,\
                               LRANGE_500, LRANGE_600, MSET')
argp.add_argument('--server_ip', '-s', default = '192.168.122.89', type = str,
                  help = 'Redis server IP address')
argp.add_argument('--step_time', '-t', default = 60, type = int,
                  help = 'Duration of a single test step')
argp.add_argument('--it_num', '-I', default = 1, type = int,
                  help = 'Number of each test step iterations')
argp.add_argument('--sockets', '-S', default = 1, type = int,
                  help = 'Number of redis sockets to use')
argp.add_argument('--pipelines', '-P', default = 1, type = int,
                  help = 'Number of pipelines to use')

args = argp.parse_args()

################################################################################

def adjust_runtime_factor (cmd, adjust_to_sec):
    start = time.time()
    exe = subprocess.Popen(cmd, stdout = subprocess.PIPE, stderr = subprocess.PIPE,)
    outs, errs = exe.communicate()
    #outs = str(outs, 'utf-8')
    rc = exe.wait()
    elapsed = (time.time() - start)

    if rc != 0:
        raise Exception('cmd failed', outs)


    #print("factor " + str(adjust_to_sec / elapsed))

    return adjust_to_sec / elapsed, outs

################################################################################
#if len(sys.argv) != 4:
#    os.system("cat " + sys.argv[0] + " | grep ^\"# !\" | cut -d\"!\" -f2-");
#    sys.exit(1)

#SERVER_IP = sys.argv[1]
#STEP_TIME = sys.argv[2]
#ITER      = sys.argv[3]
################################################################################

# Tests' names
tests = ['PING', 'SET', 'GET', 'INCR', 'LPUSH', 'LPOP', 'SADD', 'SPOP', \
         'LRANGE_100', 'LRANGE_300', 'LRANGE_500', 'LRANGE_600', 'MSET']

# Number of iterations to use for adjustment
adgust_it_num = 100000

cmd_line_base = ['redis-benchmark', '--csv', '-h', args.server_ip, '-c',
                 str(args.sockets), '-P', str(args.pipelines)]

results = {}
test_tags = []

for test in tests:
    test_cmd_line = cmd_line_base + ['-t', test, '-n']
    factor, outs = adjust_runtime_factor(test_cmd_line + [str(adgust_it_num)],
                                   args.step_time)
    #test_cmd_line += [str(adgust_it_num * factor)]
    it_num = adgust_it_num
    for run in range(args.it_num):
        # Drop the DB
        os.system("redis-cli -h " + args.server_ip + " flushall > /dev/null");

        # Execute a test
        it_num *= factor
        factor, outs = adjust_runtime_factor(test_cmd_line + [str(it_num)],
                                            args.step_time)

        # Check the output lines
        for line in outs.splitlines():
            # Search for the line that starts with the name of the test
            # The first item will be the test tag
            # (PING has two different tests tags)
            header = string.split(string.split(line,',')[0], '"')[1]

            if string.find(header, test) == 0:
                if not results.has_key(header):
                    results[header] = []
                    test_tags += [header]

                results[header] += [float(string.split(string.split(line,',')[1], '"')[1])]

print("Test,AVG,CV")
for test in test_tags:
    avg = numpy.average(results[test])
    stdev = numpy.std(results[test])
    print(test + ',' + str(avg) + ',' + str(100 * stdev / avg))

