#!/bin/bash
# !
# ! Usage: check_log_errors.sh <log files>
# !

usage()
{
	cat $0 | grep ^"# !" | cut -d"!" -f2-
}

if [[ $# -eq 0 ]]; then
	usage
	exit 0
fi

for f in $@
do
	grep -H shard "$f" | egrep -i "error|Writing large|no progress|stall" 
done

