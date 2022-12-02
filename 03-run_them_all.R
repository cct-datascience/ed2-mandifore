library(rstudioapi)
library(purrr)
library(here)

workflows <- list.files("MANDIFORE_runs/", pattern = "workflow.R", recursive = TRUE, full.names = TRUE)

#launch them all as RStudio jobs
walk(workflows, ~{
  jobRunScript(.x, workingDir = here()) 
  Sys.sleep(2) #stagger jobs
})
