logger() {
    # Param 1: Log name
    # Param 2: Module name
    # Param 3: Level (INFO, DEBUG, ERROR)
    # Param 4: Message
    local log=$1
    local module=`hostname`
    local level=$2
    local message=$3
    error_levels=("INFO" "DEBUG" "ERROR")
    # Validate 
    if [ $# -ne 3 ]; then
        echo "Bad params"
    fi
    # Check if error level is valid
    if ! [[ " ${error_levels[@]} " =~ " ${level} " ]]; then
        gcloud logging write $log "$module: Invalid log error level." --severity="ERROR"
        level="DEBUG"
    fi
    echo "$level: $message"
    gcloud logging write $log "$module: $message" --severity=$level
}



### Try / Except execution wrapper with GCloud logging ###
# Usage 1: exec_wrapper $ERR_ACTION_EXIT $LOGNAME "My Bash Command"  # <- This will log an error (To LOGNAME) and exit the script in case of command error
# Usage 2: exec_wrapper $ERR_ACTION_CONT $LOGNAME "My Bash Command"  # <- This will only log an error (To LOGNAME) in case of command error
# Successful command outputs will be printed out

readonly ERR_ACTION_EXIT="Exit"
readonly ERR_ACTION_CONT="Continue"
readonly STD_OUT_PATH="/tmp/stdoutput"
readonly STD_ERR_PATH="/tmp/stderr"

exec_wrapper () {
    
    local errAction=$1
    local logName=$2
    local cmdExec=$3
    echo "wrapper exec: $cmdExec"
    $cmdExec 1>$STD_OUT_PATH 2>$STD_ERR_PATH
    
    local errCode=$?
    if [ $errCode -ne 0 ]; then
        errMsg=$(cat $STD_ERR_PATH)
        logger $logName "ERROR" "ErrCode: $errCode, ErrAction: $errAction,  Message: $errMsg"
        if [[ $errAction == $ERR_ACTION_EXIT ]]; then
            logger $logName "DEBUG" "Stopping execution due to error action"
            exit 1
        fi
    fi
    cat $STD_OUT_PATH
}
