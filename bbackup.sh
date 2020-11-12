#!/bin/bash
#
# bbackup.sh
# version: 1.0.6.4
#
# Author:	Ungerböck Michele
# Github:	github.com/mikeunge
# Company:	GEDV GmbH
#
# All rights reserved.
#
# Store the pid for bbackup.sh as $_pid.
# $_pid will get written into /var/run/bbackup.pid
_pid=$$ 

# Gather metrics.
start_date=$(date +'%d.%m.%Y')
script_start=$(date +'%d.%m.%Y %T')
calc_start=$(date +'%Y-%m-%d %T')

# Load the config.
CONFIG_FILE="/etc/bbackup.conf"   # change this path if needed.
if [ -f "$CONFIG_FILE" ]; then
    source $CONFIG_FILE
else
    # If config is not found, log to a specific .error.log file.
    printf "Configuration file doesn't exist! %s\n" "$CONFIG_FILE" >> /var/log/bbackup.error.log
    exit 1
fi

# Define the log levels and the log level that is used.
declare -A levels=([DEBG]=0 [INFO]=1 [WARN]=2 [ERRO]=3)
log() {
    # Bind the passed parameters.
    local message=$1
    local priority=$2

    # Check if level exists.
    [[ ${levels[$priority]} ]] || return 1

    # Check if level is enough.
    (( ${levels[$priority]} < ${levels[$LOG_LEVEL]} )) && return 2

    # Get the current datetime.
    local cur_datetime=$(date +'%d.%m.%Y %T')

    # Check if file logging is enabled, else print to stdout.
    if [[ $LOG_ENABLE == 1 ]]; then
    	# Write the message to the log file.
        printf "[%s] :: [%s] :: %s\n" "$cur_datetime" "${priority}" "${message}" >> $LOG_FILE
    else
	    # Write the message to stdout.
        printf "[%s] :: [%s] :: %s\n" "$cur_datetime" "${priority}" "${message}"
    fi
}

send_email() {
    # Declare that the rsnapshot.log exists, if not, it'll get changed below.
    local rsnapshot_exists=1

    # Check if attachment exists.
    if ! [ -f $RSNAPSHOT_LOG_FILE ]; then
        log "rsnapshot logfile does not exist, attachment cannot be attached." "WARN"
        rsnapshot_exists=0
    fi
    log "Sending email via $MAIL_CLIENT..." "DEBG"
    local mail_str=""
    # Check if the mail_client is defined correctly.
    case $MAIL_CLIENT in
        "sendmail")
            if [[ $rsnapshot_exists > 0 ]]; then
                mail_str='sendmail -t $DEST_EMAIL -m "$SENDER [$status] - Task: $JOB - $start_date" -a $RSNAPSHOT_LOG_FILE'
            else
                mail_str='sendmail -t $DEST_EMAIL -m "$SENDER [$status] - Task: $JOB - $start_date"'
            fi ;;
        "mail")
            if [[ $rsnapshot_exists > 0 ]]; then
                mail_str='mail -A $RSNAPSHOT_LOG_FILE -s "$SENDER [$status] - Task: $JOB - $start_date" $DEST_EMAIL < $LOG_FILE'
            else
                mail_str='mail -s "$SENDER [$status] - Task: $JOB - $start_date" $DEST_EMAIL < $LOG_FILE'
            fi ;;
        "mutt") 
            if [[ $rsnapshot_exists > 0 ]]; then
                mail_str='mutt -s "$SENDER [$status] - Task: $JOB - $start_date" -a $RSNAPSHOT_LOG_FILE -- $DEST_EMAIL < $LOG_FILE'
            else
                mail_str='mutt -s "$SENDER [$status] - Task: $JOB - $start_date" -- $DEST_EMAIL < $LOG_FILE'
            fi ;;
        "null" | "nil" | "none")
            log "E-Mail functionality is turned of. If you want to activate it, change the 'MAIL_CLIENT' in your config. ($CONFIG_FILE)" "WARN" ;;
        *)
            log "Could not send the e-mail; Mail client ($MAIL_CLIENT) is not (or wrong) defined. Please check the config. ($CONFIG_FILE)" "ERRO"
            panic 2     # Special case that kills the script entirely without trying to send the e-mail (again).
        ;;
    esac 
    # Send the email;
    eval $mail_str
    local return_code=$?
    log "send_mail() returned with $return_code." "DEBG"
    # Exit the script after sending the email
    if [[ $return_code > 0 ]]; then
        panic 2
    else
        exit 0
    fi
}

panic() {
    # Define vars.
    local error=0
    local status=""

    # Unmount network share (if set)
    if [[ $UMOUNT == 1 ]]; then
        log "Unmounting network share." "INFO"
        unmount -f $MOUNT >/dev/null 2>&1

        if [[ $? == 0 ]]; then
            log "$MOUNT successfully unmounted." "INFO"
        else
            log "Something went wrong while unmounting drive $MOUNT" "WARN"
        fi
    fi

    cleanup

    # Check if a argument is provided.
    if [ -z "$1" ]; then
        error=1
    else
        error=$1
    fi

    # Check for different error cases.
    case $error in
        1)
            status="Error"
            log "An error occured, please check the mail content and/or the attachment for more informations." "ERRO"
            send_email
            wait
            exit 1;;
        2)  # This is a special case (panic 2) that only gets triggered from the send_email function.
            # The check prevents the script from an endless loop. (=> dosn't call the send_email function like the other cases)
            status="Error"
            log "Something went wrong while sending the status mail, please check if everything is configured correctly and sending e-mails is possible from command line." "ERRO"
            exit 1 ;;
        0)
            status="Success"
            log "Backup was successfully created!" "INFO"
            send_email
            wait
            exit 0 ;;
        *)  # This should actually never happen.
            status="Warning"
            log "A warning was raised, please check the mail content and/or the attachment for more informations." "WARN"
            send_email
            wait
            exit 1 ;;
    esac
}

declare CLEANUP_DEST_ARR=()
# Clean all the created garbage.
cleanup() {
    local return_code
    for dest in "${CLEANUP_DEST_ARR[@]}"
    do
        # Routine for deleting the existing src.
        if [ -f $dest ]; then
            # TODO:
            # >Move this check BEFORE the function gets called,
            # >This just takes time and mem.
            #
            # Check if the trigger is defined.
            if [[ $COMP_REM == 1 ]]; then
                log "Trying to delete [$dest]." "DEBG"
                {
                    # Check if we are on a dry run or not.
                    if [[ $TEST == 0 ]]; then
                        log "rm -rf $dest >/dev/null 2>&1" "DEBG" 
                        rm -rf $dest >/dev/null 2>&1
                        return_code=$?
                    else
                        # Free the script, delete the pid.
                        if [[ $dest == *.pid ]]; then
                            log "Test - Delting .pid file to free script." "DEBG"
                            rm -rf $dest >/dev/null 2>&1
                            return_code=$?
                        else
                            log "Test - Destination [$dest] would be deleted." "DEBG"
                            return_code=0
                        fi
                    fi
                } || {
                    log "An error occured while deleting [$dest]" "ERRO"
                    continue
                }
                if [[ $return_code == 0 ]]; then
                    log "File $dest deleted." "INFO"
                elif [[ $return_code == 1 ]]; then
                    log "Could not delete $dest." "ERRO"
                else
                    log "Something went wrong with deleting $dest, returned code: $return_code." "WARN"
                fi
            else
                if [[ $dest == *.pid ]]; then
                    log "Removing lockfile ($dest)." "INFO"
                    rm -rf $dest >/dev/null 2>&1
                    return_code=$?
                    if [[ $return_code == 0 ]]; then
                        log "Master has presented bbackup with clothes, bbackup is free." "INFO"
                    else
                        log "Something went wrong with deleting $dest" "WARN"
                    fi
                fi
            fi
        else 
            log "Destination doesn't exist. [$dest]" "DEBG"
        fi
    done
}

# Calculate the elapsed time (Analytics only)
function calc_time() {
    local num=$1
    local min=0
    local hour=0
    local day=0
    if ((num>59)); then
        ((sec=num%60))
        ((num=num/60))
        if ((num>59)); then
            ((min=num%60))
            ((num=num/60))
            if ((num>23)); then
                ((hour=num%24))
                ((day=num/24))
            else
                ((hour=num))
            fi
        else
            ((min=num))
        fi
    else
        ((sec=num))
    fi
    log "Day(s): $day  |  Hour(s): $hour  |  Min(s): $min  |  Sec(s): $sec" "INFO"
}

compress() {
	local error=0
	if [ -z $1 ]; then
		log "No source provided!" "WARN"
		error=1
	fi
	if [ -z $2 ]; then
		log "No destination provided!" "WARN"
		error=1
	fi
	
	# Define variables for better understanding.
	local src=$1
	local dest=$2

	# Check for errors.
	if [[ $error == 1 ]]; then
		log "One ore more errors occured, please check the log for more information." "ERRO"
	else
        local return_code
		log "Compressing [$src -> $dest]" "INFO"
        if [[ $TEST == 0 ]]; then
            # This COMP_MOD trigger can be set in the configuration file.
            # The tar (only) mode creates an uncompressed tar file where as the default is bz2.
            case $COMP_MOD in
                "tar") tar --warning=no-file-changed -cPf $dest $src >/dev/null 2>&1 ;;
                "bz2" | "bzip2") 
                    BZIP2=-$COMP_LVL
                    tar --warning=no-file-changed -cP --bzip2 -f $dest $src >/dev/null 2>&1 ;;
                "gz" | "gzip") 
                    GZIP=-$COMP_LVL
                    tar --warning=no-file-changed -cP --gzip -f $dest $src >/dev/null 2>&1 ;;
                "lzma")
                    LZMA=-$COMP_LVL
                    tar --warning=no-file-changed -cP --lzma -f $dest $src >/dev/null 2>&1 ;;
                *)
                    BZIP2=-$COMP_LVL
                    tar --warning=no-file-changed -cP --bzip2 -f $dest $src >/dev/null 2>&1 ;;
            esac
            return_code=$?
        else
            log "Test - File(s) would be compressed now." "DEBG"
            return_code=0
        fi
		# Check the 'tar' return code.
		if [[ $return_code == 0 ]]; then
            # Get the size of the source and destination.
            local size_src
            local size_dest
            size_src=$(du -hs $src | awk '{print $1}') &
            size_dest=$(du -hs $dest | awk '{print $1}') &
            wait
            log "Compression $src (Size: $size_src) -> $dest (Size: $size_dest) succeeded." "INFO"
		else
			log "An error occured while compressing [$src -> $dest], 'tar' returned with error code $return_code." "ERRO"
		fi
	fi
}

log_rotate() {
    # Check if the logfiles exist, if so, delete them.
    log_files=( "$LOG_FILE" "$RSNAPSHOT_LOG_FILE" )
    for file in "${log_files[@]}"; do
        if [ -f "$file" ]; then
            rm -f "$file"
            log "Deleted logfile $file" "DEBG"
        else
            log "$file doesn't exist. Next." "DEBG"
        fi
    done
}

# This is a real shitty way, i need to check if it's running like at the beginning of the script.
# I need to move it up like before i start reading the config and initializing it or so.

# Check if LOG_ROTATE is enabled.
# If so, remove the logs for a cleaner output.
if [[ $LOG_ROTATE == 1 ]]; then
    log "LOG_ROTATE is active." "DEBG"
    if [ -f "/var/run/bbackup.pid" ]; then
        log "bbackup is locked (/var/run/bbackup.pid). Log rotate is active but was skipped." "WARN"
    else
        if [[ $1 == "TEST_C" ]]; then
            log "Test - Skipped log_rotation for test prupose, files would be deleted." "DEBG"
        else
            log_rotate
        fi
    fi
fi

# Start of the script.
log "*.bbackup.sh start.*" "INFO"
log "Configfile => $CONFIG_FILE." "INFO"

# Check if a bbackup instance is already running.
if [ -f "/var/run/bbackup.pid" ]; then
    log "bbackup.sh could not create a lockfile (/var/run/bbackup.pid), make sure that only one instance of bbackup.sh is running." "ERRO"
    panic 1
fi

# Create lock (pid) file.
printf "%s\n" "$_pid" >> /var/run/bbackup.pid
log "Created lockfile, $_pid >> /var/run/bbackup.pid" "INFO"
# Add the path to the pidfile to the cleanup function.
CLEANUP_DEST_ARR+=("/var/run/bbackup.pid")

# Check if a argument is provided.
if [ -z "$1" ]; then
    log "No argument supplied, fallback to config defined job => $DEFAULT_JOB." "WARN"
    JOB="$DEFAULT_JOB"
    TEST=0
else
    # Create a test execution flag.
    # If the passed argumetn is equal to TEST_C the flag will be set.
    if [[ $1 == "TEST_C" ]]; then
        # Define a TEST variable and change the log_level as well as the log output to stdout.
        TEST=1
        LOG_ENABLE=0
        LOG_LEVEL="DEBG"
        log "Initializing test case." "DEBG"
    else
        JOB=$1
        TEST=0
        log "Executed job => $JOB." "DEBG"
    fi
fi

# Check if the second job is executed.
if [[ $SEC_JOB == $JOB ]]; then
    if ! [ -z "$SEC_SHARE" ]; then
        log "Second job got triggered, share has changed. [$SHARE => $SEC_SHARE]" "INFO"
        SHARE="$SEC_SHARE"
    fi
    if ! [ -z "$SEC_MOUNT" ]; then
        log "Second job got triggered, mount has changed. [$MOUNT => $SEC_MOUNT]" "INFO"
        MOUNT="$SEC_MOUNT"
    fi
fi

# Check if mounting is enabled, if not it will skip the process.
# If it's disabled make sure the correct paths are set in the rsnapshot configuration!
#
# Try to mount the network drive.
if [[ $MOUNT_ENABLED == 1 ]]; then
    # Check if the $MOUNT ends with a /
    # If so, trim it, eg. /mnt/nas/ => /mnt/nas
    if [[ "$MOUNT" == */ ]]; then
        MOUNT="${MOUNT%?}"
    fi
    # Check if the mount point exists.
    if ! [ -d $MOUNT ]; then
        log "Mount point ($MOUNT) does not exist, exiting." "ERRO"
        panic 1
    fi

    i=0
    while [[ $i < $TRIES ]]; do
        ((i=i+1))
        if ! mount | grep $MOUNT >/dev/null 2>&1; then
            log "Mounting share [$SHARE]" "DEBG"
            mount -t cifs -o username="$USER",password="$PASSWORD" "$SHARE" "$MOUNT" >/dev/null 2>&1
            if [[ $? == 0 ]]; then
                break
            else
                log "Could not mount network share, try $i/$TRIES" "WARN"
                if [[ $i == $TRIES ]]; then
                    log "Could not mount the network share $TRIES, exiting!" "ERRO"
                    panic 1
                fi
            fi
        else
            log "Network share is already mounted." "INFO"
            break
        fi
    done
else 
    log "Network mount is disabled, if you want to change it, set MOUNT_ENABLED to '1' in your configuration." "WARN"
fi

# Compression implementation.  if [[ $COMPRESS == 1 ]]; then
if [[ $COMPRESS == 1 ]]; then
    # Define a 'local' error count.
    error=0

    # Check if source string is NOT empty.
	if [ -z $COMP_SRC ]; then
		log "[COMP_SRC] is not defined!" "ERRO"
        error=1
	fi

	if ! [ -d $COMP_TMP ]; then
		log "TMP folder does not exist, creating '$COMP_TMP'" "INFO"
		{
            if [[ $TEST == 0 ]]; then
			    mkdir $COMP_TMP
            else
                log "Test - Folder creation skipped." "DEBG"
            fi
		} || {
			log "Couldn't create folder '$COMP_TMP'" "ERRO"
			error=1
		}
	fi

	# Check if any errors occured.
	if [[ $error == 1 ]]; then
		log "Something went wrong with the COMP_SRC or the COMP_TMP! Check logs for more detail." "ERRO"
		panic 1
	fi

	# Creates the $COMP_SRC_SPLIT array.
	IFS=$COMP_DEL read -ra COMP_SRC_SPLIT <<< "$COMP_SRC"

    # Make sure the source string is splitable.
    # If not, it'll probably only be one path provided.
    if [[ ${#COMP_SRC_SPLIT[@]} == 1 ]]; then
        log "Compression source string is NOT splitable by delimiter '$COMP_DEL'! Probably only one (1) path provided, if not, check the configuration." "WARN"
    fi

	# Loop over the split array.
	for elem in "${COMP_SRC_SPLIT[@]}"
	do
		# Make sure the path to compress exists.
		if ! [ -d $elem ]; then
			log "Path '$elem' doesn't exist! Skipping this one." "WARN"
			continue
		fi

		# For every elem split the path by delimiter '/'.
		# This returns the "real" name of the destination.
		#  eg. /var/log/bbackup/ -> bbackup.tar.bz2
		#
		IFS='/' read -ra dest_arr <<< "$elem"

		arr_len=${#dest_arr[@]}
		dest_elem=${dest_arr[$arr_len - 1]}

		# Construct the destinatin path.
        case "$COMP_MOD" in
            "tar") dest="$COMP_TMP$dest_elem.tar" ;;
            "bz2" | "bzip2") dest="$COMP_TMP$dest_elem.tar.bz2" ;;
            "gz" | "gzip") dest="$COMP_TMP$dest_elem.tar.gz" ;;
            "lzma") dest="$COMP_TMP$dest_elem.tar.lzma" ;;
            *) dest="$COMP_TMP$dest_elem.tar.bz2" ;;
        esac

        # Set the default compression level if nothing is set.
        if ! [ $COMP_MOD == "tar" ]; then
            if [ -z $COMP_LVL ]; then
                COMP_LVL=3
            fi
        fi

        # Add the destination to the CLEANUP array so they will get later deleted.
        CLEANUP_DEST_ARR+=($dest)
		# Compress each element.
		{
			compress $elem $dest &
		} || {
			log "Could not compress file/folder [$elem]" "WARN"
			error=1
		}
	done
	# Waiting for the compress() function to finish its tasks.
	wait
    # Check if any errors occured.
    if [[ $error == 1 ]]; then
        log "Something went wrong with the compression. Check the logs for more information!" "ERRO"
        panic 1
    fi
fi

# Actual backup starts here.
log "Starting rSnapshot job ... [$JOB]" "INFO"
# Run the rsnapshot backup job.
if [[ $TEST == 0 ]]; then
    # Check if any EXEC_MODE is specified.
    case "$EXEC_MODE" in
        "quiet")
            log "rsnapshot EXEC_MODE was changed to '$EXEC_MODE'" "INFO"
            cmd="$RSNAPSHOT -q $JOB" ;;
        "verbose")
            log "rsnapshot EXEC_MODE was changed to '$EXEC_MODE'" "INFO"
            cmd="$RSNAPSHOT -V $JOB" ;;
        "diagnose")
            log "rsnapshot EXEC_MODE was changed to '$EXEC_MODE'" "INFO"
            cmd="$RSNAPSHOT -D $JOB" ;;
        *)
            cmd="$RSNAPSHOT $JOB" ;;
    esac
else
    cmd="$RSNAPSHOT -t $JOB"
    log "Test - Executing rsnapshot with it's test parameter." "DEBG"
    log "Test - rsnapshot job: $cmd" "DEBG"
fi

# If test, log the rsnapshot output.
if [[ $TEST > 0 ]]; then
    output=`$cmd`
    log "Test - rSnapshot output." "DEBG"
    log "Test - $output" "DEBG"
else
    # Execute the built command.
    eval $cmd
fi

# Check exit codes.
if [[ $? == 0 ]]; then
    log "Backup complete. No warnings/errors occured." "INFO"
    err=0
else
    log "rSnapshot retured with an error (code: $?), please check the rSnapshot logs for more information." "ERRO"
    err=1
fi

# Get the size of the backup.
backup_size=$(du -hs $COMP_TMP | awk '{print $1}')

# Mark the end of the script.
script_end=$(date +'%d.%m.%Y %T')
calc_end=$(date +'%Y-%m-%d %T')

# Calculate the difference between script start and script finished.
calc_time "$(($(date -d "$calc_end" '+%s') - $(date -d "$calc_start" '+%s')))"

# End of the script.
log "Start: $script_start :: End: $script_end :: Total: $backup_size" "INFO"

# Make sure no errors occured.
if [[ $err > 0 ]]; then
    panic 1
else
    panic 0
fi
