library(tidyverse)
#Read all css files and get table of PFTs
new_sites <- read_csv("data/mandifore_sites.csv")



css_files <- 
  list.files(file.path("/data/input", new_sites$cohort_filename), pattern = "*.css", full.names = TRUE) |> 
  set_names(new_sites$sitename)

all_pfts <- map_df(css_files, ~{
  read_table(.x) |> 
    count(pft) |> select(-n)
}, .id = "sitename")

pft_count <- 
  all_pfts |> 
  separate(sitename, into = c("mandifore", "sn", "num")) |> 
  select(sn, pft) |> 
  group_by(pft) |> 
  count(sn) |> 
  pivot_wider(values_from = n, names_from = sn)

write_csv(pft_count, here::here("data/pfts.csv"))

knitr::kable(pft_count)


#find sites in the SEUS with all the PFTs in the example one Mike found (1:8)
seus_known_pfts <- 
  all_pfts |> 
  filter(str_detect(sitename, "SEUS")) |> 
  group_by(sitename) |> 
  filter(all(pft %in% 1:8)) |> pull(sitename) |> unique()
seus_known_pfts
#21 sites that we think we know the PFT mapping for
