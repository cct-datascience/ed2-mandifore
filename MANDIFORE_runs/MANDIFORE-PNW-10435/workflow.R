# This may take a long time to run.  Run as a background job if you don't want
# to tie up your R session.  In RStudio click the "Source" drop-down and choose
# "Source as Local Job"

# Load packages -----------------------------------------------------------
library(PEcAn.all)
library(purrr)

# Read in settings --------------------------------------------------------

#edit this path
inputfile <- "MANDIFORE_runs/MANDIFORE-PNW-10435/pecan.xml"

#check if settings_checked.xml exists and read that in if it does
chk_path <- file.path(dirname(inputfile), "outdir/settings_checked.xml")
if (file.exists(chk_path)){
  settings <- PEcAn.settings::read.settings(chk_path)
} else if (file.exists(inputfile)) {
  #check that inputfile exists, because read.settings() doesn't do that!
  settings <- PEcAn.settings::read.settings(inputfile)
} else {
  stop(inputfile, " doesn't exist")
}


#check outdir
settings$outdir

# Prepare settings --------------------------------------------------------
settings <- prepare.settings(settings)
settings <- do_conversions(settings)

# Query trait database ----------------------------------------------------
#skip if this was already done
exp_trait_files <- file.path(settings$pfts |> map_chr("outdir"), "trait.data.Rdata")
if(!all(file.exists(exp_trait_files))) {
  settings <- runModule.get.trait.data(settings)
}
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

job_scripts <- list.files(settings$rundir, "job.sh", recursive = TRUE, full.names = TRUE)
#TODO: could get this from settings under the assumption that the .sh "ED binary" has same naming convention as .sif file
container_path <- "/groups/dlebauer/ed2_results/global_inputs/pecan-dev_ed2-dev.sif"

purrr::walk(job_scripts, function(x) {
  job_sh <- readLines(x)
  cmd <- paste0("singularity run ", container_path, " /usr/local/bin/Rscript")
  job_sh_mod <- stringr::str_replace(job_sh, "Rscript", cmd)
  writeLines(job_sh_mod, x)
})

# Start model runs --------------------------------------------------------

## This copies config files to the HPC and starts the run
## Sometimes not everything gets copied over (still) and you'll need to run this twice.
runModule_start_model_runs(settings, stop.on.error = FALSE)

# Model analyses ----------------------------------------------------------

## Get results of model runs
get.results(settings)

## Run ensemble analysis on model output
runModule.run.ensemble.analysis(settings)
