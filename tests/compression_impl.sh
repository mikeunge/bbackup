#!/bin/bash

COMPRESS=1
COMP_SRC="/Users/mikeunge/Documents/Work/;/Users/mikeunge/Documents/Privat/"
COMP_TMP="/tmp/backupper/"

# Define the delimiter char.
# This char defines where the string will be split.
#
COMP_DEL=";"
error=0


panic() {
	exit $1
}

log() {
	echo "[$2] $1"
}

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
		#  eg. /var/log/backupper/ -> backupper.tar.bz2
		#
		IFS='/' read -ra dest_arr <<< "$elem"

		arr_len=${#dest_arr[@]}
		dest_elem=${dest_arr[$arr_len - 1]}

		# Construct the destinatino path.
		dest="$COMP_TMP$dest_elem.tar.bz2"
		# Compress each element.
		log "Start compressing [$elem -> $dest]" "DEBUG"
		# Try to compress the files/folders.
		{
			tar -cjvf $dest $elem > /dev/null 2>&1
		} || {
			log "Could not compress file/folder [$elem]" "WARNING"
			error=1
		}
	done
    # Check if any errors occured.
    if [[ $error == 1 ]]; then
        log "Something went wrong with the compression. Check the logs for more information!" "ERROR"
        panic 1
    fi
fi

echo "Done"
