#!/bin/bash

OUTPUT_BASE=$PWD
NUM_INSTANCES=16
SCYLLA_HOST="172.16.0.80"

LOAD_RECORD_COUNT=160000000 
ONE_CLIENT_LOAD_RECORDS=$(( LOAD_RECORD_COUNT / NUM_INSTANCES ))
LOAD_THREADS_COUNT=400
YCSB_LOAD_COMMON_PARAMS="-p recordcount=$LOAD_RECORD_COUNT -s -P workloads/workloada -threads $LOAD_THREADS_COUNT"

intr_handler()
{
    echo "stopping java..."
    pkill -9 java
    cd $OUTPUT_BASE
    exit 1
}

load_data_scylla()
{
	local start
	local cmd="./bin/ycsb load cassandra-cql -p hosts=$SCYLLA_HOST -p cassandra.writeconsistencylevel=QUORUM $YCSB_LOAD_COMMON_PARAMS"
	local log_file_name
	local inst_cmd

	cd ~/YCSB
	for ((i=0; i < NUM_INSTANCES; i++))
	do 
		start=$(( i * ONE_CLIENT_LOAD_RECORDS ))
		inst_cmd="$cmd -p insertstart=$start -p insertcount=$ONE_CLIENT_LOAD_RECORDS"
		log_file_name="$OUTPUT_BASE/load-out-$i.txt"
		
		echo "Starting loader $i..."
		echo "$inst_cmd" > $log_file_name 2>&1
		$inst_cmd >> $log_file_name 2>&1 &
	done
	wait
	cd -
}

#
#  workload <db type> <host> <total records> <workload> <output prefix> <extra params>
#
workload()
{
    local db_type="$1"
    shift
    local host="$1"
    shift
    local total_records="$1"
    shift
    local workload="$1"
    shift
    local fname_prefix="$1"
    shift
    local extra_ld_params="$@"

    local one_client_op_count=$(( total_records / NUM_INSTANCES ))
	local start
    local cmd="./bin/ycsb run $db_type -p hosts=$host $extra_ld_params -P $workload -s"
    local log_file_name
    local inst_cmd

    cd ~/YCSB
    for ((i=0; i < NUM_INSTANCES; i++))
    do
		start=$(( i * one_client_op_count ))
		inst_cmd="$cmd -p recordcount=$total_records -p insertstart=$start -p insertcount=$one_client_op_count -p operationcount=$one_client_op_count"
		log_file_name="$OUTPUT_BASE/$fname_prefix-out-$i.txt"

		echo "Starting test instance $i..."
		echo "$inst_cmd" > $log_file_name 2>&1
		$inst_cmd >> $log_file_name 2>&1 &
    done
    wait
    cd -
}

#A_UNI_REC_COUNT=1000000000
A_UNI_REC_COUNT=$LOAD_RECORD_COUNT
A_UNI_THREADS=35 #??? Limit the rate instead
A_UNI_COMMON_SCYLLA_PARAMS="-p maxexecutiontime=5400 -threads $A_UNI_THREADS -p cassandra.writeconsistencylevel=QUORUM"

workloadA_uniform_scylla()
{
    workload "cassandra-cql" "$SCYLLA_HOST" "$A_UNI_REC_COUNT" "workloads/workloada" "wA-uni-scylla-out" $A_UNI_COMMON_SCYLLA_PARAMS
}


########################################################################################################################
trap 'intr_handler' INT TERM
workloadA_uniform_scylla