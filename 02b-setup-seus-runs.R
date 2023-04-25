# load packages and functions -----------------------------------------------------------

library(tidyverse)
library(PEcAn.settings)
library(fs)

set.seed(4444)

# load site info ----------------------------------------------------------
# LHS sample of 20 sites
sites <- read_csv("data/seus_sample20.csv")

# 3 ecosystems corresponding to 3 .css files
ecosystems <- c("pine", "mixed", "prairie")

# create working directories ----------------------------------------------
run_df <- 
  expand_grid(sites, ecosystem = ecosystems) |> 
  mutate(wd = path("seus_sample", sitename, ecosystem))

#create all dirs
dir_create(run_df$wd)

#copy the same workflow template to all dirs
walk(run_df$wd, \(x) {
  file_copy(path("templates", "workflow_template_model_training.R"), path(x, "workflow.R"))
})

#copy job run script to all dirs
walk(run_df$wd, \(x) {
  file_copy(path("templates", "run.sh"), path(x, "run.sh"))
})

#copy pecan_xml per ecosystem
run_df <- 
  run_df |> 
  mutate(template = path("templates", paste0("pecan_template_", ecosystem, ".xml"))) |> 
  mutate(settings_path = file_copy(template, path(wd, "pecan.xml"))) |> 
  #create paths in /data/ for outdir
  mutate(outdir = path("/data/output/pecan_runs/seus_sample", sitename, ecosystem))

# Filepaths ---------------------------------------------------------------
# File paths for cohort and patch files.  The originals are in /data/input, and
# they'll be moved to /data/sites/mandifore/<sitename>
init <- 
  run_df |> 
  select(cohort_filename) |> 
  filter(!duplicated(cohort_filename)) |> 
  mutate(pss = dir_ls(path("/data/input", cohort_filename), glob = "*.pss"),
         css = dir_ls(path("/data/input", cohort_filename), glob = "*.css"))

# Now we need an altered filename for the files specifying the ecosystem
# because each will be a different css file. Even though we are using the *same*
# pss file for each ecosystem within a site, ED2 requries that the .pss and .css
# filenames are the same, so we'll create unique paths for both and need to copy
# over the .pss file three times under different names.
run_df <- left_join(run_df, init, by = join_by(cohort_filename)) |> 
  mutate(css_dest = path("/data/sites/mandifore/", sitename, paste(ecosystem, basename(css), sep = "_")),
         pss_dest = path("/data/sites/mandifore/", sitename, paste(ecosystem, basename(pss), sep = "_")))

# Customize pecan.xml -----------------------------------------------------

settings_list <- map(run_df$settings_path, read.settings)

# can't completely turn off ensemble analysis because of a bug:
# https://github.com/PecanProject/pecan/issues/3024
# Instead I'll set ensemble members to 1
settings_list<- 
  map(settings_list, \(x) {
    x$ensemble$size <- "1"
    x
  })

# Should only need 4 cores for these jobs:
# SA-median and the three pseudo-genotypes (the one ensemble gets deleted in
# worflow.R)

settings_list <-
  map(settings_list, \(x) {
    x$host$qsub <-
      str_replace(x$host$qsub, pattern = "--ntasks=\\d+", replacement = "--ntasks=4")
    x  
  })

# add data from sites tibble
for (i in seq_len(nrow(run_df))) {
  run <- run_df |> slice(i)
  settings_list[[i]]$outdir <- run_df$outdir[i]
  settings_list[[i]]$info$notes <- run_df$sitename[i]
  settings_list[[i]]$run$site$id <- run_df$site_id[i]
  settings_list[[i]]$run$site$met.start <- 
    format(run_df$met_start_date[i], "%Y-%m-%d %H:%M:%S")
  settings_list[[i]]$run$site$met.end <-
    format(run_df$met_end_date[i], "%Y-%m-%d %H:%M:%S")
  
  settings_list[[i]]$run$inputs$met <-
    fs::path("/data/sites/mandifore",
             run_df$met_filename[i],
             "ED_MET_DRIVER_HEADER")
  # edit .css and .pss paths
  settings_list[[i]]$run$inputs$pss <- run_df$pss_dest[i]
  settings_list[[i]]$run$inputs$css <- run_df$css_dest[i]
}


# write settings out
walk2(settings_list, run_df$wd, ~write.settings(.x, "pecan.xml", outputdir = .y))


# Edit workflow.R ---------------------------------------------------------

workflows <- map(run_df$wd, ~readLines(file.path(.x, "workflow.R")))
settings_paths <- file.path(run_df$wd, "pecan.xml")

map2(workflows, settings_paths, ~{
  repl <- paste0('inputfile <- \"', .y, '\"')
  str_replace(.x, 'inputfile <- .*', replacement = repl)
}) |> 
  walk2(run_df$wd, ~writeLines(.x, file.path(.y, "workflow.R")))


# Modify ED_MET_DRIVER_HEADER -------------------------------------------------
# Need to edit ED_MET_DRIVER_HEADER to point to correct path
# 
# E.g. change `/data/input/NARR_ED2_site_1-18168/` to `/data/sites/mandifore/NARR_ED2_site_1-18168/`
# Skip files that are already done
existing_met <- dir_ls("/data/sites/mandifore") |> basename()
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

# MET files
walk(sites$met_filename, #only need one met file per site, so can use the smaller df for this
     \(met_filename) {
       PEcAn.remote::remote.copy.to(
         host = list(name = "puma"),
         src = file.path("/data/sites/mandifore", met_filename),
         dst = "/groups/kristinariemer/data/sites/mandifore"
       )
     }, .progress = "Copy MET files to HPC")

# .css and .pss files

#create directories
walk(sites$sitename, \(x){
  PEcAn.remote::remote.execute.cmd(
    host = list(name = "puma"),
    cmd = "mkdir",
    args = path("/groups/kristinariemer/data/sites/mandifore/", x)
  )
})

run_df |> 
  rowwise() |> 
  transmute(x = PEcAn.remote::remote.copy.to(
    host = list(name = "puma"),
    src = "/data/sites/generic_patches/generic.pss",
    dst = path("/groups/kristinariemer", pss_dest)
  ))

run_df |> 
  mutate(css = path("/data/sites/generic_patches", paste0(ecosystem, ".css"))) |> 
  rowwise() |> 
  transmute(x = PEcAn.remote::remote.copy.to(
    host = list(name = "puma"),
    src = css,
    dst = path("/groups/kristinariemer", css_dest)
  ))
