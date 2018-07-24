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
#  workload <db type> <host> <total records> <op count> <insert count> <workload> <output prefix> <extra params>
#
workload()
{
    local db_type="$1"
    shift
    local host="$1"
    shift
    local total_records="$1"
    shift
    local op_count="$1"
    shift
    local insert_count="$1"
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
		inst_cmd="$cmd -p recordcount=$total_records -p insertstart=$start -p insertcount=$insert_count -p operationcount=$op_count"
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
    workload "cassandra-cql" "$SCYLLA_HOST" "$A_UNI_REC_COUNT" "$(( A_UNI_REC_COUNT / NUM_INSTANCES ))" "$(( A_UNI_REC_COUNT / NUM_INSTANCES ))" "workloads/workloada" "wA-uni-scylla" $A_UNI_COMMON_SCYLLA_PARAMS
}

workloadA_zipifian_scylla()
{
    workload "cassandra-cql" "$SCYLLA_HOST" "$A_UNI_REC_COUNT" "$(( A_UNI_REC_COUNT / NUM_INSTANCES ))" "$(( A_UNI_REC_COUNT / NUM_INSTANCES ))" "workloads/workloada" "wA-zipifian-scylla" $A_UNI_COMMON_SCYLLA_PARAMS -p hotspotdatafraction=0.2 -p hotspotopnfraction=0.8 -p requestdistribution=zipfian
}

workloadA_single_partition_scylla()
{
    workload "cassandra-cql" "$SCYLLA_HOST" 100000 "$(( A_UNI_REC_COUNT / NUM_INSTANCES ))" 1 "workloads/workloada" "wA-uni-single-part-scylla" $A_UNI_COMMON_SCYLLA_PARAMS
}


########################################################################################################################
test_mode="$1"

trap 'intr_handler' INT TERM

case "$test_mode" in
"l_s")
	load_data_scylla
	;;
"u_s")
	workloadA_uniform_scylla
	;;
"z_s")
	workloadA_zipifian_scylla
	;;
"sp_s")
	workloadA_single_partition_scylla
	;;
*)
	echo "Bad test mode: $test_mode"
	;;
esac
