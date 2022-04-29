rm(list = ls())

library(tidyverse)
library(lubridate)


for (tipo in c("estatal","unidad_medica")){
  #---------------------------------------------------
  # UNIR TODOS LOS ARCHIVOS EN UNA BASE ÚNICA
  #---------------------------------------------------
  
  archivos <- list.files(paste0("raw/", tipo), pattern = "Hospitalizaciones*")
  fechas   <- str_replace_all(archivos,"Hospitalizaciones_","")
  fechas   <- str_replace_all(fechas,".csv","") 
  
  #Variables para el join
  if (tipo == "unidad_medica"){
    common_vars = c("CLUES","Estado","Institución","Unidad médica")
    colspecs = cols(
      `Unidad médica`  = col_character(),
      Estado           = col_character(),
      Institución      = col_character(),
      CLUES            = col_character(),
      `% de Ocupación` = col_double()
    )
  } else{
    common_vars = c("Estado")
    colspecs = cols(
      Estado           = col_character(),
      `% Ocupación` = col_double()
    )
  }
  
  for (fecha in fechas){
    
    message(paste0("Trabajando el ", fecha))
    
    hosp <- read_csv(paste0("raw/",tipo,"/Hospitalizaciones_",fecha,".csv"),
                     locale = locale(encoding = "UTF-8"),
                     col_types = colspecs) 
    hosp <- hosp %>% rename(`Hospitalizados (%)` := starts_with("%"))
    
    vent <- read_csv(paste0("raw/",tipo,"/Ventiladores_",fecha,".csv"),
                     locale = locale(encoding = "UTF-8"),
                     col_types = colspecs) 
    vent <- vent %>% rename(`Ventilación (%)` := starts_with("%"))
    
    uci  <- read_csv(paste0("raw/",tipo,"/UCI_",fecha,".csv"),
                     locale = locale(encoding = "UTF-8"),
                     col_types = colspecs) 
    uci  <- uci %>% rename(`UCI y Ventilación (%)` := starts_with("%"))
    
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
    write_rds(paste0("processed/HospitalizacionesMX_",tipo,".rds"))
  
  datos %>% distinct() %>%
    write_csv(paste0("processed/HospitalizacionesMX_",tipo,".csv"))
}

#Script para subirlo a OSF
source("scripts/upload_osf.R")