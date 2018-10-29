#!/bin/bash

. $(dirname $0)/get_results_lib.sh

get_rate_resutls "mixed" "op rate"

get_average_resutls "mixed" "latency mean"

get_max_resutls "mixed" "latency 95th"

get_max_resutls "mixed" "latency 99th"

get_max_resutls "mixed" "latency 99.9th"

get_max_resutls "mixed" "latency max"

#get_average_resutls "mixed" "latency max"

