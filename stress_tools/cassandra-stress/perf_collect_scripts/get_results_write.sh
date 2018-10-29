#!/bin/bash

. $(dirname $0)/get_results_lib.sh

	
get_rate_resutls "write" "op rate"
#get_rate_resutls "read" "op rate"

get_average_resutls "write" "latency mean"
#get_average_resutls "read" "latency mean"

get_max_resutls "write" "latency 95th"
#get_max_resutls "read" "latency 95th"

get_max_resutls "write" "latency 99th"
#get_max_resutls "read" "latency 99th"

get_max_resutls "write" "latency 99.9th"
#get_max_resutls "read" "latency 99.9th"

get_max_resutls "write" "latency max"
#get_max_resutls "read" "latency max"

#get_average_resutls "write" "latency max"
#get_average_resutls "read" "latency max"

