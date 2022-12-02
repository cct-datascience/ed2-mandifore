library(rstudioapi)
library(purrr)
library(here)

workflows <- list.files("MANDIFORE_runs/", pattern = "workflow.R", recursive = TRUE, full.names = TRUE)

# #launch them all as RStudio jobs
# walk(workflows, ~{
#   jobRunScript(.x, workingDir = here()) 
#   Sys.sleep(2) #stagger jobs
# })

# launch in separate R sessions with callr
library(furrr)
future::plan(future.callr::callr, workers = 5)
future_walk(workflows, ~{
  logpath <- file.path(dirname(.x), "workflow_log.txt")
  sink(file(logpath, "wt"), type = "message")
  withr::defer(sink(file = NULL, type = "message"))
  source(.x)
})
