#!/bin/bash
#set -x #modalità debug
####################################################################################
# Sample Nagios plugin to monitor occurrence of the process running on the machine #
# Author: Fulvio Capone                                                            #
####################################################################################

VERSION="Version 1.0"
AUTHOR="2015 Fulvio Capone (fulvio.capone@gmail.com)"

PROGNAME=`type $0 | awk '{print $3}'`  # search for executable on path
PROGNAME=`basename $PROGNAME`          # base name of program

# Exit codes
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

# Global variables #############################################################
dat="${PROGNAME%.*}.dat" #delete ".sh" and replace with ".dat"
datwr="${PROGNAME%.*}.dat" #delete ".sh" and replace with ".dat"
now=$(date +"%F %H:%M") #YYYY-MM-DD HH:MM
lastexec="$(date +"%F") 00:00" #today at midnight
fileerr=""
filewrn=""

# Helper functions #############################################################

function read_last_exec_date_from_file () {
	# Read last execution date and time YYYY-MM-DD HH:MM
	dat=${1%.*}.dat
	dat="${dat//\//_}"
	if [ -f "$dat" ]
	then
		lastexec=$(<$dat)
	else
		echo "Dat file not exists. Last execution time is set at midnight : $lastexec"
	fi
}

function write_current_exec_date_to_file () {
	#write current execution date and time
	datwr=${1%.*}.dat
	datwr="${datwr//\//_}"
	echo "$now" > "$datwr"
}

function print_revision {
   # Print the revision number
   echo "$PROGNAME - $VERSION - AUTHOR"
}

function print_usage {
   # Print a short usage statement
   echo "Usage: $PROGNAME [-v] -l <log file name with absolute path>"
}

function print_help {
   # Print detailed help information
   print_revision
   echo "$AUTHOR\n\nCheck log file to find ERROR or WARNING\n"
   print_usage

   /bin/cat <<__EOT

Options:
-h
   Print detailed help screen
-V
   Print version information
-l STRING
   The name of the log file to monitor
-v
   Verbose output
__EOT
}

# Main #########################################################################
# Verbosity level
verbosity=0

# Parse command line options
while [ "$1" ]; do
   case "$1" in
       -h | --help)
           print_help
           exit $STATE_OK
           ;;
       -V | --version)
           print_revision
           exit $STATE_OK
           ;;
       -v | --verbose)
           : $(( verbosity++ ))
           shift
           ;;
	   -l | --log)
			if [[ -z "$2" || "$2" = -* ]]; then
			# Process name not provided
			echo "$PROGNAME: Option '$1' requires an argument"
               print_usage
               exit $STATE_UNKNOWN
		   elif [[ "$2" = /* ]]; then
               # Process is a path
               logfile=$2
			   read_last_exec_date_from_file $logfile
			   cmderr="cat $logfile | sed -n '/$lastexec/,/$now/p' | grep ERROR"
			   cmdwrn="cat $logfile | sed -n '/$lastexec/,/$now/p' | grep WARNING"
			   eval $cmderr > ${logfile//\//_}_err.dat
			   eval $cmdwrn > ${logfile//\//_}_wrn.dat
			   fileerr=${logfile//\//_}_err.dat
			   filewrn=${logfile//\//_}_wrn.dat
           else
               # this is not a valid file with absolute path
               echo "$PROGNAME: Log File must be a file with absolute path. You are entered the value: $2"
               print_usage
               exit $STATE_UNKNOWN
           fi
		   shift 2
		   ;;
       -?)
           print_usage
           exit $STATE_OK
           ;;
       *)
           echo "$PROGNAME: Invalid option '$1'"
           print_usage
           exit $STATE_UNKNOWN
           ;;
   esac
done

if [[ "$verbosity" -ge 1 ]]; then
   # Print debugging information
   /bin/cat <<__EOT
Debugging information:
  Last Execution Time: $lastexec
  Current Execution Time: $now
  Verbosity level: $verbosity
  LOG file: $logfile
  Last Execution Time file storage: $logfile
  Errors file: $fileerr
  Warning file: $filewrn
__EOT
fi

ERRORS=$(<$fileerr)
WARNINGS=$(<$filewrn)
nowfile=$(date +"%Y%m%d%H%M%S")

if [[ -z "$ERRORS" && -z "$WARNINGS" ]]; then
	echo "OK - No errors or warnings found"
	write_current_exec_date_to_file $logfile
	exit $STATE_OK
elif [[ -n "$ERRORS" ]]; then
	echo "CRITICAL - Errors are the following:"
	for line in ${ERRORS[*]}; do
		echo $line
	done
	fileerro="${fileerr%.*}_$nowfile.dat"
	cp $fileerr $fileerro
	write_current_exec_date_to_file $logfile
	exit $STATE_CRITICAL
elif [[ -n "$WARNING" ]]; then
	echo "WARNING - Warnings are the following:"
	for line in ${WARNINGS[*]}; do
		echo $line
	done
	filewrno="${filewrn%.*}_$nowfile.dat"
	cp $filewrn $filewrno
	write_current_exec_date_to_file $logfile
	exit $STATE_WARNING
else
	echo "UNKNOWN"
	exit $STATE_UNKNOWN
fi

