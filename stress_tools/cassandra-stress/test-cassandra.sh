#!/bin/bash

USER=$1
SCYLLA_HOST=$2
test_mode=$3

#USER=root
#SCYLLA_HOST_INTERNAL=10.100.53.133

# SCYLLA_HOST=( 147.75.107.46 147.75.107.30 147.75.193.234 )
# SCYLLA_HOST_INTERNAL=( 10.100.53.133 10.100.53.131 10.100.53.129 )
#SCYLLA_HOST=147.75.107.46
#test_mode=$2

STRESS_NUM=14
#NUM_KEYS=18000000
NUM_KEYS=9000000
#NUM_KEYS=400000
#NUM_KEYS=250000
#SCYLLA_HOST=192.168.129.14
#SCYLLA_HOST=10.13.104.5
#SCYLLA_HOST=10.13.100.22
NUM_THREADS=100
OUT_BASE=$PWD
NUM_CORES=152
CORE_START=8
CORES_PER_INST=$((NUM_CORES / STRESS_NUM))
LOADERS=( 10.13.104.9 10.13.104.8 )
#LOADERS=( 10.13.104.9 )
ITERATIONS=1
POP_WIDTH=$NUM_KEYS
#RATE_LIMIT="fixed=80000/s"
RATE_LIMIT=""
#POP_WIDTH=$NUM_KEYS
SSH_CMD="ssh $USER"
SSH_LOADER_CMD="ssh user1"
#SCYLLA_START_CMD=`$SSH_CMD@$SCYLLA_HOST cat /home/$USER/scylla-ccm/start_cmd.txt`
CS_CMD="/home/user1/scylla-tools-java/tools/bin/cassandra-stress"
#CS_CMD="/home/user1/cassandra/tools/bin/cassandra-stress"

get_server_latencies()
{
	local test_type=$1
	local itn=$2
	local i
	for ((i = 0; i < ${#LOADERS[@]}; i++))
	do
		$SSH_CMD@$SCYLLA_HOST /home/$USER/scylla-tools-java/bin/nodetool cfhistograms ks$i standard1 > $OUT_BASE/$test_type-server-latencies-$itn-$i.txt 2>&1
	done
}

CS_PARAMS()
{
	local ks_id=$1
	local it_id=$2
	local nthreads=$3
	local num_itarations=$4
	echo "no-warmup n=$num_itarations -node $SCYLLA_HOST -rate threads=$nthreads $RATE_LIMIT -mode native cql3 -pop seq=$((1+POP_WIDTH*it_id))..$((POP_WIDTH*(it_id+1))) -schema keyspace=ks$ks_id replication\(strategy=NetworkTopologyStrategy, datacenter1=1\)"
}

stress_write_cmd()
{
	local ks_id=$1
	local it_id=$2
	local nthreads=$3
	local num_itarations=$4
	echo "$CS_CMD write $(CS_PARAMS $ks_id $it_id $nthreads $num_itarations)"
}

stress_read_cmd()
{
    local ks_id=$1
    local it_id=$2
    echo "$CS_CMD read $(CS_PARAMS $ks_id $it_id $NUM_THREADS $NUM_KEYS)"
}

stress_mixed_cmd()
{
    local ks_id=$1
    local it_id=$2
    echo "$CS_CMD mixed ratio\(write=2,read=8\) $(CS_PARAMS $ks_id $it_id $NUM_THREADS $NUM_KEYS)"
}


clear_and_restart()
{
	local i=1
	echo "$SCYLLA_HOST: Stopping cassandra..."
	$SSH_CMD@$SCYLLA_HOST "pkill java" &> /dev/null
	while `$SSH_CMD@$SCYLLA_HOST ps -elf | grep java | grep cassandra | grep -v grep` &> /dev/null
	do
		echo "Waiting $i..."
		sleep 1
		let "i++"
	done

	echo "$SCYLLA_HOST: Clearing data..."
	$SSH_CMD@$SCYLLA_HOST "cd /home/$USER/ccm; ccm clear" &> /dev/null
	
	echo "$SCYLLA_HOST: Starting cassandra..."
	$SSH_CMD@$SCYLLA_HOST "cd /home/$USER/ccm; ccm start --wait-for-binary-proto" &> /dev/null
}

restart_scylla()
{
        local i=1
        echo "$SCYLLA_HOST: Stopping cassandra..."
        $SSH_CMD@$SCYLLA_HOST "cd /home/$USER/ccm; ccm stop" &> /dev/null
        while `$SSH_CMD@$SCYLLA_HOST ps -elf | grep java | grep cassandra | grep -v grep` &> /dev/null
        do 
                echo "Waiting $i..." 
                sleep 1  
                let "i++" 
        done 
 
        echo "$SCYLLA_HOST: Starting cassandra..."
        $SSH_CMD@$SCYLLA_HOST "cd /home/$USER/ccm; ccm start --wait-for-binary-proto" &> /dev/null
}


test_write()
{
	local iterations=$1
	echo "Write test. $iterations iterations..."
	local i
	local itn
	local loader
	local ld
#	local total_stress_inst=$((STRESS_NUM*${#LOADERS[@]}))
	for ((itn=0; itn < iterations; itn++))
	do
	    echo -e "Iteration $itn..."
	    clear_and_restart

            # Create the KS with a short single thread WRITE
            for ((ld = 0; ld < ${#LOADERS[@]}; ld++))
            do
                echo "${LOADERS[$ld]}: $(stress_write_cmd $ld 0 1 1000)"
                $SSH_LOADER_CMD@${LOADERS[$ld]} "$(stress_write_cmd $ld 0 1 1000)"
            done

            local j=0

            for ((ld = 0; ld < ${#LOADERS[@]}; ld++))
	    do
                for ((i = 0; i < STRESS_NUM; i++))
                do
                    echo "${LOADERS[$ld]}: taskset -c $((CORE_START + i * CORES_PER_INST))-$((CORE_START + (i+1) * CORES_PER_INST - 1)) $(stress_write_cmd $ld $i $NUM_THREADS $NUM_KEYS)" > $OUT_BASE/write-out-$itn-$j.txt
                    $SSH_LOADER_CMD@${LOADERS[$ld]} "taskset -c $((CORE_START + i * CORES_PER_INST))-$((CORE_START + (i+1) * CORES_PER_INST - 1)) $(stress_write_cmd $ld $i $NUM_THREADS  $NUM_KEYS)" >> $OUT_BASE/write-out-$itn-$j.txt 2>&1 &
                    echo "starting write test instance $j..."
                    sleep 0.1
                    j=$((j+1))
                done
            done
            wait
            get_server_latencies write $itn
	done
}

test_read()
{
	echo "Read test. $ITERATIONS iterations..."
	local rd_from_disk="$1"
	local i
	local j
	local itn
	local ld 
	for ((itn=0; itn < ITERATIONS; itn++))
        do
		j=0
		echo -e "Iteration $itn..."
		[[ -n "$rd_from_disk" ]] && restart_scylla
		for ((ld = 0; ld < ${#LOADERS[@]}; ld++))
		do
        	    for ((i = 0; i < STRESS_NUM; i++))
	            do
	                echo "${LOADERS[$ld]}: taskset -c $((CORE_START + i * CORES_PER_INST))-$((CORE_START + (i+1) * CORES_PER_INST - 1)) $(stress_read_cmd $ld $i)" > $OUT_BASE/read-out-$itn-$j.txt
        	        $SSH_LOADER_CMD@${LOADERS[$ld]} "taskset -c $((CORE_START + i * CORES_PER_INST))-$((CORE_START + (i+1) * CORES_PER_INST - 1)) $(stress_read_cmd $ld $i)" >> $OUT_BASE/read-out-$itn-$j.txt 2>&1 &
			echo "starting read test instance $j..."
			sleep 0.1
			j=$((j+1))
	            done
		done
        	wait
		get_server_latencies read $itn
	done
}

test_mixed()
{ 
        echo "Mixed (2 writes 8 read) test. $ITERATIONS iterations..."
        local rd_from_disk="$1"
        local i
	local j
        local itn
	local ld
        for ((itn=0; itn < ITERATIONS; itn++))
        do
		j=0 
                echo -e "Iteration $itn..."
		test_write 1
                [[ -n "$rd_from_disk" ]] && restart_scylla
		for ((ld = 0; ld < ${#LOADERS[@]}; ld++))
                do
                    for ((i = 0; i < STRESS_NUM; i++))
                    do
                        echo "${LOADERS[$ld]}: taskset -c $((CORE_START + i * CORES_PER_INST))-$((CORE_START + (i+1) * CORES_PER_INST - 1)) $(stress_mixed_cmd $ld $i)" > $OUT_BASE/mixed-out-$itn-$j.txt
                        $SSH_LOADER_CMD@${LOADERS[$ld]} "taskset -c $((CORE_START + i * CORES_PER_INST))-$((CORE_START + (i+1) * CORES_PER_INST - 1)) $(stress_mixed_cmd $ld $i)" >> $OUT_BASE/mixed-out-$itn-$j.txt 2>&1 &
                        echo "starting mixed test instance $j..."
			sleep 0.1
                        j=$((j+1))
                    done
		done
                wait
		get_server_latencies mixed $itn
        done
} 


test_read_from_disk()
{
	test_read rd
}

intr_handler()
{
    for loader in ${LOADERS[@]}
    do
        echo "$loader: stopping java..."
        $SSH_LOADER_CMD@$loader "pkill java"
    done
    exit 1
}

trap 'intr_handler' INT TERM

case "$test_mode" in
"r") 
	test_read
	;;
"rd") 
	test_read_from_disk
	;;
"w")
	test_write $ITERATIONS
	;;
"wr")
	test_write $ITERATIONS
	test_read
	;;
"mx")
	test_mixed
	;;
"mxd")
	test_mixed rd
	;;
*)
	echo "Bad test mode: $test_mode"
	;;
esac



