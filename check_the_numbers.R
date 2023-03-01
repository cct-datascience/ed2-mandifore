library(tidync)
library(ncdf4)
library(tidyverse)
library(lubridate)
library(units)
install_unit("plant", def="unitless")

e_file <- "/data/output/pecan_runs/MANDIFORE_big_run/MANDIFORE-SEUS-352/out/SA-median/analysis-E-2005-02-00-000000-g01.h5"

# -E- file ----------------------------------------------------------------

# look up metadata
e_nc <- nc_open(e_file)
ncatt_get(e_nc, "MMEAN_NPPDAILY_CO")
ncatt_get(e_nc, "MMEAN_NPPDAILY_PY")
ncatt_get(e_nc, "NPLANT")
ncatt_get(e_nc, "PFT")
ncatt_get(e_nc, "PACO_N")
ncatt_get(e_nc, "SIPA_N")
ncatt_get(e_nc, "PYSI_N")

# Extract cohort-level variables from E file
e_cohort <-
  tidync(e_file) |> 
  activate("D0") |> 
  hyper_tibble(select_var = c(
    "MMEAN_NPPDAILY_CO", #"Monthly mean - Net primary productivity - total [kgC/m2/yr]" but actual units are kgC/plant/yr https://github.com/EDmodel/ED2/issues/342
    "PFT", #ED2 PFT number
    "NPLANT" # "Plant density [plant/m2]"
    )) |> 
  mutate(
    MMEAN_NPPDAILY_CO = set_units(MMEAN_NPPDAILY_CO, "kg/plant/yr"),
    NPLANT = set_units(NPLANT, "plant/m^2")
  )

# Extract polygon-level variables from E file

e_polygon <- 
  tidync(e_file) |> 
  activate("D4")|>
  hyper_tibble(select_var = c(
    "AREA",
    "PACO_ID", # "First index for patch
    "PACO_N" # Cohort count in each patch
  ))
# rolling-join (not actually necessary in this single-patch example)
e_df <- 
  left_join(e_cohort, e_polygon, join_by(closest(phony_dim_0 >= PACO_ID)))

e_df

# Polygon-level total
target <- 
  tidync(e_file) |>
  activate("D1") |>
  hyper_tibble(select_var = c(
    "MMEAN_NPPDAILY_PY"#, # "Monthly mean - Net primary productivity - total [kgC/m2/yr]"
  )) |> 
  mutate(
    MMEAN_NPPDAILY_PY = set_units(MMEAN_NPPDAILY_PY, "kg/m^2/yr")
  ) |> pull(MMEAN_NPPDAILY_PY)

# does it all add up?
tot <- e_df |> 
  summarize(npp_total = sum(MMEAN_NPPDAILY_CO*NPLANT*AREA)) |> pull(npp_total)
waldo::compare(tot, target, tolerance = 0.01)
