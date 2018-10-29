#!/bin/bash

get_one_result()
{
        local fname=$1
        shift
        local pattern="$@"

        local res=$(grep -i "$pattern" $fname)
        [[ -z "$res" ]] && return 1
        echo $(echo $res | cut -d":" -f2 ) | cut -d" " -f1 | tr -d ','
}

total()
{
	local fname_prefix=$1
	shift
	local pattern="$@"
	local i
	local sum
	local files_count0=0
	local files_count=0
	local fname

	for (( i = 0; i < ITERATIONS_NUMBER; i++ ))
	do
		sum=0
		files_count=0
		local bad_file=""
		for fname in $fname_prefix-$i-*.txt
		do
			if (( i == 0 )); then
				files_count0=$(( files_count0 + 1 ))
			else
				files_count=$(( files_count + 1 ))
			fi
			[[ -n "$bad_file" ]] && continue
                        local cur_val=$(get_one_result $fname $pattern)
                        if [[ -z "$cur_val" ]]; then
                                bad_file="1"
                                continue
                        fi

                        sum=$(echo "scale=2; $sum + $cur_val" | bc)
		done

		if (( i != 0 )) && (( files_count != files_count0 ));  then
			echo "Bad test set for $fname_prefix: number of files in iteration 0: $files_count0 and in iteration $i: $files_count"
			exit 1
		fi

		[[ -n "$bad_file" ]] && sum=0
		echo $sum
	done

	echo "$files_count0"
}

max()
{
	local fname_prefix=$1
	shift
	local pattern="$@"
	local i
	local max_val
	local files_count0=0
	local files_count=0
	local fname

	for (( i = 0; i < ITERATIONS_NUMBER; i++ ))
	do
		max_val=0
		files_count=0
		local bad_file=""
		for fname in $fname_prefix-$i-*.txt
		do
			if (( i == 0 )); then
				files_count0=$(( files_count0 + 1 ))
			else
				files_count=$(( files_count + 1 ))
			fi

			[[ -n "$bad_file" ]] && continue
                        local new_val=$(get_one_result $fname $pattern)
                        if [[ -z "$new_val" ]]; then
                                bad_file="1"
                                continue
                        fi

                        if (( $(echo "$max_val < $new_val" | bc) == 1 )); then
                            max_val=$new_val
                        fi

		done

		if (( i != 0 )) && (( files_count != files_count0 ));  then
			echo "Bad test set for $fname_prefix: number of files in iteration 0: $files_count0 and in iteration $i: $files_count"
			exit 1
		fi

		[[ -n "$bad_file" ]] && max_val=0
		echo $max_val
	done

	echo "$files_count0"
}

declare -r RESULTS_DIR1=$1
declare -r RESULTS_DIR2=$2
declare -r MARKER1=$3
declare -r MARKER2=$4
declare -r ITERATIONS_NUMBER=$5

get_rate_resutls()
{
    local test_type=$1
    shift
    local pattern="$@"
    local rate_orig=( `total $RESULTS_DIR1/${test_type}-out "$pattern"` )
    local rate_new=( `total $RESULTS_DIR2/${test_type}-out "$pattern"` )

    if (( ${rate_orig[$ITERATIONS_NUMBER]} != ${rate_new[$ITERATIONS_NUMBER]} )); then
    	echo "Bad test set for write_test: number of loaders in orig: ${rate_orig[$ITERATIONS_NUMBER]} and in new: ${rate_new[$ITERATIONS_NUMBER]}"
    fi

    echo "$test_type $pattern,$MARKER1,$MARKER2"
    for ((i=0; i < ITERATIONS_NUMBER; i++))
    do
    	echo ",${rate_orig[$i]},${rate_new[$i]}"
    done

    echo ",,"
    echo ",,"
    echo ",,"
#    echo ",,"
#    echo ",,"
}

get_average_resutls()
{
    local test_type=$1
    shift
    local pattern="$@"
    local rate_orig=( `total $RESULTS_DIR1/${test_type}-out "$pattern"` )
    local rate_new=( `total $RESULTS_DIR2/${test_type}-out "$pattern"` )

    if (( ${rate_orig[$ITERATIONS_NUMBER]} != ${rate_new[$ITERATIONS_NUMBER]} )); then
    	echo "Bad test set for write_test: number of loaders in orig: ${rate_orig[$ITERATIONS_NUMBER]} and in new: ${rate_new[$ITERATIONS_NUMBER]}"
    fi

    echo "$test_type $pattern,$MARKER1,$MARKER2"
    for ((i=0; i < ITERATIONS_NUMBER; i++))
    do
        rate_orig[$i]=$(echo "scale=2; ${rate_orig[$i]} / ${rate_orig[$ITERATIONS_NUMBER]}" | bc)
        rate_new[$i]=$(echo "scale=2; ${rate_new[$i]} / ${rate_orig[$ITERATIONS_NUMBER]}" | bc)

    	echo ",${rate_orig[$i]},${rate_new[$i]}"
    done

    echo ",,"
    echo ",,"
    echo ",,"
 #   echo ",,"
 #   echo ",,"
}

get_max_resutls()
{
    local test_type=$1
    shift
    local pattern="$@"
    local rate_orig=( `max $RESULTS_DIR1/${test_type}-out "$pattern"` )
    local rate_new=( `max $RESULTS_DIR2/${test_type}-out "$pattern"` )

    if (( ${rate_orig[$ITERATIONS_NUMBER]} != ${rate_new[$ITERATIONS_NUMBER]} )); then
    	echo "Bad test set for write_test: number of loaders in orig: ${rate_orig[$ITERATIONS_NUMBER]} and in new: ${rate_new[$ITERATIONS_NUMBER]}"
    fi

    echo "$test_type $pattern,$MARKER1,$MARKER2"
    for ((i=0; i < ITERATIONS_NUMBER; i++))
    do
    	echo ",${rate_orig[$i]},${rate_new[$i]}"
    done

    echo ",,"
    echo ",,"
    echo ",,"
  #  echo ",,"
  #  echo ",,"
}


