send_http() {
    if [ -z "$1" ]; then
        local status="Warning"
    else
        local status="$1"
    fi
    # make sure 'curl' exists
    which curl >/dev/null 
    if ! [ $? == 0 ]; then
        log error "'curl' was not found, please install 'curl' before running this again."
        return 1
    fi
    if ! [ -f $LOG_FILE ]; then
        log error "File '$LOG_FILE' does not exist, cannot send any data to server."
        return 1
    fi
    # load the data into a variable
    local payload=$(cat $LOG_FILE)
    if ! [ $? == 0 ]; then
        log error "Could not create payload. Check if the provided file exists: $LOG_FILE"
        return 1
    fi
    log info "Sending data to '$SERVER:$PORT'"

    # Create a connection and send the payload.
    # Check the status code and determin if everything was ok.
    local STATUS=$(curl --silent --output /dev/null --max-time $TIMEOUT --request POST --header "Content-Type: text/plain" --data "$payload" --write-out "%{http_code}" $SERVER:$PORT)
    wait    # till curl has finished
    case $STATUS in
        200)
            log info "Success!" ; return 0 ;;
        404)
            log error "Given route wasn't found, please check the server address and try again. (HTTP_STATUS: $STATUS)" ; return 1 ;;
        501)
            log error "Server responded with an internal-error, try again later. (HTTP_STATUS: $STATUS)" ; return 1 ;;
        000)
            log error "Server was not found, please check if you specified the correct route and port. (HTTP_STATUS: $STATUS)" ; return 1 ;;
        *)
            log error "Server responded with HTTP_STATUS_CODE: $STATUS" ; return 1 ;;
    esac
}

send_email() {
    if [ -z "$1" ]; then
        local status="Warning"
    else
        local status="$1"
    fi
    local rsnapshot_exists
    if ! [ -f $RSNAPSHOT_LOG_FILE ]; then
        log warn "rsnapshot logfile does not exist, attachment cannot be attached."
        rsnapshot_exists=0
    else
        rsnapshot_exists=1
    fi
    log debug "Sending email via $MAIL_CLIENT..." 
    local mail_str
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
            log warn "E-Mail functionality is turned of. If you want to activate it, change the 'MAIL_CLIENT' in your config. ($CONFIG_FILE)" ;;
        *)
            log error "Could not send the e-mail; Mail client ($MAIL_CLIENT) is not (or wrong) defined. Please check the config. ($CONFIG_FILE)"
        ;;
    esac 
    eval $mail_str
    wait
    local return_code=$?
    log debug "send_mail() returned with $return_code."
    return $return_code
}
