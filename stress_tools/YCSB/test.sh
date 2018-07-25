#!/bin/bash

export YCSB_HOME=/home/ubuntu/YCSB
export DYNAMODB_HOME=$YCSB_HOME/dynamodb

OUTPUT_BASE=$PWD
NUM_INSTANCES=8
SCYLLA_HOST="172.16.0.30"
SCYLLA_USER="centos"

LOAD_RECORD_COUNT=80000000
TARGET_RATE=120000

A_UNI_REC_COUNT=$LOAD_RECORD_COUNT
PER_HOST_CONNETIONS=16
A_UNI_THREADS=50 #??? Limit the rate instead
SCYLLA_COMMON_PARAMS="-p maxexecutiontime=5400 -threads $A_UNI_THREADS -p cassandra.writeconsistencylevel=QUORUM -p cassandra.coreconnections=$(( PER_HOST_CONNETIONS / 2 )) -p cassandra.maxconnections=$PER_HOST_CONNETIONS"
A_UNI_COMMON_SCYLLA_PARAMS="$SCYLLA_COMMON_PARAMS -target $(( TARGET_RATE / NUM_INSTANCES ))"
LOAD_COMMON_SCYLLA_PARAMS="$SCYLLA_COMMON_PARAMS -target $(( TARGET_RATE / (NUM_INSTANCES * 2) ))"

intr_handler()
{
    echo "stopping java..."
    pkill -9 java
    cd $OUTPUT_BASE
    exit 1
}

#
#  workload <workload phase, e.g. "run" or "load"> <db type> <host> <total records> <op count> <insert count> <workload> <output prefix> <extra params>
#
workload()
{
    local workload_phase="$1"
    shift
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

    local host_param=""

    [[ -n "$host" ]] && host_param="-p hosts=$host"

    local one_client_op_count=$(( total_records / NUM_INSTANCES ))
    local start
    local cmd="./bin/ycsb $workload_phase $db_type $host_param $extra_ld_params -P $workload -s"
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

load_data_scylla()
{
	# Create the KS.CF first
	echo "Creating a KS..."
	if ! ssh $SCYLLA_USER@$SCYLLA_HOST "cqlsh -e \"CREATE KEYSPACE IF NOT EXISTS ycsb WITH REPLICATION = {'class' : 'SimpleStrategy', 'replication_factor' : 3} ;\""; then
	    echo "Failed to create a KS"
	    exit 1
	fi

	echo "Creating a CF..."
	if ! ssh $SCYLLA_USER@$SCYLLA_HOST "cqlsh -e \"create table if not exists ycsb.usertable ( y_id varchar, field0 varchar, field1 varchar, field2 varchar, field3 varchar, field4 varchar, field5 varchar, field6 varchar, field7 varchar, field8 varchar, field9 varchar, PRIMARY KEY(y_id));\""; then
	    echo "Failed to create a CF"
	    exit 1
	fi

    workload "load" "cassandra-cql" "$SCYLLA_HOST" "$LOAD_RECORD_COUNT" "$(( LOAD_RECORD_COUNT / NUM_INSTANCES ))" "$(( LOAD_RECORD_COUNT / NUM_INSTANCES ))" "workloads/workloada" "load-scylla" $LOAD_COMMON_SCYLLA_PARAMS
}

DYNAMO_COMMON_PARAMS="-p maxexecutiontime=5400 -threads $A_UNI_THREADS -P dynamodb/conf/dynamodb.properties"
A_UNI_COMMON_DYNAMO_PARAMS="$DYNAMO_COMMON_PARAMS -target $(( TARGET_RATE / NUM_INSTANCES ))"
LOAD_COMMON_DYNAMO_PARAMS="$DYNAMO_COMMON_PARAMS -target $(( TARGET_RATE / (NUM_INSTANCES * 2) ))"
SP_COMMON_DYNAMO_PARAMS="$DYNAMO_COMMON_PARAMS -target 1000"

load_data_dynamo()
{
    workload "load" "dynamodb" "" "$LOAD_RECORD_COUNT" "$(( LOAD_RECORD_COUNT / NUM_INSTANCES ))" "$(( LOAD_RECORD_COUNT / NUM_INSTANCES ))" "workloads/workloada" "load-dynamo" $LOAD_COMMON_DYNAMO_PARAMS
}

workloadA_uniform_scylla()
{
    workload "run" "cassandra-cql" "$SCYLLA_HOST" "$A_UNI_REC_COUNT" "$(( A_UNI_REC_COUNT / NUM_INSTANCES ))" "$(( A_UNI_REC_COUNT / NUM_INSTANCES ))" "workloads/workloada" "wA-uni-scylla" $A_UNI_COMMON_SCYLLA_PARAMS
}

workloadA_zipifian_scylla()
{
    workload "run" "cassandra-cql" "$SCYLLA_HOST" "$A_UNI_REC_COUNT" "$(( A_UNI_REC_COUNT / NUM_INSTANCES ))" "$(( A_UNI_REC_COUNT / NUM_INSTANCES ))" "workloads/workloada" "wA-zipifian-scylla" $A_UNI_COMMON_SCYLLA_PARAMS -p hotspotdatafraction=0.2 -p hotspotopnfraction=0.8 -p requestdistribution=zipfian
}

workloadA_single_partition_scylla()
{
    workload "run" "cassandra-cql" "$SCYLLA_HOST" 100000 "$(( A_UNI_REC_COUNT / NUM_INSTANCES ))" 1 "workloads/workloada" "wA-uni-single-part-scylla" $A_UNI_COMMON_SCYLLA_PARAMS
}

workloadA_single_partition_dynamo()
{
    workload "run" "dynamodb" "" 100000 "$(( A_UNI_REC_COUNT / NUM_INSTANCES ))" 1 "workloads/workloada" "wA-uni-single-part-dynamo" $A_UNI_COMMON_DYNAMO_PARAMS
}

workloadA_zipifian_dynamo()
{
    workload "run" "dynamodb" "" "$A_UNI_REC_COUNT" "$(( A_UNI_REC_COUNT / NUM_INSTANCES ))" "$(( A_UNI_REC_COUNT / NUM_INSTANCES ))" "workloads/workloada" "wA-zipifian-dynamo" $A_UNI_COMMON_DYNAMO_PARAMS -p hotspotdatafraction=0.2 -p hotspotopnfraction=0.8 -p requestdistribution=zipfian
}


########################################################################################################################
test_mode="$1"

trap 'intr_handler' INT TERM

case "$test_mode" in
"l_s")
	load_data_scylla
	;;
"l_d")
	load_data_dynamo
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
"sp_d")
	workloadA_single_partition_dynamo
	;;
*)
	echo "Bad test mode: $test_mode"
	;;
esac
