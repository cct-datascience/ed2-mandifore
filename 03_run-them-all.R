library(purrr)
library(here)
library(furrr)
future::plan(future.callr::callr, workers = 5)

# get paths to all the workflow.R files
workflows <- list.files("MANDIFORE_runs/", pattern = "workflow.R", recursive = TRUE, full.names = TRUE)

# launch them all as RStudio background jobs
library(rstudioapi)
walk(workflows, ~{
  jobRunScript(.x, workingDir = here())
  Sys.sleep(2) #stagger jobs
})

# # launch them all in separate R sessions and sink messages to a log
# future_walk(workflows, function(.x) {
#   #create a log file to capture logger messages
#   logpath <- file.path(dirname(.x), "workflow_log.txt")
#   sink(file(logpath, "wt"), type = "message")
#   withr::defer(sink(file = NULL, type = "message"))
#   #source workflow.R
#   source(.x)
# })
