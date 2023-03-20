load("/data/output/pecan_runs/MANDIFORE_big_run/MANDIFORE-SEUS-1123/mixed/sensitivity.results.NOENSEMBLEID.AGB_PFT.2002.2012.Rdata")
SA_mixed <- sensitivity.results$SetariaWT$variance.decomposition.output
load("/data/output/pecan_runs/MANDIFORE_big_run/MANDIFORE-SEUS-1123/pine/sensitivity.results.NOENSEMBLEID.AGB_PFT.2002.2012.Rdata")
SA_pine <- sensitivity.results$SetariaWT$variance.decomposition.output

library(tidyverse)

df_elast_mixed <- 
  SA_mixed$elasticities |> 
  enframe() 

df_elast_pine <- 
  SA_pine$elasticities |> 
  enframe() 

df_sens_mixed <- 
  SA_mixed$sensitivities |> 
  enframe()

df_sens_pine <- 
  SA_pine$sensitivities |> 
  enframe()

plot_df_elast <- 
  list("Mixed Forest" = df_elast_mixed, "Southern Pine Forest" = df_elast_pine) |> 
  bind_rows(.id = "ecosystem") |> 
  mutate(name = case_when(
    name == "mort2"                ~ "Mortality coefficient",
    name == "growth_resp_factor"   ~ "Growth respiration",
    name == "leaf_turnover_rate"   ~ "Leaf turnover rate",
    name == "leaf_width"           ~ "Leaf width",
    name == "nonlocal_dispersal"   ~ "Seed dispersal",
    name == "fineroot2leaf"        ~ "Fine root allocation",
    name == "root_turnover_rate"   ~ "Root turnover rate",
    name == "seedling_mortality"   ~ "Seedling mortality",
    name == "stomatal_slope"       ~ "Stomatal slope",
    name == "quantum_efficiency"   ~ "Quantum efficiency",
    name == "Vcmax"                ~ "Vcmax",
    name == "r_fract"              ~ "Reproductive allocation",
    name == "cuticular_cond"       ~ "Cuticular conductance",
    name == "root_respiration_rate"~ "Root respiration rate",
    name == "Vm_low_temp"          ~ "Photo. min temp",
    name == "SLA"                  ~ "Specific leaf area"
  ))

plot_df_sens <- 
  list("Mixed Forest" = df_sens_mixed, "Southern Pine Forest" = df_sens_pine) |> 
  bind_rows(.id = "ecosystem") |> 
  mutate(name = case_when(
    name == "mort2"                ~ "Mortality coefficient",
    name == "growth_resp_factor"   ~ "Growth respiration",
    name == "leaf_turnover_rate"   ~ "Leaf turnover rate",
    name == "leaf_width"           ~ "Leaf width",
    name == "nonlocal_dispersal"   ~ "Seed dispersal",
    name == "fineroot2leaf"        ~ "Fine root allocation",
    name == "root_turnover_rate"   ~ "Root turnover rate",
    name == "seedling_mortality"   ~ "Seedling mortality",
    name == "stomatal_slope"       ~ "Stomatal slope",
    name == "quantum_efficiency"   ~ "Quantum efficiency",
    name == "Vcmax"                ~ "Vcmax",
    name == "r_fract"              ~ "Reproductive allocation",
    name == "cuticular_cond"       ~ "Cuticular conductance",
    name == "root_respiration_rate"~ "Root respiration rate",
    name == "Vm_low_temp"          ~ "Photo. min temp",
    name == "SLA"                  ~ "Specific leaf area"
  ))

p_elast <- 
  ggplot(plot_df_elast, aes(y = name)) +
  geom_segment(aes(x = 0, xend = value, yend = name)) +
  geom_point(aes(x = value)) +
  geom_vline(xintercept = 0, linetype =2) +
  theme_bw() +
  facet_wrap(~ecosystem)+
  labs(x = "Elasticity", y = "Parameter") +
  theme(axis.title.y = element_blank())

ggsave("MSRs/2023-03-15/elasticity.png", p_elast)

p_sens <- 
  ggplot(plot_df_sens, aes(y = name)) +
  geom_segment(aes(x = 0, xend = value, yend = name)) +
  geom_point(aes(x = value)) +
  geom_vline(xintercept = 0, linetype =2) +
  theme_bw() +
  facet_wrap(~ecosystem)+
  labs(x = "Sensitivity", y = "Parameter") +
  theme(axis.title.y = element_blank())

ggsave("MSRs/2023-03-15/sensitivity.png", p_sens)
