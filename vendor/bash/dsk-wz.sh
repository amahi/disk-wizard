#!/bin/bash

# Function to write to the Log file
# Ref:http://goo.gl/ld4ifr
###################################
DEBUG_MODE=true;
write_log()
{
  while read text
  do
			if [ "$DEBUG_MODE" = true ]; then
				LOGTIME=`date "+%Y-%m-%d %H:%M:%S"`
				LOG="dsw.log"
				touch $LOG
				if [ ! -f $LOG ]; then echo "ERROR!! Cannot create log file $LOG. Exiting."; exit -1; fi
				echo $LOGTIME": $text" >> $LOG;
			fi
  done
}

executor(){
	local command=$1;
	shift;
	local params="$*";
	echo  "Start executing $command with arguments = $params" | write_log;
	eval sudo $command $params;
}

if [ $# -lt 2 ]
	then
		echo -e "An insufficient number of arguments(arguments)" | write_log ;
		exit -1;
fi

command=$1;
shift;
arguments="$@";

# Pattern matching Ref: http://goo.gl/JnXS5y
case $command in
parted)
	executor $command $arguments;
;;
mkfs.*)
	executor $command $arguments;
;;
lsblk)
	executor $command $arguments;
;;
fdisk)
	executor $command $arguments;
;;
*)
	executor $command $arguments;
	# if a command is not one we know, we exit with an error
;;
esac
exit 0;
