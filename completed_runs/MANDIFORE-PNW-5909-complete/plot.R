library(tidync)
library(tidyverse)
library(lubridate)
library(units)
library(PEcAn.settings)
library(patchwork)

# read in the two years of output
# TODO: generalize and parallelize using furr_map()
settings <- read.settings("MANDIFORE_runs/MANDIFORE-PNW-5909/outdir/settings_checked.xml")

ens_dirs <- list.files(file.path(settings$outdir, "out"), pattern = "ENS-", full.names = TRUE)

nc_files <- list.files(ens_dirs[[1]], pattern = "*.nc$", full.names = TRUE)

df <- 
  map_df(ens_dirs, function(.x) {
    nc_files <- list.files(.x, pattern = "*.nc$", full.names = TRUE)
    #extract and combine data from each year.nc file
    map_df(nc_files, function(.y) {
      year <- stringr::str_remove(basename(.y), "\\.nc")
      tidync(.y) |> 
        activate("D0,D1,D5,D6") |> 
        hyper_tibble() |> 
        mutate(date = make_date(year, 1, 1) + days(dtime))
    })
  }, .id = "ensemble")


# standard_vars |> 
#   as_tibble() |> 
#   filter(Variable.Name == "NPP")

# tidy, set units
df <- 
  df |> 
  mutate(pft = as.factor(pft)) |> 
  #set units
  mutate(
    AGB_PFT = set_units(AGB_PFT, "kg m-2"),
    NPP_PFT = set_units(NPP_PFT, "kg m-2 s-1")
  )

df_summary <- df |> 
  group_by(pft, date) |> 
  summarize(across(
    c(NPP_PFT, AGB_PFT),
    .fns = list(
      mean = mean,
      lower = ~ quantile(.x, 0.025),
      upper = ~ quantile(.x, 0.975)
    )
  ))

# Plot above ground biomass and NPP
agb_plot <- 
  ggplot(df_summary, aes(x = date, color = pft, fill = pft)) +
  geom_line(data = df, aes(y = AGB_PFT, group = ensemble), alpha = 0.4) +
  geom_line(aes(y = AGB_PFT_mean), size = 2) +
  geom_ribbon(aes(ymin = AGB_PFT_lower, ymax = AGB_PFT_upper), color = NA, alpha = 0.4) +
  scale_x_date(date_breaks = "3 months") +
  labs(
    # title = "MANDIFORE-PNW-5909",
    color = "PFT",
    fill = "PFT",
    y = "AGB",
    x = "Date"
    ) +
  theme_bw()
agb_plot

npp_plot <- 
  ggplot(df_summary, aes(x = date, color = pft, fill = pft)) +
  geom_line(data = df, aes(y = NPP_PFT, group = ensemble), alpha = 0.4) +
  geom_line(aes(y = NPP_PFT_mean), size = 2) +
  geom_ribbon(aes(ymin = NPP_PFT_lower, ymax = NPP_PFT_upper), color = NA, alpha = 0.4) +
  scale_x_date(date_breaks = "3 months") +
  labs(
    # title = "MANDIFORE-PNW-5909",
    color = "PFT",
    fill = "PFT",
    y = "NPP",
    x = "Date"
  ) +
  theme_bw()
npp_plot

#Get weather data to plot along with this for the MSR



#path to driver header
met <- settings$run$inputs$met$path |> unlist()
# readLines(met)
met_files <- 
  list.files(dirname(met), pattern = "*.h5", full.names = TRUE) %>% 
  set_names(str_remove(basename(.), "\\.h5"))


# met_meta <- PEcAn.ED2::read_ed_metheader(met)
# met_meta[[1]]$variables
#looks like everything but co2 updates every 10800 seconds

#Read in the met .h5 files (this takes a while)
met_df_raw <- 
  imap_dfr(met_files, ~{
    tidync(.x) |> 
      hyper_tibble() |> 
      add_column(file = .y)
  }) 

# Add datetime column and tidy
met_df_tidy <-
  met_df_raw |> 
  group_by(file) |> 
  select(file, everything()) |> 
  mutate(date = ym(file) + seconds(phony_dim_2 * 10800), .after = file) |> 
  select(-file, -starts_with("phony_dim"))

# met_meta[[1]]$variables

#unit conversions
### need water density for this
wd <- set_units(1000, "kg m-3")

met_df <- 
  met_df_tidy |> 
  ungroup() |> 
  select(date, tmp, prate) |> 
  mutate(
    tmp = set_units(tmp, "K"),
    prate = set_units(prate, "kg m-2 s-1")
  ) |> 
  mutate(
    tmp = set_units(tmp, "degC"),
    prate = set_units(prate / wd, "mm/day")
  )



met_df$date |> range()

# Filter data to just range of ED2 run
met_df_sub <- 
  met_df |> 
  filter(date >= min(df$date), date <= max(df$date)) 

# temperature plot
tmp_plot <- 
  ggplot(met_df_sub, aes(x = date, y = tmp)) + geom_line(color = "orange") +
  scale_x_datetime(date_breaks = "3 months", date_labels = "%b %Y") +
  theme_bw() +
  labs(y = "Temp")

#precip plot
precip_plot <- 
  ggplot(met_df_sub, aes(x = date, y = prate)) + 
  geom_col(color = "darkblue") +
  scale_x_datetime(date_breaks = "3 months") +
  theme_bw() +
  labs(y = "Precip")


# Put it all together and export

msr_plot <- 
  (agb_plot + theme(axis.text.x = element_blank(), axis.title.x = element_blank()))/
  (npp_plot + theme(axis.text.x = element_blank(), axis.title.x = element_blank()))/
  (precip_plot + theme(axis.text.x = element_blank(), axis.title.x = element_blank())) / 
  (tmp_plot) +
  plot_annotation(title = "MANDIFORE-PNW-5909") +
  plot_layout(guides = "collect")

write_csv(met_df, file.path(settings$outdir, "MSR.csv"))
ggsave("MSR.png", plot = msr_plot, path = settings$outdir, height = 7, width = 7)
