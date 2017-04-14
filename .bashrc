# .bashrc

###############################################################################

#
# rep <num> <command>
#
# repeat the given command "num" times and break if it fails 
#
rep()
{
        local i
        local num=$1
        shift
        for ((i = 0; i < num; i++))
        do
                echo "Step $i"
                echo "Going to execute \"$*\""
                bash -c "$*"
                if [[ $? -ne 0 ]]; then
                        echo "Command failed"
                        break
                fi
        done
}

log_bash_persistent_history()
{
	[[ $(history 1) =~ ^\ *[0-9]+\ +(.*+)$ ]]
	local command_part="${BASH_REMATCH[1]}"
	# strip trailing whitespaces
	command_part=$(echo command_part)

	if [ "$command_part" != "$PERSISTENT_HISTORY_LAST" ]; then
		lock_persistent_history
		echo $(date) "|" "$command_part" >> $PERSISTENT_HISTORY_STORAGE
		unlock_persistent_history
		export PERSISTENT_HISTORY_LAST="$command_part"
	fi
}

load_persistent_history()
{
	local tmp=$(mktemp)
	cat $PERSISTENT_HISTORY_STORAGE | cut -d"|" -f2- > $tmp
	history -r $tmp
	rm -f $tmp
}

lock_persistent_history()
{
	while ! ln -s $PERSISTENT_HISTORY_STORAGE $PERSISTENT_HISTORY_LOCK 2>/dev/null
	do
		echo "Waiting for $PERSISTENT_HISTORY_LOCK"
		sleep 1
	done
}

unlock_persistent_history()
{
	rm -f $PERSISTENT_HISTORY_LOCK
}

trim_persistent_history()
{
	local tmp=$(mktemp)
	lock_persistent_history $tmp
	# first, remove duplicates, then trim all except for the last PERSISTENT_HISTORY_DEPTH line
	cat $PERSISTENT_HISTORY_STORAGE | sort -k 2 -t "|" | uniq -f 6 | sort -k2,2M -k3,3n -k4,4 -k5,5n | tail -$PERSISTENT_HISTORY_DEPTH > $tmp
	mv $tmp $PERSISTENT_HISTORY_STORAGE
	unlock_persistent_history
}
###############################################################################

# Source global definitions
#if [ -f /etc/bashrc ]; then
#	. /etc/bashrc
#fi

# Uncomment the following line if you don't like systemctl's auto-paging feature:
# export SYSTEMD_PAGER=

# User specific aliases and functions
#/etc/bashrc

# System wide functions and aliases
# Environment stuff goes in /etc/profile

# by default, we want this to get set.
# Even for non-interactive, non-login shells.
if [ "`id -gn`" = "`id -un`" -a `id -u` -gt 99 ]; then
	umask 002
else
	umask 022
fi

PS1="[\u@\h \W]\\$ "
# are we an interactive shell?
if [ "$PS1" ]; then
    case $TERM in
	xterm*)
	    PROMPT_COMMAND='echo -ne "\033]0;${USER}@${HOSTNAME}: ${PWD}\007"'
	    ;;
	*)
	    ;;
   esac
    [ "$PS1" = "\\s-\\v\\\$ " ] && PS1="[\u@\h \W]\\$ "
    
    if [ -z "$loginsh" ]; then # We're not a login shell
        for i in /etc/profile.d/*.sh; do
	    if [ -x $i ]; then
	        . $i
	    fi
	done
    fi
fi

if [ -f /etc/bash_completion ]; then
	. /etc/bash_completion
fi

#export TERM="screen-256color" 

unset loginsh

alias ls='ls --color=auto'
alias ll='ls -alh'
alias l='ls -CF'
alias vi='vim'
alias grep='grep --color'
alias rsync='rsync -av --progress'
alias phgrep='cat $PERSISTENT_HISTORY_STORAGE | grep --color'

#[[ ! -z "$DISPLAY" ]] && xhost + &>/dev/null

#export LANG="C"
export LANG="en_US.utf8"

cgrep()
{
	local patt="$1"
	local path=.

	[[ $# -gt 1 ]] && path="$2"

	find $path -name "*.[ch]" | xargs egrep --color -n "$patt"
	find $path -name "*.cc" | xargs egrep --color -n "$patt"
	find $path -name "*.hh" | xargs egrep --color -n "$patt"
}


# The next line updates PATH for the Google Cloud SDK.
source /home/vladz/work/google-cloud-sdk/path.bash.inc

# The next line enables bash completion for gcloud.
source /home/vladz/work/google-cloud-sdk/completion.bash.inc

# export prompt related env for screen
export PROMPT_COMMAND
export PS1

##### EC2 shit
export AWS_ACCESS_KEY=AKIAIORFVE6HQLMMHVEQ
export AWS_SECRET_KEY=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
export AWS_ACCESS_KEY_ID=AKIAIORFVE6HQLMMHVEQ
export AWS_SECRET_ACCESS_KEY=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
export AWS_DEFAULT_REGION=us-east-1
export EC2_HOME=/usr/local/ec2/ec2-api-tools-1.6.13.0/
export PATH=$PATH:$EC2_HOME/bin:$HOME/bin
#export JAVA_HOME=/usr/lib/jvm/java-1.7.0-openjdk-1.7.0.71-2.5.3.0.fc20.x86_64
export JAVA_HOME=$(dirname $(dirname $(dirname $(readlink /etc/alternatives/java))))
#export JAVA_OPTS="-Xms64m -Xmx128m"

#export SSH_ASKPASS=/usr/bin/ksshaskpass
#export $(dbus-launch)

export PATH=/opt/darktable/bin:$HOME/.local/bin:$PATH:/usr/lib/ccache:/opt/slickedit-pro2015/bin

if [ -f `which powerline-daemon` ]; then
  powerline-daemon -q
  POWERLINE_BASH_CONTINUATION=1
  POWERLINE_BASH_SELECT=1
  . ~/.local/lib/python2.7/site-packages/powerline/bindings/bash/powerline.sh
fi

export PERSISTENT_HISTORY_STORAGE=$HOME/.persistent_history
export PERSISTENT_HISTORY_LOCK=/tmp/.persistent_history_lock.$USER
export PERSISTENT_HISTORY_DEPTH=20000
# avoid duplicates..
export HISTCONTROL=ignoredups:erasedups 
export HISTSIZE=$PERSISTENT_HISTORY_DEPTH
export HISTFILESIZE=$PERSISTENT_HISTORY_DEPTH
trim_persistent_history
load_persistent_history

# append history entries..
shopt -s histappend

if ! echo $PROMPT_COMMAND | grep 'log_bash_persistent_history' &> /dev/null; then
	export PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND$'\n'}log_bash_persistent_history"
fi

