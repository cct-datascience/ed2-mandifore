library(fs)
library(tidyverse)
library(lubridate)
library(tidync)
source("R/write_run_csv.R")

base <- c("/data/output/pecan_runs/transect/", "/data/output/pecan_runs/seus_sample/")

dir_ls(base) |> 
  dir_ls(recurse = 1, regexp = "mixed$|prairie$|pine$") |> 
  path("out") |> 
  #for now just wrangle output of the three "genotypes".  Ensemble output has already been wrangled into csv files
  dir_ls(regexp = "SA-SetariaWT2-quantum_efficiency-0.159$|SA-SetariaWT2-fineroot2leaf-0.841$|SA-SetariaWT2-stomatal_slope-0.159$|SA-median") |> 
  walk(\(x) write_run_csv(x, overwrite = FALSE), .progress = TRUE)
  