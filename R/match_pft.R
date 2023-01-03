#' Match ED2 pfts with PEcAn PFTs depending on site location
#'
#' @param pft numeric vector of ED2 pft numbers from .css file
#' @param loc location, either "PNW" or "SEUS"
#'
#' @return a tibble with `ED` and `PEcAn` columns
#' 
match_pft <- function(pft, loc = c("PNW", "SEUS")) {
  #nothing done with this arg yet, but case_when below will be conditional on it likely
  loc <- match.arg(loc)
  
  left_join(tibble(ED = pft), PEcAn.ED2::pftmapping, by = "ED") %>%
    group_by(ED) %>% 
    slice(1) |> 
    mutate(PEcAn = case_when(
      loc == "SEUS" & pft == 1 ~ "temperate.Evergreen_Hardwood",
      loc == "SEUS" & pft == 2 ~ "temperate.Hydric",
      loc == "SEUS" & pft == 3 ~ "temperate.Late_Conifer",
      loc == "SEUS" & pft == 4 ~ "temperate.Late_Hardwood",
      loc == "SEUS" & pft == 5 ~ "temperate.North_Mid_Hardwood",
      loc == "SEUS" & pft == 6 ~ "temperate.Southern_Pine",
      loc == "SEUS" & pft == 7 ~ "temperate.South_Mid_Hardwood",
      loc == "SEUS" & pft == 8 ~ "temperate.Early_Hardwood", # 8 is also used for temperate.Northern_Pine, but not able to figure this out currently
      TRUE ~ NA_character_ #make all other PFTs just not work for now I guess
    ))
}

