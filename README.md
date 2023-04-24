
# ed2-mandifore

<!-- badges: start -->
<!-- badges: end -->

The goal of ed2-mandifore is to run ED2 with Setaria in already grown, complex ecosystems using weather data from MANDIFORE sites.

## Reproducibility

This project uses [`renv`](https://rstudio.github.io/renv/articles/renv.html) to manage package dependencies.  This is essential for reproducing this work as the version of `PEcAn.ED2` used is installed from a [pull request](https://github.com/PecanProject/pecan/pull/3125) that will likely never be merged.  Using a different version of `PEcAn.ED2` will result in errored runs.  Run `renv::restore()` to install dependencies.

### Setup scripts
Scripts 00 and 01 have already been run and have generated the data in `data/`.  They do not need to be run again.  

1. Start with sourcing `02_setup-runs.R` to generate files in the `transect/` directory.
2. In the terminal, navigate to a particular run (e.g. `./transect/MANDIFORE-SEUS-352/pine`) and start the job as a background process with `./run.sh`.
3. Follow the checklist below to check that the job is running correctly


### Job Start Checklist

Do all of this before starting the next job!

- [ ] Is the R output being saved to workflow.Rout?
- [ ] Are all the expected `run/` and `out/` folders created locally?
- [ ] Find settings_checked.xml and look through it.
- [ ] Are all the expected `run/` and `out/` folders created on the HPC?
- [ ] Once the job starts on the HPC, **record the SLURM job ID**.  It is not printed anywhere in the logs, so you will need to manually copy and paste it somewhere (e.g. into the pid.nohup file that has the local PID)
- [ ] Spot-check the log files for multiple runs to see that simulation has started

...now you can start another job.

### Job analytics

If you want to know how long a job took on the HPC you can use:

``` bash
sacct -j <jobid> -o Start,End,Elapsed
```

To check remaining compute hours:

``` bash
va
```
