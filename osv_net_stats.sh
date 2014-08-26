#!/bin/bash
# !
# ! Usage: osv_net_stats.sh <Guest IP> <NIC> 
# !

################################################################################
# 
# print_div a b <field width>
#
# Prints the result of a/b
print_div()
{
    local a=$1
    local b=$2
    local width=$3

    if [[ $b -ne 0 ]]; then
            local res=$(echo "$a/$b" | bc -l)
            printf "%$width.2f" $res
    else
            echo -n "nan"
    fi
}

#
# print_ratio <"a" name> <"a" var name> <"b" name> <"b" var name>
#
print_ratio()
{
    local a_name=$1
    local a_var_name=$2
    local b_name=$3
    local b_var_name=$4

    printf "%-40s / %-40s = " "$a_name($((a_var_name))(+$((a_var_name-${a_var_name}1))))" "$b_name($((b_var_name))(+$((b_var_name-${b_var_name}1))))"
    print_div $((a_var_name)) $((b_var_name)) 15
    echo -n "("
    print_div $((a_var_name-${a_var_name}1)) $((b_var_name-${b_var_name}1)) 0
    echo ")"
}
################################################################################
if [[ $# -ne 2 ]]; then
	cat $0 | grep ^"# !" | cut -d"!" -f2-
	exit 1
fi

GUEST_IP=$1
NIC=$2

oqueue_is_full=0
okicks=0
opackets=0
ibh_wakeups=0
ipackets=0
oworker_wakeups=0
oworker_packets=0
oworker_kicks=0

while [[ 1 ]]
do
    oqueue_is_full1=${COUNTERS[0]}
    okicks1=${COUNTERS[1]}
    opackets1=${COUNTERS[2]}
    ibh_wakeups1=${COUNTERS[3]}
    ipackets1=${COUNTERS[4]}
    oworker_wakeups1=${COUNTERS[5]}
    oworker_packets1=${COUNTERS[6]}
    oworker_kicks1=${COUNTERS[7]}

    COUNTERS=( `curl -s http://${GUEST_IP}:8000/network/ifconfig/$NIC | tr ',' '\n' | egrep "worker|bh|full|packet|kick" | cut -d":" -f2- | cut -d" " -f2- | tr '\n' ' '` )

    oqueue_is_full=${COUNTERS[0]}
    okicks=${COUNTERS[1]}
    opackets=${COUNTERS[2]}
    ibh_wakeups=${COUNTERS[3]}
    ipackets=${COUNTERS[4]}
    oworker_wakeups=${COUNTERS[5]}
    oworker_packets=${COUNTERS[6]}
    oworker_kicks=${COUNTERS[7]}
    
    clear

    #####################
    echo -n "Rx: "
    print_ratio packets ipackets bh_wakeups ibh_wakeups
    #####################
    echo -n "Tx: "
    print_ratio packets opackets kicks okicks
    #####################
    echo -n "Tx: "
    print_ratio "worker packets" oworker_packets "worker kicks" oworker_kicks
    #####################
    echo -n "Tx: "
    print_ratio "worker packets" oworker_packets "worker wakeups" oworker_wakeups
    #####################
    echo -n "Tx: "
    print_ratio "queue is full" oqueue_is_full "packets" opackets

    sleep 1
done
