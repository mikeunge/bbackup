#!/bin/bash

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
    log info "Day(s): $day  |  Hour(s): $hour  |  Min(s): $min  |  Sec(s): $sec"
}
