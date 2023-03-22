# This may take a long time to run.  Run as a background job if you don't want
# to tie up your R session.  In RStudio click the "Source" drop-down and choose
# "Source as Local Job"

# Load packages -----------------------------------------------------------
# PEcAn.ED2 installed from PR https://github.com/PecanProject/pecan/pull/3125
library(PEcAn.all) 
library(purrr)
library(stringr)
library(fs)
library(dplyr)
library(readr)


# Set logger level --------------------------------------------------------

# Set to "INFO" so console isn't flooded with squeue messages
olevel <- PEcAn.logger::logger.setLevel("INFO")

# Read in settings --------------------------------------------------------

#edit this path
inputfile <- "transect/MANDIFORE-SEUS-655/prairie/pecan.xml"
settings <- PEcAn.settings::read.settings(inputfile)

# Prepare settings --------------------------------------------------------
settings <- prepare.settings(settings)
settings <- do_conversions(settings)

# Query trait database ----------------------------------------------------
settings <- runModule.get.trait.data(settings)
write.settings(settings, outputfile = "settings_checked.xml")

# Meta analysis -----------------------------------------------------------
#skip if this was already done
exp_meta_files <- file.path(settings$pfts |> map_chr("outdir"), "trait.mcmc.Rdata")
if(!all(file.exists(exp_meta_files))) {
  runModule.run.meta.analysis(settings)
}

# Write model run configs -----------------------------------------------------

## This will write config files locally.
runModule.run.write.configs(settings)

# Modify job.sh to run R inside singularity container.  
# This is a workaround for https://github.com/PecanProject/pecan/issues/2540

#this code also modifies the job.sh to run model2netcdf.ED2() with the
#process_partial = TRUE option so that .nc files are created even for runs that
#don't finish.

job_scripts <-
  list.files(settings$rundir,
             "job.sh",
             recursive = TRUE,
             full.names = TRUE)
#TODO: could get this from settings under the assumption that the .sh "ED
#binary" has same naming convention as .sif file
container_path <-
  "/groups/kristinariemer/ed2_results/global_inputs/pecan-dev_ed2-dev.sif"

purrr::walk(job_scripts, function(x) {
  job_sh <- readLines(x)
  cmd <-
    paste0("singularity run ", container_path, " /usr/local/bin/Rscript")
  job_sh_mod <- stringr::str_replace(job_sh, "Rscript", cmd)
  # find which line has the model2netcdf.ED2() function
  linenum <-
    job_sh_mod |> str_detect("model2netcdf\\.ED2\\(") |> which()
  # add process_partial = TRUE arg
  job_sh_mod[linenum] <- job_sh_mod[linenum] |>
    str_replace('\\)\\"$' , ', process_partial = TRUE\\)\\"')
  writeLines(job_sh_mod, x)
})

## Remove sensitivity analysis runs for all PFTs except Setaria
# Delete all rundirs that aren't ensemble members, setaria SA, or the SA median
# run.
rundirs <- dir_ls(settings$rundir, type = "directory")
modeloutdirs <- dir_ls(settings$modeloutdir, type = "directory")
file_delete(rundirs[!str_detect(rundirs, "ENS-|SA-SetariaWT|SA-median")])
file_delete(modeloutdirs[!str_detect(modeloutdirs, "ENS-|SA-SetariaWT|SA-median")])

# Re-write runs.txt
runs <- read_lines(path(settings$rundir, "runs.txt"))
# This join is just to keep everything in the original order, in case that is
# important.
inner_join(
  tibble(runs),
  tibble(runs = dir_ls(settings$rundir, type = "directory") |> 
           path_file())
) |>
  pull(runs) |>
  write_lines(path(settings$rundir, "runs.txt"))


# Start model runs --------------------------------------------------------

## This copies config files to the HPC and starts the run
runModule_start_model_runs(settings, stop.on.error = FALSE)

# Model analyses ----------------------------------------------------------

## Get results of model runs
get.results(settings)

## Run ensemble analysis on model output
runModule.run.ensemble.analysis(settings)

# Run sensitivity analysis on model output
run.sensitivity.analysis(settings)

# Cleanup -----------------------------------------------------------------
# Remove .h5 files --------------------------------------------------------

# To prevent Welsch from filling up, delete .h5 files if conversion to .nc was
# successful.

# runs that finished and had successful conversion of data
end <- settings$run$end.date |> lubridate::year()
done <- 
  dir_ls(settings$modeloutdir, glob = paste0("*", end, ".nc"), recurse = TRUE) |>
  path_dir()

# and delete the .h5 files
dir_ls(done, glob = "*.h5") |> file_delete()


# Reset logger level to original value
PEcAn.logger::logger.setLevel(olevel)
