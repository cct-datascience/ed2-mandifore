library(tidyverse)
library(ggforce) #for facet_zoom()
#data from site SEUS 352 run with all three patches (pine forest, mixed forest, prairie) with 10 ensembles (but not all 10 ran)
ensemble_data <- read_csv("MSRs/2023-02-15/MANDIFORE-SEUS-352_data2.csv")

#add pft names back
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
  filter(ensemble == first(ensemble) ) |> 
  group_by(PATCH_ID, pft_name, date) |> 
  summarize(AGB = sum(AGB_CO)) #add up cohorts within each patch/pft combo

agb_single_ens |> 
  ggplot(aes(x = date, y = AGB)) +
  geom_line(aes(color = pft_name)) +
  facet_wrap(~PATCH_ID, scales = "free_y", labeller = "label_both")

#so weird
ensemble_summary <- 
  ensemble_data |> 
  # filter(ensemble == "ENS-00009-1000014289") |> 
  group_by(ensemble, PATCH_ID, pft_name, date) |> 
  #add up cohorts within each patch/pft combo
  summarize(
    across(c(AGB_CO, MMEAN_NPPDAILY_CO, MMEAN_TRANSP_CO, BSEEDS_CO, NPLANT), sum),
    across(c(DBH, DDBH_DT), mean)
  )

outlier <-
  ensemble_summary |> 
  filter(MMEAN_NPPDAILY_CO > 1) |> pull(ensemble) |> unique()

ensemble_summary <- ensemble_summary |> filter(!ensemble %in% outlier)

run_summary <- 
  ensemble_summary |> 
  group_by(PATCH_ID, pft_name, date) |> 
  summarize(
    across(c(AGB_CO, MMEAN_NPPDAILY_CO, MMEAN_TRANSP_CO, BSEEDS_CO, NPLANT),
           list("mean" = mean, "median" = median, "lower" = ~quantile(., .25), "upper" = ~quantile(., .75)))
  )



# transp <-
  run_summary |> 
  # filter(PATCH_ID == 1) |>
  # filter(date > ymd("2004-01-01")) |>
  ggplot(aes(x = date)) +
  geom_line(aes(y = MMEAN_TRANSP_CO_median, color = pft_name)) +
  # facet_zoom(y = pft_name == "SetariaWT") +
  facet_wrap(~PATCH_ID) +
  labs(x = "Simulation Date", color = "Plant Functional Type", y = "Transpiration (kg/m^2/yr)") +
  theme_bw()
transp

ggsave("MSRs/2023-02-15/transp.png", transp, height = 3.5, width = 9.5, units = "in")

# agb <-
  run_summary |> 
  # filter(PATCH_ID == 5) |>
  # filter(date > ymd("2004-01-01")) |> 
  ggplot(aes(x = date)) +
  geom_line(aes(y = AGB_CO_median, color = pft_name)) +
  # facet_zoom(y = pft_name == "SetariaWT") +
  facet_wrap(~PATCH_ID) +
  labs(x = "Simulation Date", color = "Plant Functional Type", y = "Aboveground Biomass (kg/m^2)") +
  theme_bw()
agb

ggsave("MSRs/2023-02-15/agb.png", agb, height = 3.5, width = 9.5, units = "in")


# npp <-
  run_summary |> 
  filter(PATCH_ID == 1) |>
  filter(date > ymd("2004-01-01")) |>
  ggplot(aes(x = date)) +
  geom_line(aes(y = MMEAN_NPPDAILY_CO_median, color = pft_name)) +
  # facet_wrap(~PATCH_ID,scales = "free_y") +
  facet_zoom(y = pft_name == "SetariaWT") +
  labs(x = "Simulation Date", color = "Plant Functional Type", y = "NPP (kg/m2/s)") +
  theme_bw()

dens <-
  run_summary |> 
  filter(PATCH_ID == 4) |>
  filter(date > ymd("2004-01-01")) |> 
  ggplot(aes(x = date)) +
  geom_line(aes(y = NPLANT_median, color = pft_name)) +
  # facet_zoom(y = pft_name == "SetariaWT") +
  # facet_wrap(~PATCH_ID) +
  labs(x = "Simulation Date", color = "Plant Functional Type", y = "Density (plants/m^2)") +
  theme_bw()
dens
ggsave("MSRs/2023-02-15/density.png", dens, height = 3.5, width = 9.5, units = "in")
