#!/bin/bash -l

# Parsed by PEcAn.ED2::write.config.jobsh.ED2() to generate job.sh files

# create output folder
mkdir -p "/groups/kristinariemer/ed2_results/pecan_remote/2023-02-15-19-11-58/out/ENS-00023-1000014289"
# no need to mkdir for scratch

# redirect output
exec 3>&1
exec &>> "/groups/kristinariemer/ed2_results/pecan_remote/2023-02-15-19-11-58/out/ENS-00023-1000014289/logfile.txt"

TIMESTAMP=`date +%Y/%m/%d_%H:%M:%S`
echo "Logging on "$TIMESTAMP

# host specific setup

module load openmpi3 R

# @REMOVE_HISTXML@ : tag to remove "history.xml" on remote for restarts, commented out on purpose


# flag needed for ubuntu
export GFORTRAN_UNBUFFERED_PRECONNECTED=yes

# see if application needs running
if [ ! -e "/groups/kristinariemer/ed2_results/pecan_remote/2023-02-15-19-11-58/out/ENS-00023-1000014289/history.xml" ]; then
  cd "/groups/kristinariemer/ed2_results/pecan_remote/2023-02-15-19-11-58/run/ENS-00023-1000014289"
  
  "/groups/kristinariemer/ed2_results/global_inputs/pecan-dev_ed2-dev.sh" ""
  STATUS=$?
  if [ $STATUS == 0 ]; then
    if grep -Fq '=== Time integration ends; Total elapsed time=' "/groups/kristinariemer/ed2_results/pecan_remote/2023-02-15-19-11-58/out/ENS-00023-1000014289/logfile.txt"; then
      STATUS=0
    else
      STATUS=1
    fi
  fi
  
  # copy scratch if needed
  # no need to copy from scratch
  # no need to clear scratch

  # check the status
  if [ $STATUS -ne 0 ]; then
  	echo -e "ERROR IN MODEL RUN\nLogfile is located at '/groups/kristinariemer/ed2_results/pecan_remote/2023-02-15-19-11-58/out/ENS-00023-1000014289/logfile.txt'"
  	echo "************************************************* End Log $TIMESTAMP"
    echo ""
  	exit $STATUS
  fi

  # convert to MsTMIP
  singularity run /groups/kristinariemer/ed2_results/global_inputs/pecan-dev_ed2-dev.sif /usr/local/bin/Rscript \
    -e "library(PEcAn.ED2)" \
    -e "model2netcdf.ED2('/groups/kristinariemer/ed2_results/pecan_remote/2023-02-15-19-11-58/out/ENS-00023-1000014289', 27.1764125, -82.1357099, '2002-06-01', '2012-07-01', c(SetariaWT = 1L, temperate.Southern_Pine = 7L, temperate.South_Mid_Hardwood = 10L, temperate.Evergreen_Hardwood = 8L, ebifarm.c3grass = 5L, ebifarm.c4grass = 14L, ebifarm.forb = 12L), process_partial = TRUE)"
  STATUS=$?
  if [ $STATUS -ne 0 ]; then
  	echo -e "ERROR IN model2netcdf.ED2\nLogfile is located at '/groups/kristinariemer/ed2_results/pecan_remote/2023-02-15-19-11-58/out/ENS-00023-1000014289'/logfile.txt"
  	echo "************************************************* End Log $TIMESTAMP"
    echo ""
    exit $STATUS
  fi
fi

# copy readme with specs to output
cp  "/groups/kristinariemer/ed2_results/pecan_remote/2023-02-15-19-11-58/run/ENS-00023-1000014289/README.txt" "/groups/kristinariemer/ed2_results/pecan_remote/2023-02-15-19-11-58/out/ENS-00023-1000014289/README.txt"

# run getdata to extract right variables

# host specific teardown


# all done
echo -e "MODEL FINISHED\nLogfile is located at '/groups/kristinariemer/ed2_results/pecan_remote/2023-02-15-19-11-58/out/ENS-00023-1000014289/logfile.txt'"
echo "************************************************* End Log $TIMESTAMP"
echo ""
