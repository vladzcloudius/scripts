#!/bin/bash
# !
# ! Usage: osv_net_stats.sh <Guest IP> <NIC> 
# !

if [[ $# -ne 2 ]]; then
	cat $0 | grep ^"# !" | cut -d"!" -f2-
	exit 1
fi

GUEST_IP=$1
NIC=$2

COUNTERS=( `curl -s http://${GUEST_IP}:8000/network/ifconfig/$NIC | tr ',' '\n' | egrep "worker|bh|full|packet|kick" | cut -d":" -f2- | cut -d" " -f2- | tr '\n' ' '` )
oqueue_is_full=${COUNTERS[0]}
okicks=${COUNTERS[1]}
opackets=${COUNTERS[2]}
ibh_wakeups=${COUNTERS[3]}
ipackets=${COUNTERS[4]}
oworker_wakeups=${COUNTERS[5]}
oworker_packets=${COUNTERS[6]}
oworker_kicks=${COUNTERS[7]}

# 
# print_div(a,b)
#
# Prints the result of a/b
print_div()
{
	local a=$1
	local b=$2

	if [[ $b -ne 0 ]]; then
		local res=$(echo "$a/$b" | bc -l)
		printf "%.2f\n" $res
	else
		echo "nan"
	fi
}

#####################
echo -n "Rx: packets($ipackets)/bh_wakeups($ibh_wakeups) = "
print_div $ipackets $ibh_wakeups 
#####################
echo -n "Tx: packets($opackets)/kicks($okicks) = "
print_div $opackets $okicks
#####################
echo -n "Tx: worker packets($oworker_packets)/worker kicks($oworker_kicks) = "
print_div $oworker_packets $oworker_kicks
#####################
echo -n "Tx: worker packets($oworker_packets)/worker wakeups($oworker_wakeups) = "
print_div $oworker_packets $oworker_wakeups
#####################
echo -n "Tx: queue is full($oqueue_is_full)/packets($opackets) = "
print_div $oqueue_is_full $opackets
