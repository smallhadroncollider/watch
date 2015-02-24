#! /bin/zsh

# Check config exists
if [ ! -e ".watchrc" ]; then
    >&2 echo ".watchrc file not found"
    exit 1
fi

# Load in config
source .watchrc

# Check command is set
if [ -z "$command" ]; then
    >&2 echo "command should be set"
    exit 1
fi

# Check interval is a sensible value
too_big=$(echo "$interval > 5" | bc -l)
too_small=$(echo "$interval < 0.1" | bc -l)

if [ "$too_big" -eq 1 -o "$too_small" -eq 1 ]; then
    >&2 echo "interval should be between 0.1 and 5"
    exit 1
fi

# Setup empty variables
last_error_message=""
last_error_timestamp=""
last_error_time=""
last_message=""
time_since=0

while true;
do
    # Run watch
    result=$($command)

    # If non-zero exit code (i.e. an error)
    if [ $? -ne 0 ]
    then
        # Strip colour tags
        message=$(echo "$result" | sed -E "s/\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g")

        # Send message to notification centre
        terminal-notifier -message "$message" -title "Watch Error" -activate com.googlecode.iterm2

        # Output error in console
        last_error_message=$result
        last_error_time=$(date +"%T")
        last_error_timestamp=$(date +%s)
        last_message=""
    else
        last_message=$result
    fi

    # Clear the console
    clear

    # Right align the time
    time=$(date +"%T")
    title="Watching..."
    let pos=$(tput cols)-${#title} # Work out how much to pad to right align
    printf "\e[34m%s\e[33m%${pos}s\e[39m\n" $title "$time"

    # If there was a previous error
    if [ -n "$last_error_message" ]; then
        # Work out how long ago the error occurred
        let time_since=$(expr $(date +%s) - $last_error_timestamp)/60

        # Print how long ago the error occurred
        if [ $time_since -eq 0 ]; then time_since="Less than a minute ago"; else time_since="$time_since minutes ago"; fi

        # Print the error
        printf "\n\n\e[31mLast Error @ %s (%s)\n\e[39m\n%s\r\n\n" "$time_since" "$last_error_time" "$last_error_message"

        # Print a line across the screen
        printf '=%.0s' {1..$COLUMNS}
    fi

    # If there was a success message
    if [ -n "$last_message" ]; then
        printf "\n\n\e[32mLast Message\e[39m\n\n"
        printf "%s\n" "$last_message"
    fi

    # Accept sleep time from command line, otherwise set to 0.5 seconds
    sleep "$interval"
done
