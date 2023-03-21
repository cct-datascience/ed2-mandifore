#!/bin/bash

# Submit the pipeline as a background process with ./run.sh

nohup nice -4 R CMD BATCH workflow.R &

# This saves the PID for the process nohup just started
echo $! > $PWD/pid.nohup

# Kill the PID and all child processes (i.e. the R session) with:
##  pkill -STOP -P <PID>
