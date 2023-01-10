#' Simplify and modify .css files
#' 
#' The .css files need to be simplified by taking only a single year and a
#' single value for each patch, cohort, and pft.  Then, Setaria gets added into
#' each patch. Finally, outdated PFTs are replaced.
#'
#' @param css a tibble of the css file
#' @param dbh dbh for Setaria pft.  Default is 0.6 cm
#' @param dens density for Setaria pft.  Default is 1 plant / m^2
#'
#' @return a tibble
modify_css <- function(css, dbh = 0.6, dens = 1) {
  # make sure there is a single value for each time, patch, cohort, pft
  # combination
  css <-
    css |> 
    group_by(time, patch, cohort, pft) |> 
    summarize(across(c(dbh, hite), median), 
              across(c(n, bdead, balive, lai), sum),
              .groups = "drop")|> 
    filter(time == max(time)) #only get last year
  
  setaria <- 
    css |> 
    # get unique combinations of time and patch
    group_by(time, patch) |> 
    slice(1) |> 
    # replace with Setaria
    mutate(
      cohort = NA,  
      pft = 1,
      dbh = {{dbh}},    #dbh 0.6 cm
      n = {{dens}}      #1 plant per m^2
      # dbh = 0.6,
      # n = 1
    ) 
  
  # Set cohort for Setaria---must be unique for the patch, but arbitary.  Sum of
  # all the other cohort numbers will be unique.
  #TODO only has to be unique for that PFT.  So could be 0 unless there's another PFT 1 already
  css <-
    bind_rows(css, setaria) |> 
    mutate(cohort = if_else(is.na(cohort), sum(unique(cohort), na.rm = TRUE), cohort)) |> 
    
    #For debugging: only use one cohort per patch per pft
    group_by(time, patch, pft) |> 
    slice_head(n=1) |> 
    ungroup()
  
  # replace obsolete PFTs
  # TODO: this replacements may not be correct!
  css <- 
    css |> 
    # mutate(pft = case_when(
    #   pft == 12 ~ 9, #temperate.Early_Hardwood
    #   pft == 13 ~ 10, #temperate.Mid_Hardwood 
    #   pft == 14 ~ 8, #temperate.Evergreen_Hardwood
    #   pft == 3 ~ 8, #temperate.Evergreen_Hardwood
    #   TRUE ~ pft
    # )) |> 
    # column order is important
    select(time, patch, cohort, dbh, hite, pft, n, bdead, balive, lai) 
    
  css
}