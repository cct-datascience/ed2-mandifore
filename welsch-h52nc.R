# I screwed up the singularity script by commenting out 'module load
# singularity'.  This line isn't necessary, but for some reason introduced an
# unexpected new bug where "s" was not a command.  So, here's a script to run
# model2netcdf.ED2() on Welsch in parallell.

# TO USE:
# 1) edit `outdir` path
# 2) copy-paste the appropriate model2netcdf.ED2() code from a job.sh below.

library(PEcAn.all)
library(PEcAn.ED2)
library(furrr)
library(fs)
plan("multisession", workers = 5) #probably could use more workers, but not sure

#change this to the outdir you want (dir that contains out/ run/ and pft/)
outdir <- "/data/output/pecan_runs/MANDIFORE_big_run/MANDIFORE-SEUS-1123/prairie/"

safe_model2netcdf.ED2 <- purrr::possibly(model2netcdf.ED2)

outdirs <- dir_ls(path(outdir, "out/"))
outdirs |> 
  future_walk(
    
    ###### IMPORTANT #####
    ###### EDIT THIS #####
    ~ safe_model2netcdf.ED2(
      .x,
      29.365195,
      -82.810137,
      '2002-06-01',
      '2012-06-30',
      c(
        SetariaWT = 1L,
        sentinel_ebifarm.c3grass = 5L,
        sentinel_ebifarm.c4grass = 16L,
        ebifarm.forb = 12L
      ),
      process_partial = TRUE
    ), .progress = TRUE
  )

# Read in settings
settings <- read.settings(path(outdir, "settings_checked.xml"))

## Get results of model runs
get.results(settings)

## Run ensemble analysis on model output
runModule.run.ensemble.analysis(settings)

# Run sensitivity analysis on model output
run.sensitivity.analysis(settings)
