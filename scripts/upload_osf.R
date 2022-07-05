#! /usr/bin/Rscript
rm(list = ls())
library(osfr)
library(magrittr)
library(glue)
library(stringr)
library(dplyr)

#Get files
estatal    <- list.files("raw/estatal",       pattern = ".*.csv", full.names = T)
unidad     <- list.files("raw/unidad_medica", pattern = ".*.csv", full.names = T)
procesada  <- list.files("processed", pattern = ".*.csv", full.names = T)

#Get project
covid_project <- osf_retrieve_node("https://osf.io/9nu2d/")

#List files
osfiles <- 
  covid_project %>%
    osf_ls_files("Capacidad Hospitalaria/estatal", n_max = Inf) %>% 
  bind_rows(
    covid_project %>%
      osf_ls_files("Capacidad Hospitalaria/unidad_medica", n_max = Inf)
  ) %>% 
  bind_rows(
  covid_project %>%
    osf_ls_files("Capacidad Hospitalaria/procesadas", n_max = Inf)
  )

#Get address
estatal_address <- covid_project %>%
  osf_ls_files("Capacidad Hospitalaria", pattern = "estatal") 

procesada_address <- covid_project %>%
  osf_ls_files("Capacidad Hospitalaria", pattern = "procesadas") 

unidad_address <- covid_project %>%
  osf_ls_files("Capacidad Hospitalaria", pattern = "unidad_medica") 

for (fname in c(estatal, unidad, procesada)){
  if (!(basename(fname) %in% osfiles$name)){
    stop(fname)
    message(glue("Uploading {fname}"))
    
    if (fname %in% estatal){
      #Upload file to estatal
      covid_project %>%
        osf_upload(path = fname, conflicts = "skip") %>% 
        osf_mv(estatal_address,  overwrite  = TRUE)
    } else if (fname %in% unidad) {
      #Upload file to unidad
      covid_project %>%
        osf_upload(path = fname, conflicts = "skip") %>% 
        osf_mv(unidad_address,  overwrite  = TRUE)
    } else {
      #Upload file to processed
      covid_project %>%
        osf_upload(path = fname, conflicts = "overwrite") %>% 
        osf_mv(procesada_address,  overwrite  = TRUE)
    }
    
    message(glue("Success!"))
    
  } else if (str_detect(fname,"processed")){
    
    message(glue("Uploading {fname}"))
    
    covid_project %>%
      osf_upload(path = fname, conflicts = "overwrite") %>% 
      osf_mv(procesada_address, overwrite = T)
     
  }
}
