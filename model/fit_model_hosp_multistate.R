rm(list = ls())
set.seed(2342)

library(readr)
library(tidyverse)
library(posterior) #remotes::install_github("stan-dev/posterior")
library(lubridate)
library(dplyr)
library(ggplot2)
library(rstan)
library(zoo)
library(cmdstanr)
library(viridis)
library(bayestestR)

#Dejar como NULL si quieres usar el compilador default
compiler_path_cxx <- "/usr/local/opt/llvm/bin/clang++"
options(mc.cores = parallel::detectCores())

#-------------------- Lectura y seleccion de Datos -------------------
#githubURL <- ("https://github.com/RodrigoZepeda/CapacidadHospitalariaMX/blob/master/processed/HospitalizacionesMX_estatal.rds?raw=true")
#download.file(githubURL,"Hospitaizaciones_estatalMX.rds")
message("Reading database")
hospitalizaciones <- readRDS("processed/HospitalizacionesMX_estatal.rds")
stan_fname        <- "model/BModel_ARMA_kappa.stan"
#install_cmdstan(cpp_options = list("CXX" = compiler_path_cxx), overwrite = T)
#Vamos a pivotear para que me haga una tabla bonita
message("Processing database")
observados <- hospitalizaciones %>% 
  select(-`Ventilación (%)`,-`UCI y Ventilación (%)`) %>%
  mutate(`Hospitalizados (%)` = `Hospitalizados (%)`/100) %>%
  mutate(Fecha = ymd(Fecha)) %>%
  arrange(Fecha) %>%
  filter(!is.na(Estado)) %>%
  group_by(Fecha, Estado) %>%
  mutate(`Hospitalizados (%)` = 
           rollapply(`Hospitalizados (%)`, width = 7, 
                     FUN = function(x) mean(x, na.rm=TRUE), partial=TRUE, 
                     fill = NA, align="left")) %>%
  filter(Fecha > ymd("2020/04/10")) %>% 
  mutate(`Hospitalizados (%)` = if_else(`Hospitalizados (%)` < 0.01, 0.01, `Hospitalizados (%)`)) %>%
  mutate(`Hospitalizados (%)` = if_else(`Hospitalizados (%)` > 0.99, 0.99, `Hospitalizados (%)`)) %>%
  ungroup() %>%
  identity() 

min_fecha <- min(observados$Fecha)
max_fecha <- max(observados$Fecha)

hospitalizaciones <- observados %>% #Para q sea + rápido
  mutate(`Hospitalizados (%)` = if_else(`Hospitalizados (%)` < 0.001, 0.001, `Hospitalizados (%)`)) %>%
  pivot_wider(names_from = Fecha, values_from = `Hospitalizados (%)`, 
              id_cols = c("Estado")) 

hospitalizaciones_match_estados <- hospitalizaciones %>% select(Estado) %>%
  mutate(EstadoNum = row_number())

#Proporción de hospitalizados
PHosp <- (hospitalizaciones %>% select(-Estado) %>% as.matrix()) 

#Caracter?sticas del modelo 
#p = 17; q = 1
chains = 4; iter_warmup = 1000; nsim = 2000; pchains = 4; 
datos  <- list(p = 30, q = 1, r = 2,
               dias_predict = 150,
               ndias = ncol(PHosp) , nestados = nrow(PHosp), PHosp = PHosp,
               sigma_mu_hiper = 0.1, sigma_kappa_hiper = 50, mu_phi_prior = 0,
               mu_mu_temp = 0, sigma_sigma_temp = 10, mu_kappa = 200,
               mu_mu_hiper = 0, sigma_sigma_hiper = 10, mu_kappa_prior = 200,
               sigma_phi_prior = 1) 

# function form 2 with an argument named `chain_id`
# function form 2 with an argument named `chain_id`
initf2 <- function(chain_id = 1) {
  list(kappa        = rnorm(nrow(PHosp), 200, 10), 
       alpha        = rnorm(nrow(PHosp), -2.2, 0.1),
       lambda       = rnorm(datos$p, 0.1, 1),
       phi          = rnorm(datos$q, 0, 0.001),
       mu_estado    = rnorm(1,-0.15,0.1),
       sigma_estado = rnorm(1,2.2,1) %>% abs(),
       mu           = rnorm(1,0,1) %>% abs(),
       sigma        = rnorm(1,1,1) %>% abs(),
       mu_time      = rnorm(1,0.02,0.01),
       kappa_alpha  = rnorm(nrow(PHosp), 0, 0.1),
       kappa_beta   = rnorm(nrow(PHosp), 0, 0.1),
       sigma_time   = abs(rnorm(1,0.10,0.01))
  )}



# generate a list of lists to specify initial values
init_ll <- lapply(1:chains, function(id) initf2(chain_id = id))

#Vamos a intentar con rstan
message("Fitting model. Go grab a coffee this will take A LOT")
if (!is.null(compiler_path_cxx)){
  cpp_options <- list(cxx_flags = "-O3 -march=native", 
                      cxx = compiler_path_cxx, stan_threads = TRUE)
} else {
  cpp_options <- list(cxx_flags = "-O3 -march=native", stan_threads = TRUE)
}

hosp_model <- cmdstan_model(stan_fname, cpp_options = cpp_options)

if (!dir.exists("cmdstan")){dir.create("cmdstan")}
model_sample <- hosp_model$sample(data = datos, chains = chains, 
                                  seed = 47, 
                                  iter_warmup = iter_warmup,
                                  adapt_delta = 0.95, 
                                  iter_sampling = nsim - iter_warmup,
                                  init = init_ll,
                                  max_treedepth = 2^(11),
                                  output_dir = "cmdstan",                                  
                                  threads_per_chain = 4)

message("Saving results")
model_sample$save_object(file = "model_fit1.rds")
#model_sample$cmdstan_diagnose()

#---------------------------
#Correr el modelo

#Guardamos las simulaciones por si las dudas
#modelo_ajustado <- readRDS("model_fit1.rds")
modelo_ajustado <- summarise_draws(model_sample$draws(), 
                                   ~ quantile(., probs = c(0.005, 0.025, 0.05, 
                                                           0.125, 0.25, 0.325,0.4, 0.5,
                                                           0.6, 0.675,0.75, 0.875, 0.95, 
                                                           0.975, 0.995)))
Hosp            <- modelo_ajustado %>% filter(str_detect(variable, "Hosp"))

# 
# #Calculamos el intervalo de confianza mínima densidad
# for (confint in c(0.5, 0.75, 0.9, 0.95, 0.99)){
#   message(paste0("Calculando el intervalo de ",  100*confint,"%"))
#   cime  <- hdi(sc_model, ci = confint)
#   cime  <- cime %>% rename(!!sym(paste0("Lower",100*confint)) := CI_low) %>%
#     rename(!!sym(paste0("Upper", 100*confint)) := CI_high) %>%
#     rename(variable = Parameter)
#   Hosp  <- Hosp %>% left_join(cime, by = "variable")
# }

Hosp <- Hosp %>%
  mutate(EstadoNum = str_extract(variable, "\\[.*,")) %>%
  mutate(DiaNum    = str_extract(variable, ",.*\\]")) %>%
  mutate(EstadoNum = str_remove_all(EstadoNum,"\\[|,")) %>%
  mutate(DiaNum    = str_remove_all(DiaNum,"\\]|,")) %>%
  mutate(EstadoNum = as.numeric(EstadoNum)) %>%
  mutate(DiaNum    = as.numeric(DiaNum)) %>%
  select(-variable) %>%
  left_join(hospitalizaciones_match_estados, by = "EstadoNum") %>%
  mutate(Fecha = !!ymd(min_fecha) + DiaNum) %>% 
  full_join(observados, by = c("Fecha","Estado")) %>%
  arrange(Estado, Fecha)

Hosp %>% drop_na(`50%`) %>% write_csv(paste0("predictions/Predichos.csv"))

all_states <- ggplot(Hosp, aes(x = Fecha)) +
  geom_ribbon(aes(ymin = `0.5%`, ymax = `99.5%`, fill = "99%"), alpha = 1) +
  geom_ribbon(aes(ymin = `5%`, ymax = `95%`, fill = "90%"), alpha = 1) +
  geom_line(aes(y = `50%`, color = "Predichos"), size = 0.5) +
  geom_vline(aes(xintercept = today() + 30), linetype = "dashed", color = "white") +
  geom_point(aes(y = `Hospitalizados (%)`, color = "Observados"), 
             size = 1, data = Hosp %>% filter(Fecha <= !!max_fecha)) +
  geom_point(aes(y = `Hospitalizados (%)`), 
             size = 0.001, color = "gray75",
             data = Hosp %>% filter(Fecha <= !!max_fecha)) +
  facet_wrap(~Estado, ncol = 8) +
  scale_y_continuous(labels = scales::percent) +
  scale_x_date(breaks = "4 months") +
  theme_classic() +
  scale_color_manual("Modelo", 
                     values = c("Observados" = "#222D39", 
                                "Predichos" = "#D1713B")) +
  scale_fill_manual("Probabilidad\ndel escenario", 
                    values = c("90%" = "#2F3E4E",
                               "99%" = "#222D39")) +
  labs(
    x = "\nFecha",
    y = "Capacidad Hospitalaria (%)\n",
    title = "Escenarios a largo plazo capacidad hospitalaria a partir de la RED-IRAG",
    caption = "*Predicciones después de 30 días (línea vertical) son sólo escenarios",
    subtitle = "Modelo Beta-Bayesiano | Github: @CapacidadHospitalariaMX | Datos de https://www.gits.igg.unam.mx/red-irag-dashboard"
  ) +
  coord_cartesian(ylim = c(0,1)) +
  theme(strip.text = element_text(size = 15, color = "white"), 
        text = element_text(color = "white"),
        axis.text.x  = element_text(angle = 90, hjust = 1, vjust = 0.5),
        strip.background = element_rect(fill = "#222D39"),
        axis.text = element_text(size = 16, color = "gray85"),
        axis.title=element_text(size=20,face="bold", color = "gray85"),
        plot.title = element_text(size = 20, color = "white"), 
        plot.subtitle = element_text(size = 14, color = "gray85"),
        plot.caption = element_text(size = 14),
        legend.background = element_rect(fill = NA),
        legend.text = element_text(color = "white"),
        legend.title = element_text(color = "white"),
        panel.background = element_rect(fill = "#515D6B"),
        plot.background = element_rect(fill = "#515D6B"),
        axis.ticks = element_line(color = "gray85", size = 2),
        axis.line = element_line(color = "gray85", size = 2)) 

all_states +
  ggsave(paste0("predictions/Hosp_predict_v2.pdf"), width = 30, height = 10)

all_states +
  ggsave(paste0("predictions/AllStates.png"), width = 30, height = 10)

for (estado in unique(Hosp$Estado)){
  Hosp %>% filter(Estado == !!estado) %>%
    ggplot(aes(x = Fecha)) +
    geom_ribbon(aes(ymin = `0.5%`, ymax = `99.5%`, fill = "99%"), alpha = 1) +
    geom_ribbon(aes(ymin = `5%`, ymax = `95%`, fill = "90%"), alpha = 1) +
    geom_line(aes(y = `50%`, color = "Predichos"), size = 1) +
    geom_vline(aes(xintercept = today() + 30), linetype = "dashed", color = "white") +
    annotate("label",x = today() + 95, y = 0.95,
             color = "white", size = 3,
             label = "*Predicciones después de 30 días\nson sólo escenarios",
             fill = "orange", alpha = 0.2, label.size=NA) +
    geom_point(aes(y = `Hospitalizados (%)`, color = "Observados"),
               size = 4,data = Hosp %>% filter(Fecha <= !!max_fecha & Estado == !!estado)) +
    geom_point(aes(y = `Hospitalizados (%)`), color = "white",
               size = 1,data = Hosp %>% filter(Fecha <= !!max_fecha & Estado == !!estado)) +
    facet_wrap(~Estado, ncol = 8) +
    scale_y_continuous(labels = scales::percent) +
    scale_x_date(breaks = "2 months") +
    theme_classic() +
    scale_color_manual("Modelo", 
                       values = c("Observados" = "#222D39", 
                                  "Predichos" = "#D1713B")) +
    scale_fill_manual("Probabilidad\ndel escenario", 
                      values = c("90%" = "#2F3E4E",
                                 "99%" = "#222D39")) +
    labs(
      x = "\nFecha",
      y = "Capacidad Hospitalaria (%)\n",
      title = "Escenarios a largo plazo capacidad hospitalaria a partir de la RED-IRAG",
      subtitle = "Modelo Beta-Bayesiano | Github: @CapacidadHospitalariaMX | Datos de https://www.gits.igg.unam.mx/red-irag-dashboard"
    ) +
    coord_cartesian(ylim = c(0,1)) +
    theme(strip.text = element_text(size=30, color = "white"), 
          text = element_text(color = "white"),
          axis.text.x  = element_text(angle = 90, hjust = 1, vjust = 0.5),
          strip.background = element_rect(fill = "#222D39"),
          axis.text = element_text(size = 16, color = "gray85"),
          axis.title=element_text(size=20,face="bold", color = "gray85"),
          plot.title = element_text(size = 20, color = "white"), 
          plot.subtitle = element_text(size = 14, color = "gray85"),
          plot.caption = element_text(size = 14),
          legend.background = element_rect(fill = NA),
          legend.text = element_text(color = "white"),
          legend.title = element_text(color = "white"),
          panel.background = element_rect(fill = "#515D6B"),
          plot.background = element_rect(fill = "#515D6B"),
          axis.ticks = element_line(color = "gray85", size = 2),
          axis.line = element_line(color = "gray85", size = 2)) +
    ggsave(paste0("predictions/Hosp_predict_v2",estado,".pdf"), width = 14, height = 8)
}

if (file.exists("predictions/PREDICCIONES_HOSP.pdf")){file.remove("predictions/PREDICCIONES_HOSP.pdf")}