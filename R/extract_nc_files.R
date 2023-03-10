#' Extract data from .nc files in a single run
#' 
#' Extracts data by PFT from .nc files in a single run (e.g. SA-median or a single member of an ensemble run).
#'
#' @param path The path to a single run output (see example)
#'
#' @return a tibble
#' 
#' @examples
#' settings <- PEcAn.settings::read.settings("/data/output/pecan_runs/MANDIFORE_big_run/MANDIFORE-SEUS-655/pine/settings_checked.xml")
#' sa_median_path <- file.path(settings$modeloutdir, "SA-median")
#' extract_run(sa_median_path)
#' 
#' # Or map over a vector of paths
#' library(fs)
#' library(purrr)
#' library(dplyr)
#' 
#' fs::dir_ls(settings$modeloutdir, regexp = "ENS") |> 
#'   purrr::map(extract_run) |> 
#'   dplyr::bind_rows(.id = "filepath")
extract_run <- function(path) {
  
  nc_files <- dir_ls(path, glob = "*.nc")
  years <- gsub(fs::path_file(nc_files), pattern = "*.nc", replacement = "")
  
  map(nc_files, \(.x) {
    year <- gsub(fs::path_file(.x), pattern = "*.nc", replacement = "")
    tidync(.x) |>
      hyper_tibble() |> 
      mutate(date = make_date(year, 01, 01) + dtime) |> 
      select(-dtime)
  }) |> 
    bind_rows()
}



