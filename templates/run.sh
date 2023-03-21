#!/bin/bash

# Submit the pipeline as a background process with ./run.sh

nohup nice -4 R CMD BATCH workflow.R &

# Save PGID somewhere so you can kill the process or check on it
echo $! > $PWD/pid.nohup

# Kill the process with:
##  kill -SIGTERM -- -<PGID here> 
# A negative number kills the whole process group
