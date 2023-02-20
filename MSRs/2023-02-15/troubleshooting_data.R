library(ncdf4)
library(units)
library(tidyverse)
library(lubridate)
source("R/extract_E_files.R")

path <- "MANDIFORE_big_run/MANDIFORE-SEUS-352/outdir/out/ENS-00007-1000014289/"
#make a plant unit
install_unit("plant", def = "unitless", name = "plant")

df_raw <- extract_E_file(path, do_conversions = FALSE)

df <- df_raw |> 
  #convert arrays to numeric.  gotta fix this in extract_E_file()
  mutate(across(where(is.array), as.numeric)) |> 
  select(date, DBH, AGB_CO, MMEAN_NPPDAILY_CO, MMEAN_TRANSP_CO, NPLANT, PFT, COHORT_ID, PATCH_ID, PACO_N, AREA) |> 
  mutate(pft_name = case_when(
    PFT==1  ~ "SetariaWT",
    PFT==7  ~ "Southern_pine",
    PFT==10 ~  "South_Mid_Hardwood",
    PFT==8  ~ "Evergreen_Hardwood",
    PFT==5  ~ "c3grass",
    PFT==14 ~  "c4grass",
    PFT==12 ~  "forb"
  )) 

#set units according to metadata
file <- list.files(path, pattern = "analysis-E-", full.names = TRUE)[1]
nc <- nc_open(file)

ncatt_get(nc, "AGB_CO") #kg/plant
ncatt_get(nc, "NPLANT") #plant/m2
ncatt_get(nc, "MMEAN_NPPDAILY_CO") #kg/m2/yr
ncatt_get(nc, "MMEAN_TRANSP_CO") #kg/m2/s
ncatt_get(nc, "DBH") #cm
ncatt_get(nc, "AREA") #unitless 0-1, patch area relative to site

df <- 
  df |> 
  mutate(
    AGB_CO = set_units(AGB_CO, "kg/plant"),
    NPLANT = set_units(NPLANT, "plant/m^2"),
    MMEAN_NPPDAILY_CO = set_units(MMEAN_NPPDAILY_CO, "kg/m^2/yr"),
    MMEAN_TRANSP_CO = set_units(MMEAN_TRANSP_CO, "kg/m^2/s"),
    DBH = set_units(DBH, "cm")
  )


#looks reasonable.  LOTS of pine seedlings though
ggplot(df) +
  geom_histogram(aes(AGB_CO, after_stat(ndensity)), color = "black") +
  facet_wrap(~pft_name, scales = "free_x") +
  labs(title = "AGB_CO, uncorrected", y = "frequency")

ggplot(df) +
  geom_histogram(aes(NPLANT, after_stat(ndensity)), color = "black") +
  facet_wrap(~pft_name, scales = "free_x") +
  labs(title = "NPLANT, uncorrected")


df |> 
  filter(pft_name == "Southern_pine") |> 
  ggplot(aes(x = DBH, y = AGB_CO)) +
  geom_point(alpha = 0.1)

ggplot(df) +
  geom_histogram(aes(MMEAN_NPPDAILY_CO, after_stat(ndensity)), color = "black") +
  facet_wrap(~pft_name, scales = "free_x") +
  labs(title = "NPP, untransformed")

ggplot(df) +
  geom_point(aes(x = DBH, y = MMEAN_NPPDAILY_CO, color = as.numeric(AGB_CO)), alpha = 0.1) +
  facet_wrap(~pft_name)

df |> 
  filter(pft_name == "SetariaWT") |> 
  filter(date == nth(unique(date), 80)) |> 
  ggplot() +
  geom_point(aes(x = COHORT_ID, y = DBH, color = MMEAN_NPPDAILY_CO |> as.numeric()))  

df |> 
  filter(DBH == set_units(0, "cm")) |>
  filter(as.numeric(MMEAN_NPPDAILY_CO) < 1)          

#check that number of cohorts is correct
df |> 
  group_by(date, PATCH_ID) |> 
  summarize(ncohorts = n(),
            ncohorts_exp = first(PACO_N)
            ) |> filter(ncohorts != ncohorts_exp)
#yup, got em all  

combined <- df |> 
  #convert to kg/m2
  mutate(AGB = AGB_CO * NPLANT,
         #what if the ED2 metadata is wrong, does the output make sense now?
         NPP_per_plant = set_units(as.numeric(MMEAN_NPPDAILY_CO), "kg/plant/yr"),
         NPP = NPP_per_plant * NPLANT) |> 
  #add up all the cohorts of the same PFT in each patch
  group_by(date, PATCH_ID, pft_name) |> 
  summarize(
    AGB = sum(AGB),
    NPP = sum(NPP)
  ) |> 
  ungroup()

ggplot(combined) +
  geom_histogram(aes(AGB)) +
  facet_wrap(~pft_name, scales = "free_x")

#i dunno, seems reasonable.  Trees are tall, right?

ggplot(combined) +
  geom_histogram(aes(NPP, after_stat(ndensity)), color = "black") +
  facet_wrap(~pft_name, scales = "free_x")


combined |> 
  filter(month(date)==4) |> 
ggplot() +
  geom_histogram(aes(NPP, after_stat(ndensity)), color = "black") +
  facet_wrap(~pft_name, scales = "free_x") +
  labs(title = "Just April Values")
