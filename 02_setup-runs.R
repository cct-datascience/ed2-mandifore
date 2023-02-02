#TODO:
#this script still needs to:
# copy MET files
# Edit <site> tag and <met> tag
# load packages and functions -----------------------------------------------------------

library(tidyverse)
library(PEcAn.settings)
library(fs)

set.seed(4444)

# load site info ----------------------------------------------------------

new_sites <- read_csv("data/mandifore_sites.csv")

sites <- new_sites %>% 
  filter(lon > -83 & lon < -82) %>% 
  mutate(lat_round = round(lat)) %>% 
  group_by(lat_round) %>% 
  slice_sample(n=1)

# create working directories ----------------------------------------------
wds <- paste("MANDIFORE_big_run", sites$sitename, sep = "/")

wds |> 
  walk(~{
    dir_create(.x)
    file.copy(file.path("templates", "pecan_template.xml"),
              file.path(.x, "pecan.xml"))
    file.copy(file.path("templates", "workflow_template.R"),
              file.path(.x, "workflow.R"))
  }, .progress = "Copying templates")

# Customize pecan.xml -----------------------------------------------------

settings <- map(wds, ~read.settings(file.path(.x, "pecan.xml")))

# add data from sites tibble
settings <- 
  pmap(
    list(settings = settings, wd = wds, s = sites |> rowwise() |> group_split()),
    \(settings, wd, s) {
      #set outdir--for testing it's in wd, not in data/ somewhere
      # settings$outdir <- file.path(wd, "outdir")
      settings$outdir <- file.path("/data/output/pecan_runs", wd)
      # site and met info
      settings$info$notes <- s$sitename
      settings$run$site$id <- s$site_id
      settings$run$site$met.start <-
        format(s$met_start_date, "%Y-%m-%d %H:%M:%S")
      settings$run$site$met.end <-
        format(s$met_end_date, "%Y-%m-%d %H:%M:%S")
      #TODO: check if run start and end are between met start and end
      
      # file paths
      settings$run$inputs$met <-
        file.path("/data/sites/mandifore",
                  s$met_filename,
                  "ED_MET_DRIVER_HEADER")
      settings
    }
  )


# write settings out
walk2(settings, wds, ~write.settings(.x, "pecan.xml", outputdir = .y))


# Edit workflow.R ---------------------------------------------------------

workflows <- map(wds, ~readLines(file.path(.x, "workflow.R")))
settings_paths <- file.path(wds, "pecan.xml")

map2(workflows, settings_paths, ~{
  repl <- paste0('inputfile <- \"', .y, '\"')
  str_replace(.x, 'inputfile <- .*', replacement = repl)
}) |> 
  walk2(wds, ~writeLines(.x, file.path(.y, "workflow.R")))


# Modify ED_MET_DRIVER_HEADER -------------------------------------------------
# Need to edit ED_MET_DRIVER_HEADER to point to correct path
# 
# E.g. change `/data/input/NARR_ED2_site_1-18168/` to `/data/sites/mandifore/NARR_ED2_site_1-18168/`
# Skip files that are already done
existing_met <- dir_ls("/data/sites/mandifore")
walk(sites$met_filename[!sites$met_filename %in% existing_met], ~{
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
}, .progress = "Modify ED_MET_DRIVER_HEADER")


# Copy files to HPC -------------------------------------------------------

walk2(settings, sites$met_filename,
      \(settings, met_filename) {
        PEcAn.remote::remote.copy.to(
          settings$host,
          src = file.path("/data/sites/mandifore", met_filename),
          dst = "/groups/dlebauer/data/sites/mandifore"
        )
      }, .progress = "Copy MET files to HPC")



