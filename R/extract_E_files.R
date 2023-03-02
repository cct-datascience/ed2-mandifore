#' Extract data from -E- files for an ensemble run
#'
#' Provides an alternative to the (mostly broken)
#' `PEcAn.ED2::model2netcdf.ED2()` function.  This reads in all the .h5 files
#' from all the ensemble members for a run and returns a single data frame, so
#' it might take some time to run.  A progress bar will display after a while
#' with an ETA.
#'
#' @param dir path to the out/ directory containing the ensemble folders
#' @param pattern a regular expression to match the individual ensemble member
#'   output folders.  Default can be overridden to match sensitivity analysis
#'   runs (maybe)
#'
#' @return a tibble
#'
#' @example 
#' df <- extract_E_files("MANDIFORE_runs/MANDIFORE-SEUS-5205/outdir/out/")
#' 
extract_E_files <- function(dir, pattern = "ENS-\\d+-\\d+$") {
  ens_dirs <-
    fs::dir_ls(dir, regexp = pattern)
  purrr::map(ens_dirs, extract_E_file, .progress = "Reading .h5 files") |> 
    purrr::set_names(basename(ens_dirs)) |> 
    dplyr::bind_rows(.id = "ensemble")
}


#' Extract data from -E- files for a single ensemble member
#'
#' This is what's under the hood of `extract_E_files()`
#' 
#' @param ens_dir a path to a single ensemble member output
#'
#' @return a tibble
#' 
extract_E_file <- function(ens_dir, do_conversions = TRUE) {
  e_files <- fs::dir_ls(ens_dir, regexp = "analysis-E-.*h5$")
  if(length(e_files)==0){
    warning("no -E- files found")
    return(NULL)
  } 
  
  cohort_vars <- c(
    "DBH", #diameter at breast height (cm)
    "DDBH_DT", #change in DBH (cm/plant/yr) 
    "AGB_CO", #cohort level above ground biomass (kgC/plant)
    "MMEAN_NPPDAILY_CO", #net primary productivity (kgC/m2/yr) (actual units kg/plant/yr)
    "MMEAN_TRANSP_CO", #Monthly mean leaf transpiration (kg/m2/s) (actual units: probably kg/plant/s) https://github.com/EDmodel/ED2/issues/342
    "BSEEDS_CO", #seed biomass in units of (kgC/plant)
    "NPLANT", #plant density (plants/m2), required for /plant -> /m2 conversion
    "PFT" #pft numbers
  )
  
  patch_vars <- c(
    "AREA", # fractional patch area relative to site area (unitless)
    "AGE", #patch age since last disturbance
    "PACO_N", #number of cohorts in each patch
    "PACO_ID" #index of the first cohort of each patch.  Needed for figuring out which patch each cohort belongs to
  )
  
  # function for a single file.
  foo <- function(file, cohort_vars, patch_vars) {
    nc <- ncdf4::nc_open(file)
    on.exit(ncdf4::nc_close(nc), add = FALSE)
    
    avail_cohort <- cohort_vars[cohort_vars %in% names(nc$var)]
    if(length(avail_cohort) == 0) {
      warning("No cohort-level variables found!")
      return(NULL)
    }
    avail_patch <- patch_vars[patch_vars %in% names(nc$var)]
    if(length(avail_patch) == 0) {
      warning("No patch-level variables found!")
      return(NULL)
    }
    
    cohort_df <-
      purrr::map(avail_cohort, function(.x) ncdf4::ncvar_get(nc, .x)) |> 
      purrr::set_names(avail_cohort) |> 
      dplyr::bind_cols() |> 
      dplyr::mutate(COHORT_ID = 1:n())
    #TODO: cohort ID isn't the same from one timestep to the next
    
    patch_df <- 
      purrr::map(avail_patch, function(.x) ncdf4::ncvar_get(nc, .x)) |> 
      purrr::set_names(avail_patch) |> 
      dplyr::bind_cols() |> 
      dplyr::mutate(PATCH_ID = 1:n())
    #TODO patch ID is *probably* consistent from one timestep to the next, but
    #only because I have turned off patch fusion
    

    # join patch data with cohort data.  PACO_ID is the "index of the first
    # cohort of each patch", so I use a rolling join (requires dplyr >=
    # 1.1.0) to combine them.
    dplyr::left_join(cohort_df, patch_df, dplyr::join_by(closest(COHORT_ID >= PACO_ID))) |>
      #not 100% sure why, but some columns are 1 dimensional arrays instead of vectors.
      mutate(across(where(is.array), as.numeric)) |> 
      #dates in filename are not valid because day is 00.  Extract just year
      #and month and use lubridate to build date
      dplyr::mutate(date = stringr::str_match(basename(file), "(\\d{4}-\\d{2})-\\d{2}")[,2] |> lubridate::ym()) |> 
      dplyr::select(date, everything()) |> 
      dplyr::select(-PACO_ID)
  }
  
  raw <- 
    purrr::map(e_files, ~foo(.x, cohort_vars, patch_vars)) |> 
    dplyr::bind_rows() |> 
    #set units
    mutate(
      DBH = units::set_units(DBH, "cm"), 
      DDBH_DT = units::set_units(DDBH_DT, "cm/plant/yr"),
      AGB_CO = units::set_units(AGB_CO, "kg/plant"), 
      MMEAN_NPPDAILY_CO = units::set_units(MMEAN_NPPDAILY_CO, "kg/plant/yr"),
      MMEAN_TRANSP_CO = units::set_units(MMEAN_TRANSP_CO, "kg/plant/s"),
      BSEEDS_CO = units::set_units(BSEEDS_CO, "kg/plant"), 
      NPLANT = units::set_units(NPLANT, "plant/m^2")
    )
  
  if(isFALSE(do_conversions)) {
    return(raw)
    
  } else {
    # unit conversions
    # input units are according to the ED2 source code:
    # https://raw.githubusercontent.com/EDmodel/ED2/master/ED/src/memory/ed_state_vars.F90,
    # output units are according to PEcAn.utils::standard_vars
    out <- raw |>
      dplyr::mutate(
        #per unit area corrections
        dplyr::across(c(BSEEDS_CO, AGB_CO, MMEAN_NPPDAILY_CO, MMEAN_TRANSP_CO), ~.x*NPLANT),
        #pecan standard units
        MMEAN_NPPDAILY_CO = units::set_units(MMEAN_NPPDAILY_CO,"kg/m^2/s")
      ) |> 
      # weight by patch area and sum across cohorts and patches
      group_by(date, PFT) |> 
      summarize(
        across(c(BSEEDS_CO, AGB_CO, MMEAN_NPPDAILY_CO, MMEAN_TRANSP_CO, NPLANT),
               ~sum(.x*AREA)),
        DBH_mean = mean(DBH)
      )
    return(out)
  }
}

