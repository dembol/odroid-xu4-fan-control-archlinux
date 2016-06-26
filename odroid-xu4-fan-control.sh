#!/bin/bash

function assert_user_is_root() {
    # Make sure only root can run our script
    if [[ $EUID -ne 0 ]]; then
	echo "This script must be run as root" 1>&2
	exit 1
    fi
}

function assert_file_exists() {
    if [ ! -f $1 ]; then
	echo "file $1 doesn't exists, exiting"
	exit 1
    fi
}

function detect_fan_number() {
    FAN=0
    for fan in 13 14; do
	if [ -f /sys/devices/odroid_fan.$fan/fan_mode ]; then
		return $fan
	fi
    done
    
    die "couldn't find fan device"
}

function read_current_temperature() {
    echo `cat ${TEMPERATURE_FILE} | cut -d: -f2 | sort -nr | head -1`
}

function set_fan_speed() {
    current_speed=`cat ${PWM_DUTY_FILE}`
    if [ $current_speed != $1 ]; then
	echo $1 > ${PWM_DUTY_FILE}
    fi
}

function set_manual_mode() {
    echo 0 > ${FAN_MODE_FILE}
}

function set_auto_mode() {
    echo 1 > ${FAN_MODE_FILE}
}

function get_fan_activity() {
    current_max_temp=$(read_current_temperature)

    if (( ${current_max_temp} >= $1 )); then
	echo "on"
    elif (( ${current_max_temp} <= $2 )); then
	echo "off"
    else
	echo $3
    fi
}

function get_best_fan_speed() {
    current_max_temp=$(read_current_temperature)
    
    if (( ${current_max_temp} >= 75000 )); then
	fan_speed=255
    elif (( ${current_max_temp} >= 70000 )); then
	fan_speed=200
    elif (( ${current_max_temp} >= 68000 )); then
	fan_speed=130
    elif (( ${current_max_temp} >= 66000 )); then
	fan_speed=71
    elif (( ${current_max_temp} >= 63000 )); then
	fan_speed=61
    else
	fan_speed=$FAN_SPEED_COLD
    fi
    
    echo $fan_speed
}

die() {
    echo "$@" 1>&2 
    exit 1
}

assert_user_is_root
detect_fan_number

FAN=$?
TEMPERATURE_FILE="/sys/devices/10060000.tmu/temp"
FAN_MODE_FILE="/sys/devices/odroid_fan.$FAN/fan_mode"
PWM_DUTY_FILE="/sys/devices/odroid_fan.$FAN/pwm_duty"
STEP_DELAY_SECONDS=2
TEMPERATURE_HIGH=70000
TEMPERATURE_LOW=62000
FAN_SPEED_COLD=2

assert_file_exists $TEMPERATURE_FILE
assert_file_exists $FAN_MODE_FILE
assert_file_exists $PWM_DUTY_FILE
trap set_auto_mode EXIT
set_manual_mode

function fan_control {
    FAN_STATUS="on"
    while [ true ];
    do
	current_max_temp=$(read_current_temperature)
	echo $current_max_temp

	FAN_STATUS=$(get_fan_activity $TEMPERATURE_HIGH $TEMPERATURE_LOW $FAN_STATUS)
	if [ $FAN_STATUS == "on" ]; then
		best_fan_speed=$(get_best_fan_speed)
		set_fan_speed $best_fan_speed
	else
		set_fan_speed $FAN_SPEED_COLD
	fi
	
	sleep $STEP_DELAY_SECONDS
    done
}

fan_control
