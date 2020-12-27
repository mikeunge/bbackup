#!/bin/bash

if ! [ -f "../libs/argparser.sh" ]; then
    printf "Argparser does not exist. Make sure 'argparser.sh' exists in '../libs/'.";
    exit 1; 
else
    {
        source ../libs/argparser.sh;
    } || {
        printf "Could not source argparser... Make sure it's readable and not in use.";
        exit 1;
    }
fi

# Check if the returned config and task equals the input
config_task_pass() {
    printf "\n### Config & Task (pass)\n";
    argparser "--config" "$config" "--task" "$task";
    if [[ "$ARG_CONFIG" == "$config" ]]; then
        printf "✅ ... config passed\n";
    else
        printf "❌ ... config failed\n";
    fi
    if [[ "$ARG_TASK" == "$task" ]]; then
        printf "✅ ... task passed\n";
    else
        printf "❌ ... task failed\n";
    fi
}

# Check if the returned config equals the input
config_pass() {
    printf "\n### Config (pass)\n";
    argparser "--config" "$config";
    if [[ "$ARG_CONFIG" == "$config" ]]; then
        printf "✅ ... config passed\n";
    else
        printf "❌ ... config failed\n";
    fi
}

# Check if the returned task equals the input
task_pass() {
    printf "\n### Task (pass)\n";
    argparser "--task" "$task";
    if [[ "$ARG_TASK" == "$task" ]]; then
        printf "✅ ... task passed\n";
    else
        printf "❌ ... task failed\n";
    fi
}

# Check if the returned task equals the input and the config does not equal
config_fail_task_pass() {
    printf "\n### Config (fail) & Task (pass)\n";
    argparser "--config" "--task" "$task";
    if [[ "$ARG_CONFIG" == "$config" ]]; then
        printf "✅ ... config passed\n";
    else
        printf "❌ ... config failed\n";
    fi
    if [[ "$ARG_TASK" == "$task" ]]; then
        printf "✅ ... task passed\n";
    else
        printf "❌ ... task failed\n";
    fi
}

# Check if the returned config equals the input and the TEST flag is set
config_pass_set_test() {
    printf "\n### Config (pass) & set Test flag\n";
    argparser "--test" "--config" "$config";
    if [[ "$ARG_CONFIG" == "$config" ]]; then
        printf "✅ ... config passed\n";
    else
        printf "❌ ... config failed\n";
    fi
    if [[ "$ARG_TEST" == 1 ]]; then
        printf "✅ ... test_flag passed\n";
    else
        printf "❌ ... test_flag failed\n";
    fi
}


config="/tmp/bbackup.conf";
task="daily";

config_task_pass;
config_pass;
task_pass;
config_fail_task_pass;
config_pass_set_test;
exit 0;
