### Latin Hypercube Sampling of Sites

# Load packages -----------------------------------------------------------
library(tidyverse)
library(clhs) #conditioned latin hypercube sampling
library(fs)
set.seed(123)

# Map data ----------------------------------------------------------------
states <- 
  map_data("state") |> 
  filter(region %in% c(
    "florida",
    "georgia",
    "alabama", 
    "south carolina", 
    "north carolina",
    "virginia",
    "maryland",
    "mississippi",
    "tennessee",
    "arkansas",
    "louisiana",
    "texas",
    "kentucky",
    "missouri",
    "illinois",
    "oklahoma"
  ))


# Sample sites ----------------------------------------------------------
new_sites <- read_csv("data/mandifore_sites.csv")

#don't want to include sites that have already been run as part of the transect
done <- dir_ls("/data/output/pecan_runs/transect/") |> path_file()

transect <- 
  new_sites |> 
  filter(sitename %in% done)

seus <-
  new_sites |> 
  filter(str_detect(sitename, "SEUS")) |> 
  filter(!sitename %in% done)

# draw samples and force it to include the 9 transect sites.  We'll filter those
# out later, but we want other 20 samples to be sufficiently spread out from the
# sites that are already done.
sample_ind <- 
  clhs(bind_rows(transect, seus), size = 29, must.include = 1:9, use.cpp = FALSE)

seus_sample <-
  bind_rows(transect, seus) %>%
  slice(sample_ind) |> 
  filter(!sitename %in% done) 

seus_rand <- 
  seus |> 
  slice_sample(n = 20)

# plot to check that it's more spread out than random
ggplot(states, aes(lon, lat)) +
  geom_polygon(aes(long, lat, group = group), fill = "white", color = "grey") +
  geom_point(data = seus, alpha = 0.2) +
  geom_point(data = seus_sample, aes(color = "LHS", shape = "LHS")) +
  geom_point(data = seus_rand, aes(color = "random", shape = "random")) +
  coord_quickmap() +
  theme_void() +
  labs(color = "Sample Type", shape = "Sample Type")

# plot of new sites and transect sites
ggplot(states, aes(lon, lat)) +
  geom_polygon(aes(long, lat, group = group), fill = "white", color = "grey") +
  geom_point(data = seus, alpha = 0.2) +
  geom_point(data = seus_sample, color = "darkred", shape = "triangle", size = 3) +
  geom_point(data = transect, color = "darkgreen", shape = "square", size = 3) +
  coord_quickmap() +
  theme_void() 

write_csv(seus_sample, "data/seus_sample20.csv")
