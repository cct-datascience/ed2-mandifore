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
      ED == 1 ~ "SetariaWT",
      #temporary.  This actually depends on whether its PNW or SEUS
      loc == "PNW" & ED == 9 ~ "temperate.Early_Hardwood", 
      loc == "PNW" & ED == 10 ~ "temperate.North_Mid_Hardwood",
      ED == 8 ~ "temperate.Evergreen_Hardwood",
      ED == 11 ~ "temperate.Late_Hardwood",
      TRUE ~ PEcAn
    ))
}
# match_pft(c(9, 14, 12))
