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
  
  if(loc == "SEUS") {
    
    sapply(pft, switch,
           "1" = "temperate.Evergreen_Hardwood",
           "2" = "temperate.Hydric",
           "3" = "temperate.Late_Conifer",
           "4" = "temperate.Late_Hardwood",
           "5" = "temperate.North_Mid_Hardwood",
           "6" = "temperate.Southern_Pine",
           "7" = "temperate.South_Mid_Hardwood",
           "8" = "temperate.Early_Hardwood", # 8 is also used for temperate.Northern_Pine, but not able to figure this out currently
           NA_character_ #make all other PFTs just not work for now I guess
    )
  } else {
    stop("Don't know PNW PFT mappings yet!")
  }
}
# match_pft(c(8, 7), loc = "SEUS")

