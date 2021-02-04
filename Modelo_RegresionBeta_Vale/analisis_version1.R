rm(list = ls())
library(readr)
library(tidyverse)
library(cmdstanr)
library(lubridate)
library(dplyr)
library(ggplot2)

#-------------------- Lectura y seleccion de Datos -------------------


stan_fname <- "Modelo1.stan"
setwd("C:/Users/Valeria/Documents/GitHub/CapacidadHospitalariaMX/Modelo_RegresionBeta_Vale")


#Lectura de la base de datos 
hospitalizaciones<- readRDS("C:/Users/Valeria/Documents/GitHub/CapacidadHospitalariaMX/Modelo_RegresionBeta_Vale/HospitalizacionesMX.rds")

#Cambio los nombres de las columnas para que no tengan acentos
colnames(hospitalizaciones)<-c("Unidad_medica", "Estado", "Institucion", "CLUES",
                               "Hospitalizados", "Ventilacion", "UCI_y_Ventilacion", "Fecha")
#Hago una copia de hospitalizaciones
muestra_Grande <- hospitalizaciones

#la conversi?n a factores se hace por orden alfabetico
muestra_Grande <- hospitalizaciones %>%
  mutate(Fecha = as.Date(Fecha)) %>%                          #convertimos fecha a tipo fecha
  mutate(Estado = as.numeric(factor(Estado))) %>%             #convertimos Estado en numeros del 1 al 32
  mutate(Institucion = as.numeric(factor(Institucion)))       #convertimos institucion en numeros del 1 al 12 


#Voy a agarrar solo un peque?o sample
set.seed(99)

#Hago una sample donde me filtre por 2 estados y solo 2 instituciones
sample <- muestra_Grande %>%
          filter(Estado == 5 | Estado == 6)

#Selecciono solo las columnas que necesito
sample_agrupada <- sample %>% 
            select(Unidad_medica, Fecha, Estado, Institucion, Hospitalizados) %>%
            arrange(Fecha)

#Vamos a pivotear para que me haga una tabla bonita
matriz_Total <- pivot_wider(data = sample_agrupada, names_from = Fecha, 
                      values_from = Hospitalizados, id_cols = c("Unidad_medica", "Institucion","Estado"))


matriz_Total <- matriz_Total %>%
                mutate(across(starts_with("2"), .fns = function(x){replace_na(x,0)}))  %>%
                mutate(across(starts_with("2"), .fns = function(x){x/100})) %>%
                mutate(across(starts_with("2"), .fns = function(x){if_else(x<=0,0.1,x)})) %>%
                mutate(across(starts_with("2"), .fns = function(x){if_else(x>=1,0.9,x)}))


#---------------- Correr el modelo -------------------------

#h <- nrow(matriz_Total)               #cantidad de hospitales
#l <- ncol(matriz_Total)               #n?mero de d?as
P <- (matriz_Total[ 1:3 , -c(1,2,3)])        #quitamos las columnas de unidad medica, estado e institucion
I <- pull(matriz_Total[1:3 ,], Institucion)               #vector de instituciones
S <- pull(matriz_Total[ 1:3 ,], Estado)               #vector de estados


sc_model <- cmdstanr::cmdstan_model(stan_fname, pedantic = F, 
                                    force_recompile = T)
                    #force_recompile = T solo cuando hay cambios en el stan

#Caracter?sticas del modelo 
chains = 1; iter_warmup = 100; nsim = 100; pchains = 1;   
data  <- list(h = nrow(P) , l = ncol(P) , P = P , 
              I = I , S = S, m = 3, inst = 12, est = 6)  ##OJO: recordar cambiar inst y est dependendiendo de los datos
#---------------------------
#Correr el modelo
fit      <- sc_model$sample(data = data, 
                            refresh=0, iter_warmup = iter_warmup,
                            iter_sampling = nsim,  parallel_chains = pchains,
                            chains = chains, adapt_delta = 0.8)
save(fit, file = "ModelBetafit.RData")
resumen <- fit$summary()

bayesplot::mcmc_hist(fit$draws("P[j,i]"))


#Vamos a graficar los hospitales
ggplot() + geom_line(aes(x=c(1:ncol(P)), y=as.numeric(P[1,1:ncol(P)])))
ggplot() + geom_line(aes(x=c(1:ncol(P)), y=as.numeric(P[2,1:ncol(P)])))
ggplot() + geom_line(aes(x=c(1:ncol(P)), y=as.numeric(P[3,1:ncol(P)])))
ggplot() + geom_line(aes(x=c(1:ncol(P)), y=as.numeric(P[4,1:ncol(P)])))
ggplot() + geom_line(aes(x=c(1:ncol(P)), y=as.numeric(P[5,1:ncol(P)])))





