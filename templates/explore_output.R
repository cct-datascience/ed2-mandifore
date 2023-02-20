library(tidync)
library(fs)
library(tidyverse)
library(lubridate)

source("R/extract_E_files.R")

ensemble_data <- extract_E_files("MANDIFORE_big_run/MANDIFORE-SEUS-352/outdir/out/")
write_csv(ensemble_data, "MANDIFORE_big_run/MANDIFORE-SEUS-352/ensemble_data.csv")
ensemble_data <- read_csv("MANDIFORE_big_run/MANDIFORE-SEUS-352/ensemble_data.csv")
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
