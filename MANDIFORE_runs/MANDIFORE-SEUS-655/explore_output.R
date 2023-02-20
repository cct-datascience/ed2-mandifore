library(tidync)
library(fs)
library(tidyverse)

ens_dirs <-
  fs::dir_ls("MANDIFORE_big_run/MANDIFORE-SEUS-655/outdir/out/")

ensemble_data <-
  map(ens_dirs, \(dir) {
    # for each ensemble...
    # get all the file names
    h5s <- fs::dir_ls(dir, regexp = "analysis-E-.*h5$")
    run <- 
      # for each file in a full run ...
      map(h5s, \(file) {
        # open a connection and read metadata
        nc <- tidync(file)
        
        # extract variables that are by cohort (D0)
        by_cohort <- 
          nc |>
          activate("D0") |>
          hyper_tibble(select_var = c(
            "DBH", #diameter at breast height (cm)
            "DDBH_DT", #change in DBH (cm/plant/yr) 
            "AGB_CO", #cohort level above ground biomass (kgC/plant)
            "MMEAN_NPPDAILY_CO", #net primary productivity (kgC/m2/yr)
            "MMEAN_TRANSP_CO", #Monthly mean leaf transpiration (kg/m2/s)
            "BSEEDS_CO", #seed biomass in units of (kgC/plant)
            "NPLANT", #plant density (plants/m2), required for /plant -> /m2 conversion
            "PFT"
          ))
        
        # extract by-patch variables that identify cohorts to patches and some patch data
        by_patch <- 
          nc |> 
          activate("D4") |> 
          hyper_tibble(select_var = c("AGE", "AREA", "PACO_ID", "PACO_N"))
        
        # join patch data with cohort data.  PACO_ID is the "index of the first
        # cohort of each patch", so I use a rolling join (requires dplyr >=
        # 1.1.0) to combine them.
        left_join(by_cohort, by_patch, join_by(closest(phony_dim_0 >= PACO_ID))) |>
          rename("cohort" = phony_dim_0, "patch" = phony_dim_4) |> 
          #dates in filename are not valid because day is 00.  Extract just year
          #and month and use lubridate to build date
          mutate(date = str_match(basename(file), "(\\d{4}-\\d{2})-\\d{2}")[,2] |> lubridate::ym())
      }) 
    bind_rows(run) |> mutate(ensemble = basename(dir))
  }) |> bind_rows()

write_csv(ensemble_data, "MANDIFORE_big_run/MANDIFORE-SEUS-655/ensemble_data.csv")
ensemble_data <- read_csv("MANDIFORE_big_run/MANDIFORE-SEUS-655/ensemble_data.csv")
ensemble_data <- 
  ensemble_data |> 
  mutate(pft_name = case_when(
  PFT==1  ~ "SetariaWT",
  PFT==7  ~ "Southern_pine",
  PFT==10 ~  "South_Mid_Hardwood",
  PFT==8  ~ "Evergreen_Hardwood",
  PFT==5  ~ "c3grass",
  PFT==14 ~  "c4grass",
  PFT==12 ~  "forb"
))

agb_single_ens <- 
  ensemble_data |> 
  filter(ensemble == "ENS-00009-1000014289") |> 
  group_by(patch, pft_name, date) |> 
  summarize(AGB = sum(AGB_CO)) #add up cohorts within each patch/pft combo

agb_single_ens |> 
  ggplot(aes(x = date, y = AGB)) +
  geom_line(aes(color = pft_name)) +
  facet_wrap(~patch, scales = "free_y", labeller = "label_both")
