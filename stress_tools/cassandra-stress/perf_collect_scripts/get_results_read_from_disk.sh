#!/bin/bash

. $(dirname $0)/get_results_lib.sh

get_rate_resutls "read" "op rate"

get_average_resutls "read" "latency mean"

get_max_resutls "read" "latency 95th"

get_max_resutls "read" "latency 99th"

get_max_resutls "read" "latency 99.9th"

get_max_resutls "read" "latency max"

#get_average_resutls "read" "latency max"

