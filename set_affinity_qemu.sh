#!/bin/bash
# !
# !  Usage: ./set_affinity_memcached.sh <host net interface, e.g. eth1>
# !

if [[ $# -ne 1 ]]; then
    cat $0 | grep ^"# !" | cut -d"!" -f2-
    exit 1
fi

cur_cpu=0
total_cpus=`cat /proc/cpuinfo | grep processor | wc -l`
#total_cpus=1
NIC=$1
cpus4qemu=$((total_cpus-2))
if [[ $cpus4qemu -le 0 ]]; then
	cpus4qemu=1
fi

echo "cpus4qemu=$cpus4qemu"

# Set qemu threads affinity
for t in $(echo query-cpus | sudo  qmp-shell -p /tmp/qmp-sock | grep thread_id | cut -d':' -f 2 | cut -d'}' -f 1)
do
    sudo taskset -pc $cur_cpu $t
    cur_cpu=$(((cur_cpu + 1) % cpus4qemu))
done

cur_cpu=$((cpus4qemu % total_cpus))

echo "Setting the vhost affinity to CPU $cur_cpu"
sudo taskset -pc $cur_cpu `pgrep vhost`

echo "Stoping irqbalance.."
sudo systemctl stop irqbalance.service

cur_cpu=$(((cur_cpu+1) % total_cpus))

# Set the affinity of the NIC irqs to the same 
for i in `grep $NIC /proc/interrupts | awk -F: '{print $1}'`
do
    echo "Setting the affinity of IRQ $i to CPU $cur_cpu"
    sudo sh -c "echo $cur_cpu > /proc/irq/$i/smp_affinity_list"
done

