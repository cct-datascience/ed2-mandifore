
# ed2-mandifore

<!-- badges: start -->
<!-- badges: end -->

The goal of ed2-mandifore is to run ED2 with Setaria in already grown ecosystems using history files and weather data from previous ED2 runs at MANDIFORE sites done by Mike Dietz.

The eventual goal is to automate setup of pecan.xml and workflow.R files so we can run as many sites as we need easily.

## Instructions:

1. Edit `templates/pecan_template.xml` to modify run start and end dates, number of ensembles, and metaanalysis.  Things like PFTs, site name, and paths to files will be edited programatically by an R script.
2. Source `02_setup-runs.R` to generate `pecan.xml` and `workflow.R` for runs in the `MANDIFORE_runs/` directory.
3. Run code in `03-run-them-all.R` to either launch runs as background jobs in RStudio or in separate R sessions with `callr`
