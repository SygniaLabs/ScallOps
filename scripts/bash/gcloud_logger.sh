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
