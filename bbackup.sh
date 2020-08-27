#!/bin/bash
#
# bbackup.sh
# version: 1.0.3.1
#
# Author:	Ungerböck Michele
# Github:	github.com/mikeunge
# Company:	GEDV GmbH
#
# All rights reserved.
#
# Get start time and date_only.
start_date=$(date +'%d.%m.%Y')
script_start=$(date +'%d.%m.%Y %T')

# Load the config.
CONFIG_FILE="/etc/bbackup.conf"   # change this path if needed.
if [ -f "$CONFIG_FILE" ]; then
    source $CONFIG_FILE
else
    # If config is not found, log to a specific .error.log file.
    echo "Configuration file doesn't exist! [$CONFIG_FILE]" > /var/log/bbackup.error.log
    exit 1
fi

# Define the log levels and the log level that is used.
declare -A levels=([DEBUG]=0 [INFO]=1 [WARNING]=2 [ERROR]=3)
log() {
    # Bind the passed parameters.
    local message=$1
    local priority=$2

    # Check if level exists.
    [[ ${levels[$priority]} ]] || return 1

    # Check if level is enough.
    (( ${levels[$priority]} < ${levels[$LOG_LEVEL]} )) && return 2

    # Get the current datetime.
    cur_datetime=$(date +'%d.%m.%Y %T')

    # Check if file logging is enabled, else echo to stdout.
    if [[ $LOG_ENABLE == 1 ]]; then
    	# Write the message to the log file.
    	echo "[$cur_datetime] :: ${priority} :: ${message}" >> $LOG_FILE
    else
	    # Write the message to stdout.
	    echo "[$cur_datetime] :: ${priority} :: ${message}"
    fi
}

send_email() {
    log "Sending email via $MAIL_CLIENT..." "DEBUG"
    mail_str=""
    # Check if the mail_client is defined correctly.
    case $MAIL_CLIENT in
        "sendmail"|"mail") 
            mail_str='mail -A $RSNAPSHOT_LOG_FILE -s "$SENDER [$status] (exec=$JOB) - $start_date" $DEST_EMAIL < $LOG_FILE' ;;
        "mutt") 
            mail_str='mutt -s "$SENDER [$status] (exec=$JOB) - $start_date" -a $RSNAPSHOT_LOG_FILE -- $DEST_EMAIL < $LOG_FILE' ;;
        *)
            log "Could not send the e-mail; Mail client ($MAIL_CLIENT) is not (or wrong) defined. Please check the config. ($CONFIG_FILE)" "ERROR"
            panic 2     # Special case that kills the script entirely without trying to send the e-mail (again).
        ;;
    esac
    # Send the email;
    eval $mail_str
    log "send_mail() returned with $?." "DEBUG"
}

panic() {
    # Check if a argument is provided.
    if [ -z "$1" ]; then
        error=1
    else
        error=$1
    fi
    # Check for different error cases.
    case $error in
        1)
            status="error"
            log "An error occured, please check the mail content and/or the attachment for more informations." "ERROR"
            send_email
            exit 1;;
        2)  # This is a special case (panic 2) that only gets triggered from the send_email function.
            # The check prevents the script from an endless loop. (=> dosn't call the send_email function like the other cases)
            status="error"
            log "Something went wrong while sending the status mail, please check if everything is configured correctly and sending e-mails is possible from command line." "ERROR"
            exit 1 ;;
        0)
            status="success"
            log "Backup was successfully created!" "INFO"
            send_email
            exit 0 ;;
        *)  # This should actually never happen.
            status="warning"
            log "A warning was raised, please check the mail content and/or the attachment for more informations." "WARNING"
            send_email
            exit 1 ;;
    esac
}

compress() {
	err=0
	if [ -z $1 ]; then
		log "No source provided!" "WARNING"
		err=1
	fi
	if [ -z $2 ]; then
		log "No destination provided!" "WARNING"
		err=1
	fi
	
	# Define variables for better understanding.
	src=$1
	dest=$2

	# Routine for deleting the existing src.
	#
	if [ -d $dest ]; then
		# Check if the trigger is defined.
        	if [[ $COMP_REM == 1 ]]; then
            		log "Trying to delete [$dest]." "DEBUG"
			{
            			rm -rf $dest 2>&1 /dev/null
			} || {
				log "An error occured while deleting [$dest]" "WARNING"
				err=1
			}
            	if [[ $? == 0 ]]; then
                	log "File $dest deleted successfully." "DEBUG"
            	else
                	log "Could not delete $dest." "WARNING"
			err=1
            	fi
        fi
    	else 
        	log "Destination doesn't exist. [$dest]" "DEBUG"
    	fi

	# Check for errors.
	if [[ $err == 1 ]]; then
		log "One ore more errors occured, please check the log for more information." "ERROR"
	else
		log "Compressing [$src -> $dest]" "INFO"
		# Suppress warning "file-changed".
 	        # This flag needs to be set, it ignores if file changes occured.
        	# If it detects a change, it will simply ignore it, else it would need manual accaptance (eg. ENTER).
		tar --warning=no-file-changed -cPjf $dest $src 2>&1 /dev/null
        	return_code=$?
		# Check the 'tar' return code.
		if [[ $return_code == 0 ]]; then
			log "Compression [$src -> $dest] succeeded." "INFO"
		else
			log "An error occured while compressing [$src -> $dest], 'tar' returned with error code $return_code." "WARNING"
		fi
	fi
}

# Check if the log_rotate is set.
# If so, remove the defined logs for cleaner output.
if [[ $LOG_ROTATE == 1 ]]; then
    log "LOG_ROTATE is active." "DEBUG"
    # Check if the logfiles exist, if so, delete them.
    log_files=( "$LOG_FILE" "$RSNAPSHOT_LOG_FILE" )
    for file in "${log_files[@]}"; do
        if [ -f "$file" ]; then
            rm -f "$file"
            log "Deleted logfile $file" "DEBUG"
        else
            log "$file doesn't exist. Next." "DEBUG"
        fi
    done
fi

# Start of the script.
log "*.bbackup.sh start.*" "INFO"
log "Configfile => $CONFIG_FILE." "INFO"

# Check if a argument is provided.
if [ -z "$1" ]; then
    log "No argument supplied, fallback to config defined job => $DEFAULT_JOB." "WARNING"
    JOB="$DEFAULT_JOB"
else
    JOB="$1"
    log "Executed job => $JOB." "DEBUG"
fi

# Check if the second job is executed.
if [[ "$SEC_JOB" == "$JOB" ]]; then
    log "Second job got triggered, share has changed. [$SHARE => $SEC_SHARE]" "INFO"
    SHARE="$SEC_SHARE"
fi


# TODO: Add skip function for network mounting.
#
# Try to mount the network drive.
i=0
while [[ $i < $TRIES ]]; do
    if ! grep -q "$MOUNT" /proc/mounts; then
        { # Try to mount the network drive.
            log "Mounting share ... [$SHARE]" "INFO"
            mount -t cifs -o username="$USER",password="$PASSWORD" "$SHARE" "$MOUNT" > /dev/null 2>&1
            log "Network share successfully mounted!" "INFO"
            break
        } || {
            (( i=i+1 ))
            log "[$i/$TRIES] Could not mount network share! ... [$SHARE -> $MOUNT]" "WARNING"
            if [[ i == $TRIES ]]; then
                log "Could not mount the network share $TRIES times!\nExiting script!" "ERROR"
                panic 1
            fi
        }
    else
        log "Network share is already mounted." "INFO"
        break
    fi
done

# Compression implementation.
if [[ $COMPRESS == 1 ]]; then
    # Define a 'local' error count.
    error=0

    # Check if source string is NOT empty.
	if [ -z $COMP_SRC ]; then
		log "[COMP_SRC] is not defined!" "ERROR"
        error=1
	fi

	if ! [ -d $COMP_TMP ]; then
		log "TMP folder does not exist, creating '$COMP_TMP'" "INFO"
		{
			mkdir $COMP_TMP
		} || {
			log "Couldn't create folder '$COMP_TMP'" "ERROR"
			error=1
		}
	fi

	# Check if any errors occured.
	if [[ $error == 1 ]]; then
		log "Something went wrong with the COMP_SRC or the COMP_TMP! Check logs for more detail." "ERROR"
		panic 1
	fi

	# Creates the $COMP_SRC_SPLIT array.
	IFS=$COMP_DEL read -ra COMP_SRC_SPLIT <<< "$COMP_SRC"

    # Make sure the source string is splitable.
    if [[ ${#COMP_SRC_SPLIT[@]} == 1 ]]; then
        log "Compression source string is NOT splitable by delimiter '$COMP_DEL'! Make sure to define the correct delimiter and/or define/split the correct source." "ERROR"
        panic 1
    fi
	# Loop over the split array.
	for elem in "${COMP_SRC_SPLIT[@]}"
	do
		# Make sure the path to compress exists.
		if ! [ -d $elem ]; then
			log "Path '$elem' doesn't exist! Skipping this one." "WARNING"
			continue
		fi

		# For every elem split the path by delimiter '/'.
		# This returns the "real" name of the destination.
		#  eg. /var/log/bbackup/ -> bbackup.tar.bz2
		#
		IFS='/' read -ra dest_arr <<< "$elem"

		arr_len=${#dest_arr[@]}
		dest_elem=${dest_arr[$arr_len - 1]}

		# Construct the destinatino path.
		dest="$COMP_TMP$dest_elem.tar.bz2"
		# Compress each element.
		{
			compress $elem $dest &
		} || {
			log "Could not compress file/folder [$elem]" "WARNING"
			error=1
		}
	done
	# Waiting for the compress() function to finish its tasks.
	wait
    # Check if any errors occured.
    if [[ $error == 1 ]]; then
        log "Something went wrong with the compression. Check the logs for more information!" "ERROR"
        panic 1
    fi
fi


log "Starting rSnapshot job ... [$JOB]" "INFO"
{
    # Run the rsnapshot backup job.
    cmd="$RSNAPSHOT $JOB"
    output=`$cmd`
    # Check if the rsnapshot output is empty or not.
    if [[ $output != "" ]]; then
        log "$output" "DEBUG"
    else
        log "rSnapshot didn't return any output." "INFO"
    fi
} || {
    # Built a wrapper around a rsnapshot error that happens if a file changes while rsnapshot runs (return_val: 2).
    if [[ $? == 0 ]]; then
        log "Backup complete. No warnings/errors occured." "INFO"
    else
        log "rSnapshot retured with an error (code: $?), please check the rSnapshot logs for more information." "ERROR"
        panic 1
    fi
}

script_end=$(date +'%d.%m.%Y %T')
log "Start: $script_start :: End: $script_end" "DEBUG"
panic 0
