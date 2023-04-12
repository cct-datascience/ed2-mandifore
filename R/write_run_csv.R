#' Collect timeseries data from .nc files output by PEcAn.ED2
#'
#' Extracts data from the .nc files created by `model2netcdf.ED2()` into a
#' tibble and then writes the result to a CSV.  
#' 
#' @note Some data is inferred from the path to the files, so this function is
#'   not very portable as it is written.
#'
#' @param ensemble a path to a single ensemble run output directory
#' @param overwrite logical; if the output run_data.csv already exists, should
#'   it be overwritten?
#'
#' @return the path to the output run_data.csv file
#'
#' @examples
#' library(fs)
#' library(purrr)
#' base_path <- "/data/output/pecan_runs/transect"
#' sites <- dir_ls(base_path, recurse = 1, regexp = "mixed$|prairie$|pine$")
#' ensembles <- dir_ls(path(sites, "out"), regexp = "ENS-")
#' 
#' paths <- 
#' map_chr(ensembles, \(x) write_run_csv(x, overwrite = FALSE), .progress = TRUE) |>
#' discard(is.na) 
#' 
write_run_csv <- function(ensemble, overwrite = FALSE) {
  if(file_exists(path(ensemble, "run_data.csv"))) {
    if(overwrite) {
      warning("Overwriting run_data.csv")
    } else {
      warning("run_data.csv already exists")
      return(path(ensemble, "run_data.csv"))
    }
  }
  
  nc_files <- ensemble |>
    dir_ls(glob = "*.nc") 
  
  #check that nc_files exist
  if(length(nc_files) == 0) {
    warning("No .nc files found!")
    return(NA)
  }
  
  nc_files|> 
    map(\(nc_file) {
      tidync(nc_file) |> 
        activate("D0,D1,D2,D3") |> 
        hyper_tibble() |> 
        # get data from file name into tibble
        mutate(
          ensemble = path_split(nc_file) |> map_chr(-2),
          ecosystem = path_split(nc_file) |> map_chr(-4),
          site = path_split(nc_file) |> map_chr(-5),
          year = path_file(nc_file) |> str_remove("\\.nc"),
          date = (make_date(year, month = 1, day = 1) + days(dtime)) |>
            # I don't think PEcAn knows about leap years
            floor_date(unit = "month")
        ) |> 
        select(-dtime, -year)
    }) |> bind_rows() |> 
    write_csv(path(ensemble, "run_data.csv"))
  return(path(ensemble, "run_data.csv"))
}