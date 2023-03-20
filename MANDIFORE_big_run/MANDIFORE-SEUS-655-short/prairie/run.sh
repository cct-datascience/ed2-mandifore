#!/bin/bash

# Submit the pipeline as a background process with ./run.sh
# module load R # Uncomment if R is an environment module.
cd MANDIFORE_big_run/MANDIFORE-SEUS-655-short/prairie/
nohup nice -4 R CMD BATCH workflow.R &

# Change the nice level above as appropriate
# for your situation and system.

# Removing .RData is recommended.
# rm -f .RData
