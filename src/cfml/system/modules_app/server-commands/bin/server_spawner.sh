#!/bin/bash

# In *nix OS's we need to separate the server process from the CLI process
# so SIGINTs from Ctrl-C won't also kill previously started servers

# Save name of log file
log_file=$1

# Initialize log file as empty
> "$log_file"

# Remove log file from argument list
shift

# Pass all remaining args through to "nohup" which will make the server process ignore
# 'hangup' signals so it stays running and it not part of the thread group that the CLI is in.
nohup "$@" > "$log_file" 2>&1 &

# Grab the PID of our server (last backgrounded job)
p_name=$!

# Tail the log file starting from the beginning in the background
tail -f -n +0 "$log_file" &

# Wait for the server launcher process to end
wait $p_name

# Kill the tail
kill $!
