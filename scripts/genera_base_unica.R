rm(list = ls())
setwd("~/Dropbox/HospitalizacionesCOVIDMX")

library(tidyverse)
library(readr)
library(lubridate)

#---------------------------------------------------
# UNIR TODOS LOS ARCHIVOS EN UNA BASE ÚNICA
#---------------------------------------------------

archivos <- list.files("raw", pattern = "Hospitalizaciones*")
fechas   <- str_replace_all(archivos,"Hospitalizaciones_","")
fechas   <- str_replace_all(fechas,".csv","") 

#Variables para el join
common_vars = c("CLUES","Estado","Institución","Unidad médica")
colspecs = cols(
  `Unidad médica`  = col_character(),
  Estado           = col_character(),
  Institución      = col_character(),
  CLUES            = col_character(),
  `% de Ocupación` = col_double()
)

for (fecha in fechas){
  
  message(paste0("Trabajando el ", fecha))
  
  hosp <- read_csv(paste0("raw/Hospitalizaciones_",fecha,".csv"),
                   locale = locale(encoding = "UTF-8"),
                   col_types = colspecs) 
  hosp <- hosp %>% rename(`Hospitalizados (%)` = `% de Ocupación`)
  
  vent <- read_csv(paste0("raw/Ventiladores_",fecha,".csv"),
                   locale = locale(encoding = "UTF-8"),
                   col_types = colspecs) 
  vent <- vent %>% rename(`Ventilación (%)` = `% de Ocupación`)
  
  uci  <- read_csv(paste0("raw/UCI_",fecha,".csv"),
                   locale = locale(encoding = "UTF-8"),
                   col_types = colspecs) 
  uci  <- uci %>% rename(`UCI y Ventilación (%)` = `% de Ocupación`)
  
  hosp <- hosp %>% full_join(vent, by = common_vars) %>% 
    full_join(uci, by = common_vars)
  
  hosp <- hosp %>% mutate(Fecha = fecha)
  
  if (fecha == fechas[1]){
    datos <- hosp 
  } else {
    datos <- datos %>% bind_rows(hosp)
  }
  
}

datos %>% distinct() %>%
  write_rds("processed/HospitalizacionesMX.rds")
