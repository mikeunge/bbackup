usage() {
    printf "Usage:   ./bbackup.sh --<argument> <value>\n\n";
    printf "Arguments:  config - Specify a path to a different configuration file\n";
    printf "            task   - Provide the task that should get executed\n";
}

argparser() {
    ARG_CONFIG=0;
    ARG_TASK=0;
    ARG_TEST=0;

    local argc="$@";
    local arg_tmp=0;
    for arg in $argc; do
        case $arg_tmp in
            "--config"|"-c")
                if [[ $ARG_CONFIG == 0 ]]; then
                    ARG_CONFIG=$arg;
                fi ;;
            "--task"|"-t")
                if [[ $ARG_TASK == 0 ]]; then
                    ARG_TASK=$arg;
                fi ;;
            "--test")
                # Make sure to set the '--test' flag as the FIRST parameter.
                # If '--test' get's provided as eg. last parameter, the 
                # parser will simply ignore it. (I don't really know why)
                ARG_TEST=1 ;;
            "--help"|"-h"|"help")
                usage;
                exit 0 ;;
        esac;
        arg_tmp=$arg;
    done;
}
