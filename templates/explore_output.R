library(tidync)
library(fs)
library(tidyverse)
library(lubridate)
library(ggforce)
library(units)
install_unit("plants", def = "unitless")

source("R/extract_nc_files.R")

settings_path <- "/data/output/pecan_runs/MANDIFORE_big_run/MANDIFORE-SEUS-655/pine/settings_checked.xml"
settings <- PEcAn.settings::read.settings(settings_path)

# In case you want to re-run model2netcdf.ED2 locally for some reason
# dir_ls(settings$modeloutdir, regexp = "ENS") |> 
#   walk(~{
#     model2netcdf.ED2(.x, settings = settings)
#   })


# Extract data from ensemble runs -----------------------------------------
ens_data_raw <- 
  dir_ls(settings$modeloutdir, regexp = "ENS") |> 
  map(extract_run) |> 
  bind_rows(.id = "filepath") |> 
  mutate(run_id = path_file(filepath)) |> 
  select(-filepath) |> 
  select(run_id, date, everything()) 

ens_data <- ens_data_raw |> 
  mutate(pft_name = case_when(
   pft == 1  ~ "SetariaWT",
   pft == 7  ~ "Southern_pine",
   pft == 10 ~  "South_Mid_Hardwood",
   pft == 8  ~ "Evergreen_Hardwood",
   pft == 5  ~ "c3grass",
   pft == 14 ~  "c4grass",
   pft == 12 ~  "forb"
  )) |> 
  # set units with {units}
  mutate(
    AGB_PFT = set_units(AGB_PFT, "kg/m^2"),
    NPP_PFT = set_units(NPP_PFT, "kg/m^2/s"),
    TRANSP_PFT = set_units(TRANSP_PFT, "kg/m^2/s"),
    DENS = set_units(DENS, "plants/m^2"),
    BSEEDS = set_units(BSEEDS, "kg/m^2"),
    DBH = set_units(DBH, "cm")
  )
  

plot_df <- ens_data |>
  group_by(date, pft_name) |> 
  summarize(across(
    c(AGB_PFT, NPP_PFT, TRANSP_PFT, DENS),
    .fns = list(
      mean = mean,
      median = median,
      lower = ~ quantile(., probs = 0.25),
      upper = ~ quantile(., probs = 0.75)
    )
  ), .groups = "drop")

ts_plot <- function(data, var, ylab) {
  
  data |> 
    ggplot(aes(x = date, color = pft_name, fill = pft_name)) +
    geom_line(aes_string(y = paste(var, "median", sep = "_"))) +
    geom_ribbon(aes_string(ymin = paste(var, "lower", sep = "_"), ymax = paste(var, "upper", sep = "_")), alpha = 0.4, color = NA) +
    labs(y = ylab, x = "Simulation Date", color = "PFT", fill = "PFT") +
    theme_bw()
}

ts_plot(plot_df, c("Plant Density" = "DENS"))
#take a named vector to plot them all
x <- 
  c(
    "Plant density" = "DENS",
    "Above-ground biomass" = "AGB_PFT",
    "Leaf transpiration" = "TRANSP_PFT",
    "Net primary productivity" = "NPP_PFT"
  ) |> 
  imap(~ts_plot(plot_df, .x, .y)) 

library(patchwork)

wrap_plots(x, ncol = 2) + plot_layout(guides = "collect")

