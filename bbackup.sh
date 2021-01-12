#!/bin/bash
#
# bbackup.sh
# version: 1.1.2.1
#
# Author:	Ungerböck Michele
# Github:	github.com/mikeunge/bbackup
# Company:	GEDV GmbH
#
#
# All rights reserved.
#
############################################

panic() {
    # Check if any argument is provided.
    if [ -z "$1" ]; then
        local error=1;
    else
        local error=$1;
    fi

    cleanup;

    # Unmount network share (if set)
    if [[ $UMOUNT == 1 ]]; then
        log info "Unmounting network share."; 
        unmount -f $MOUNT >/dev/null 2>&1;

        if [[ $? == 0 ]]; then
            log info "$MOUNT successfully unmounted.";
        else
            log warn "Something went wrong while unmounting drive $MOUNT";
            error=1;
        fi
    fi

    case $ENDPOINT in
        0)
            JSONLOG_CLOSE=1;
            log info "No endpoint defined, script finished.";
            exit $error ;;
        1)  # send e-mail
            if [[ $error > 0 ]]; then
                log error "An error occured, please check the mail content and/or the attachment for more informations.";
                send_email "Error";
            else
                log info "Backup was successfully created!";
                send_email "Success";
            fi ;;
        2)  # send http
            if [[ $error > 0 ]]; then
                log error "An error occured, please check the logs for more informations.";
                send_http "Error";
            else
                log info "Backup was successfully created!";
                send_http "Success";
            fi ;;
        3)  # send http then status mail
            if [[ $error > 0 ]]; then
                log error "An error occured, please check the logs for more informations.";
                send_http "Error";
                send_email "Error";
            else
                log info "Backup was successfully created!";
                send_http "Success";
                send_email "Success";
            fi ;;
        *)  # throw error
            JSONLOG_CLOSE=1;
            log error "Something went wrong, no endpoint was specified. Please check your configuration and fix the endpoint.";
            error=1 ;;
    esac
    exit $error;
}

# Clean all the created garbage.
declare CLEANUP_DEST_ARR=()
cleanup() {
    local return_code
    for dest in "${CLEANUP_DEST_ARR[@]}"
    do
        if [ -f $dest ]; then
            if [[ $COMP_REM == 1 ]]; then
                log debug "Trying to delete [$dest]."
                {
                    if [[ $TEST == 0 ]]; then
                        log debug "rm -rf $dest >/dev/null 2>&1" 
                        rm -rf $dest >/dev/null 2>&1
                        return_code=$?
                    else
                        # Free the script, delete the pid.
                        if [[ $dest == *.pid ]]; then
                            log debug "Test - Delting .pid file to free script."
                            rm -rf $dest >/dev/null 2>&1
                            return_code=$?
                        else
                            log debug "Test - Destination [$dest] would be deleted."
                            return_code=0
                        fi
                    fi
                } || {
                    log error "An error occured while deleting [$dest]"
                    continue
                }
                if [[ $return_code == 0 ]]; then
                    log info "File $dest deleted."
                elif [[ $return_code == 1 ]]; then
                    log error "Could not delete $dest."
                else
                    log warn "Something went wrong with deleting $dest, returned code: $return_code."
                fi
            else
                if [[ $dest == *.pid ]]; then
                    log info "Removing lockfile ($dest)."
                    rm -rf $dest >/dev/null 2>&1
                    return_code=$?
                    if [[ $return_code == 0 ]]; then
                        log info "Master has presented bbackup with clothes, bbackup is free."
                    else
                        log warn "Something went wrong with deleting $dest"
                    fi
                fi
            fi
        else 
            log debug "Destination doesn't exist. [$dest]"
        fi
    done
}

compress() {
	local error=0
	if [ -z $1 ]; then
		log warn "No source provided!"
		error=1
	fi
	if [ -z $2 ]; then
		log warn "No destination provided!"
		error=1
	fi
	local src=$1
	local dest=$2

	# Check for errors.
	if [[ $error == 1 ]]; then
		log error "One ore more errors occured, please check the log for more information."
	else
        local return_code
		log info "Compressing [$src -> $dest]"
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
            log debug "Test - File(s) would be compressed now."
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
            log info "Compression $src (Size: $size_src) -> $dest (Size: $size_dest) succeeded."
		else
			log error "An error occured while compressing [$src -> $dest], 'tar' returned with error code $return_code."
		fi
	fi
}

log_rotate() {
    # Check if the logfiles exist, if so, delete them.
    log_files=( "$LOG_FILE" "$RSNAPSHOT_LOG_FILE" )
    for file in "${log_files[@]}"; do
        if [ -f "$file" ]; then
            rm -f "$file"
            log debug "Deleted logfile $file"
        else
            log debug "$file doesn't exist. Next."
        fi
    done
}
#
# ----------- Start of the script -----------
#
# Check if a bbackup instance is already running.
if [ -f "/var/run/bbackup.pid" ]; then
    printf "bbackup.sh could not create a lockfile (/var/run/bbackup.pid), make sure that only one instance of bbackup.sh is running." >> /var/log/bbackup.error.log;
    exit 1;
fi

_pid=$$;
_execpath=$(dirname $(readlink -f $0));
start_date=$(date +'%d.%m.%Y');
start_datetime=$(date +'%d.%m.%Y %T');
analytics_start=$(date +'%Y-%m-%d %T');

# Import the libraries
# On failure the script exits
libs=("$_execpath/libs/timer.sh" "$_execpath/libs/notification.sh" "$_execpath/libs/log.sh" "$_execpath/libs/argparser.sh");
for lib in "${libs[@]}"; do
    if [ -f "$lib" ]; then
        {
            source $lib;
        } || {
            printf "Import error, could not import library: %s\n" "$lib" >> /var/log/bbackup.error.log;
            exit 1;
        }
    else
        printf "Lib '%s' does not exist, script cannot run any longer.\n" "$lib" >> /var/log/bbackup.error.log;
        exit 1;
    fi
done

if [[ $# == 0 ]]; then
    CONFIG_FILE="/etc/bbackup.conf";
    TASK=0;
    TEST=0;
else
    argparser;
    if [[ "$ARG_CONFIG" == 0 ]]; then
        CONFIG_FILE="/etc/bbackup.conf";
    else
        CONFIG_FILE="$ARG_CONFIG";
    fi
    if [[ "$ARG_TASK" == 0 ]]; then
        TASK=0;
    else
        TASK="$ARG_TASK";
    fi
    if [[ "$ARG_TEST" == 0 ]]; then
        TEST=0;
    else
        TEST=1;
    fi
fi
if [ -f "$CONFIG_FILE" ]; then
    {
        source $CONFIG_FILE;
    } || {
        printf "Could not source config file, make sure it's readable and the permissions are granted. Path: '%s'\n" "$CONFIG_FILE" >> /var/log/bbackup.error.log;
        exit 1;
    }
else
    printf "Configuration file doesn't exist! Path: '%s'\n" "$CONFIG_FILE" >> /var/log/bbackup.error.log;
    exit 1;
fi

if [[ $TASK == 0 ]]; then
    TASK=$DEFAULT_TASK;
fi

# Define the BASHLOG paths configs
# Modify the destination paths of the logging file for 
# either plain or json.
if [[ $BASHLOG_JSON == 1 ]]; then
    LOG_FILE=$LOG_FILE".json";
    BASHLOG_JSON_PATH=$LOG_FILE;
    json_path=$LOG_FILE;
else
    BASHLOG_FILE_PATH=$LOG_FILE;
    file_path=$LOG_FILE;
fi

if [[ $LOG_ROTATE == 1 ]]; then
    if [[ $TEST == 0 ]]; then
        log_rotate;
    fi
fi

log info "*.bbackup.sh start.*";
printf "%s\n" "$_pid" >> /var/run/bbackup.pid;
log info "Created lockfile, $_pid >> /var/run/bbackup.pid"; 
CLEANUP_DEST_ARR+=("/var/run/bbackup.pid");   # add the path for later cleanup
log info "Configfile => $CONFIG_FILE";

# Check if the second job is executed.
if [[ $TASK == $SEC_TASK ]]; then
    if ! [ -z "$SEC_SHARE" ]; then
        log info "Second job got triggered, share has changed. [$SHARE => $SEC_SHARE]"
        SHARE="$SEC_SHARE"
    fi
    if ! [ -z "$SEC_MOUNT" ]; then
        log info "Second job got triggered, mount has changed. [$MOUNT => $SEC_MOUNT]" 
        MOUNT="$SEC_MOUNT"
    fi
fi

# Try to mount the network drive.
if [[ $MOUNT_ENABLED == 1 ]]; then
    # Check if the $MOUNT ends with a /
    # If so, trim it, eg. /mnt/nas/ => /mnt/nas
    if [[ "$MOUNT" == */ ]]; then
        MOUNT="${MOUNT%?}"
    fi
    # Check if the mount point exists.
    if ! [ -d $MOUNT ]; then
        log error "Mount point ($MOUNT) does not exist, exiting." 
        panic 1
    fi

    i=0
    while [[ $i < $TRIES ]]; do
        ((i=i+1))
        if ! mount | grep $MOUNT >/dev/null 2>&1; then
            log debug "Mounting share [$SHARE]" 
            mount -t cifs -o username="$USER",password="$PASSWORD" "$SHARE" "$MOUNT" >/dev/null 2>&1
            if [[ $? == 0 ]]; then
                break
            else
                log warn "Could not mount network share, try $i/$TRIES"
                if [[ $i == $TRIES ]]; then
                    log error "Could not mount the network share $TRIES, exiting!" 
                    panic 1
                fi
            fi
        else
            log info "Network share is already mounted." 
            break
        fi
    done
else 
    log warn "Network mount is disabled, if you want to change it, set MOUNT_ENABLED to '1' in your configuration." 
fi

# Compression implementation.  if [[ $COMPRESS == 1 ]]; then
if [[ $COMPRESS == 1 ]]; then
    error=0
    # Check if source string is NOT empty.
	if [ -z $COMP_SRC ]; then
		log error "[COMP_SRC] is not defined!"
        error=1
	fi
	if ! [ -d $COMP_TMP ]; then
		log info "Temp folder does not exist, creating '$COMP_TMP'" 
		{
            if [[ $TEST == 0 ]]; then
			    mkdir $COMP_TMP
            else
                log debug "Test - Folder creation skipped." 
            fi
		} || {
			log error "Couldn't create folder '$COMP_TMP'" 
			error=1
		}
	fi
    # Error checking
	if [[ $error == 1 ]]; then
		log error "Something went wrong with the COMP_SRC or the COMP_TMP! Check logs for more detail."
		panic 1
	fi

	# Creates the $COMP_SRC_SPLIT array.
	IFS=$COMP_DEL read -ra COMP_SRC_SPLIT <<< "$COMP_SRC"

    # Make sure the source string is splitable.
    # If not, it'll only be one path provided.
    if [[ ${#COMP_SRC_SPLIT[@]} == 1 ]]; then
        log warn "Compression source string is NOT splitable by delimiter '$COMP_DEL'! Probably only one (1) path provided, if not, check the configuration."
    fi
	# Loop over the split array.
	for elem in "${COMP_SRC_SPLIT[@]}"
	do
		# Make sure the path to compress exists.
		if ! [ -d $elem ]; then
			log warn "Path '$elem' doesn't exist! Skipping this one." 
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
		{
		    # Compress each element.
			compress $elem $dest &
		} || {
			log warn "Could not compress file/folder [$elem]" 
			error=1
		}
	done

	# Waiting for the compress() function to finish its tasks.
	wait

    # Check if any errors occured.
    if [[ $error == 1 ]]; then
        log error "Something went wrong with the compression. Check the logs for more information!"
        panic 1
    fi
fi

# Actual backup starts here.
log info "Starting rSnapshot job ... [$TASK]" 
# Run the rsnapshot backup job.
if [[ $TEST == 0 ]]; then
    # Check if any EXEC_MODE is specified.
    case "$EXEC_MODE" in
        "quiet")
            log info "rsnapshot EXEC_MODE was changed to '$EXEC_MODE'" 
            cmd="$RSNAPSHOT -q $TASK" ;;
        "verbose")
            log info "rsnapshot EXEC_MODE was changed to '$EXEC_MODE'"
            cmd="$RSNAPSHOT -V $TASK" ;;
        "diagnose")
            log info "rsnapshot EXEC_MODE was changed to '$EXEC_MODE'"
            cmd="$RSNAPSHOT -D $TASK" ;;
        *)
            cmd="$RSNAPSHOT $TASK" ;;
    esac
else
    cmd="$RSNAPSHOT -t $TASK"
    log debug "Test - Executing rsnapshot with it's test parameter."
    log debug "Test - rsnapshot job: $cmd" 
fi

# If test, log the rsnapshot output.
if [[ $TEST > 0 ]]; then
    output=`$cmd`
    log debug "Test - rSnapshot output."
    log debug "Test - $output"
else
    # Execute the built command.
    eval $cmd
fi

# Check exit codes.
if [[ $? == 0 ]]; then
    log info "Backup complete. No warnings/errors occured."
    err=0
else
    log error "rSnapshot retured with an error (code: $?), please check the rSnapshot logs for more information."
    err=1
fi

# Get the size of the backup.
if [[ $COMPRESS == 1 ]]; then
    backup_size=$(du -hs $COMP_TMP | awk '{print $1}');
else
    backup_size="N/A";
fi

# Mark the end of the script.
end_datetime=$(date +'%d.%m.%Y %T');
analytics_end=$(date +'%Y-%m-%d %T');

# Calculate the difference between script start and script finished.
calc_time "$(($(date -d "$analytics_end" '+%s') - $(date -d "$analytics_start" '+%s')))"
log info "Start: $start_datetime :: End: $end_datetime :: Total: $backup_size"

# Make sure no errors occured.
if [[ $err > 0 ]]; then
    panic 1
else
    panic 0
fi
