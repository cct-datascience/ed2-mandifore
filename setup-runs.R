
# load packages and functions -----------------------------------------------------------

library(tidyverse)
library(PEcAn.settings)

source("R/modify_css.R")
source("R/modify_pss.R")
source("R/match_pft.R")

set.seed(123)

# load site info ----------------------------------------------------------

new_sites <- read_csv("data/mandifore_sites.csv")
#just sample 3 for now to test iteration
sites <- slice_sample(new_sites, n=3)
sites


# create working directories ----------------------------------------------
wds <- paste("MANDIFORE_runs", sites$sitename, sep = "/")

wds |> 
  walk(~{
    dir.create(.x)
    file.copy(file.path("templates", "pecan_template.xml"),
              file.path(.x, "pecan.xml"))
    file.copy(file.path("templates", "workflow_template.R"),
              file.path(.x, "workflow.R"))
  })


# edit css and pss files --------------------------------------------------
#move files from input/ to sites/mandifore/
file.copy(
  from = file.path("/data/input", sites$cohort_filename),
  to = "/data/sites/mandifore",
  recursive = TRUE,
  copy.mode = FALSE
)

# read into R
pss_files <- list.files(
  file.path("/data/sites/mandifore", sites$cohort_filename),
  pattern = ".pss$",
  full.names = TRUE
)
pss <- map(pss_files, ~read_table(.x, col_types = cols(patch = col_character())))

css_files <- list.files(
  file.path("/data/sites/mandifore", sites$cohort_filename),
  pattern = ".css$",
  full.names = TRUE
)
css <- map(css_files, ~read_table(.x, col_types = cols(patch = col_character())))

# modify .css
css <- map(css, modify_css)

# modify .pss

pss <- map2(pss, css, modify_pss)


# Write .css and .pss files -----------------------------------------------
walk2(css, css_files, ~write.table(.x, .y, quote = FALSE, row.names = FALSE))
walk2(pss, pss_files, ~write.table(.x, .y, quote = FALSE, row.names = FALSE))


# Customize pecan.xml -----------------------------------------------------

settings <- map(wds, ~read.settings(file.path(.x, "pecan.xml")))

# add data from sites tibble
settings <- 
  pmap(
    list(settings = settings, wd = wds, s = sites |> rowwise() |> group_split()),
    \(settings, wd, s) {
      #set outdir--for testing it's in wd, not in data/ somewhere
      settings$outdir <- file.path(wd, "outdir")
      # site and met info
      settings$info$notes <- s$sitename
      settings$run$site$id <- s$site_id
      settings$run$site$met.start <-
        format(s$met_start_date, "%Y-%m-%d %H:%M:%S")
      settings$run$site$met.end <-
        format(s$met_end_date, "%Y-%m-%d %H:%M:%S")
      #TODO: check if run start and end are between met start and end
      
      # file paths
      base <- "/data/sites/mandifore"
      settings$run$inputs$met <-
        file.path(base,
                  s$met_filename,
                  "ED_MET_DRIVER_HEADER")
      files <-
        list.files(file.path(base, s$cohort_filename))
      
      settings$run$inputs$pss <-
        file.path(base, s$cohort_filename, files[str_detect(files, "\\.pss$")])
      settings$run$inputs$css <-
        file.path(base, s$cohort_filename, files[str_detect(files, "\\.css$")])
      settings
    }
  )


# Add PFTs to settings
pfts <- 
  map(css, ~unique(.x$pft)) |>
  map(match_pft) # a tibble

settings <- 
  map2(settings, pfts, ~{
    .x$pfts <- 
      .y |> 
      # converts pfts tibbles to a list
      select(name = PEcAn, ed2_pft_number = ED) |>
      rowwise() |>
      group_split() |>
      map(as.list) |> 
      set_names("pft")
    .x
  })


# Edit workflow.R ---------------------------------------------------------

workflows <- map(wds, ~readLines(file.path(.x, "workflow.R")))
settings_paths <- map(sites$sitename, ~{
  file.path("MANDIFORE_runs", .x, "pecan.xml")
})

map2(workflows, settings_paths, ~{
  repl <- paste0('inputfile <- \"', .y, '\"')
  str_replace(.x, 'inputfile <- .*', replacement = repl)
}) |> 
  walk2(wds, ~writeLines(.x, file.path(.y, "workflow.R")))


# Modify ED_MET_DRIVER_HEADER -------------------------------------------------
# Need to edit ED_MET_DRIVER_HEADER to point to correct path
# 
# E.g. change `/data/input/NARR_ED2_site_1-18168/` to `/data/sites/mandifore/NARR_ED2_site_1-18168/`
walk(sites$met_filename, ~{
  file.copy(
    from = file.path("/data/input", .x),
    to = "/data/sites/mandifore",
    recursive = TRUE,
    copy.mode = FALSE
  )
  met_driver_path <-
    file.path("/data/sites/mandifore",
              .x,
              "ED_MET_DRIVER_HEADER")
  met_driver <- readLines(met_driver_path) #read in
  met_driver <-
    str_replace(met_driver, "/data/input/", "/data/sites/mandifore/") #fix path
  write_lines(met_driver, met_driver_path)
})


# Copy files to HPC -------------------------------------------------------
walk2(settings, sites$met_filename, ~{
  PEcAn.remote::remote.copy.to(
    .x$host,
    src = file.path("/data/sites/mandifore", .y),
    dst = "/groups/dlebauer/data/sites/mandifore"
  )
})


walk2(settings, sites$cohort_filename, ~{
  PEcAn.remote::remote.copy.to(
    .x$host,
    src = file.path("/data/sites/mandifore", .y),
    dst = "/groups/dlebauer/data/sites/mandifore"
  )
})



