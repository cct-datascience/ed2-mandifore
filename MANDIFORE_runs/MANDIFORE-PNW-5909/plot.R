library(tidync)
library(tidyverse)
library(lubridate)
library(units)
library(PEcAn.settings)
library(patchwork)

# read in the two years of output
# TODO: generalize and parallelize using furr_map()
df_2002 <- 
  tidync("MANDIFORE_runs/MANDIFORE-PNW-5909/outdir/out/ENS-00001-1000021575/2002.nc") |> 
  activate("D0,D1,D5,D6") |> 
  hyper_tibble() |> 
  mutate(date = ymd("2002-01-01") + days(dtime))

df_2003 <- 
  tidync("MANDIFORE_runs/MANDIFORE-PNW-5909/outdir/out/ENS-00001-1000021575/2003.nc") |> 
  activate("D0,D1,D5,D6") |> 
  hyper_tibble()|> 
  mutate(date = ymd("2003-01-01") + days(dtime))

# standard_vars |> 
#   as_tibble() |> 
#   filter(Variable.Name == "NPP")

#Bind together, tidy, set units
df <- bind_rows(df_2002, df_2003,.id = "year") |> 
  mutate(pft = as.factor(pft)) |> 
  #set units
  mutate(
    AGB_PFT = set_units(AGB_PFT, "kg m-2"),
    NPP_PFT = set_units(NPP_PFT, "kg m-2 s-1")
    )
# Plot above ground biomass and NPP
agb_plot <- 
  ggplot(df, aes(x = date, y = AGB_PFT, color = pft)) +
  geom_line() +
  scale_x_date(date_breaks = "3 months") +
  labs(
    # title = "MANDIFORE-PNW-5909",
    color = "PFT",
    y = "AGB",
    x = "Date"
    ) +
  theme_bw()
# agb_plot

npp_plot <- 
  ggplot(df, aes(x = date, y = NPP_PFT, color = pft)) +
  geom_line() +
  scale_x_date(date_breaks = "3 months") +
  labs(
    # title = "MANDIFORE-PNW-5909",
    color = "PFT",
    y = "NPP",
    x = "Date"
  ) +
  theme_bw()
# npp_plot

#Get weather data to plot along with this for the MSR

settings <- read.settings("MANDIFORE_runs/MANDIFORE-PNW-5909/outdir/settings_checked.xml")

#path to driver header
met <- settings$run$inputs$met$path
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

(agb_plot + theme(axis.text.x = element_blank(), axis.title.x = element_blank()))/
(npp_plot + theme(axis.text.x = element_blank(), axis.title.x = element_blank()))/
(precip_plot + theme(axis.text.x = element_blank(), axis.title.x = element_blank())) / 
(tmp_plot) +
  plot_annotation(title = "MANDIFORE-PNW-5909") +
  plot_layout(guides = "collect")

ggsave("MSR.png", path = settings$outdir, height = 7, width = 7)
