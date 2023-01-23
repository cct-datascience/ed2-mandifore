library(DBI)
library(tidyverse)

# Open connection ---------------------------------------------------------
con <- dbConnect(RSQLite::SQLite(), dbname = "data/SQLite_FIADB_GA.db")
dbListTables(con)


# Scope out forest types --------------------------------------------------

# plot types to filter to get just oak-hickory, for example
tbl(con, "REF_FOREST_TYPE") |> 
  collect() |> View()
#e.g. oak/hickory is 500.  Not sure where that is in the tree table though

#links PLOT and forest type (FORTYPCD)
plot <-
  tbl(con, "COND") |> 
  filter(FORTYPCD %in% c(500, 503, 605)) |> 
  #just get identifiers
  select(PLT_CN)


#Tree species (SPCD) in plots (PLOT) and subplots (SUBP)
oak_hickory <- left_join(plot, tbl(con, "TREE"))

#summarize

summary <- 
  oak_hickory |> 
  group_by(PLT_CN, PLOT, SUBP, SPCD) |> 
  summarize(n = n(), DIA_median = median(DIA)) #in inches
  
#subplots are 24.0 foot radius circles, approx. 1/24 acre

sp <- tbl(con, "REF_SPECIES") |> select(SPCD, COMMON_NAME, GENUS, SPECIES, SPECIES_SYMBOL)
left_join(summary, sp) |> arrange(desc(n), SPCD) |> collect() |>  View()

#TODO: join REF_SPECIES earlier and summarize by Genus level instead of species
#TODO: summarize by subplot, then by plot to get mean density and DBH.
#TODO: convert units

