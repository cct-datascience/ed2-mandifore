#' Simplify and modify .pss file
#'
#' Upgrades .pss file by adding required dummy columns, changing column names,
#' and removing unused columns. Removes patches that aren't found in
#' corresponding .css file and re-scale the area of the patches so they sum to
#' 1.
#'
#' @param pss tibble, a pss file
#' @param css tibble, a css file
#'
#' @return tibble
modify_pss <- function(pss, css) {
  pss <- pss |> 
    select(-site, lai = psc) |> 
    # add dummy columns
    add_column(nep = 0, gpp = 0, rh = 0) |> 
    # remove patches that don't exist in the css files
    filter(patch %in% unique(css$patch)) |> 
    filter(time == max(time)) |> 
    # rescale area
    mutate(area = area/sum(area)) |> 
    #column order is important
    select(time, patch, trk, age, area, water, fsc, stsc, stsl, ssc, lai, msn, fsn, nep, gpp, rh)
  
  pss
}