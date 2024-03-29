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
options(mc.cores = parallel::detectCores())

#-------------------- Lectura y seleccion de Datos -------------------
#githubURL <- ("https://github.com/RodrigoZepeda/CapacidadHospitalariaMX/blob/master/processed/HospitalizacionesMX_estatal.rds?raw=true")
#download.file(githubURL,"Hospitaizaciones_estatalMX.rds")
message("Reading database")
hospitalizaciones <- readRDS("processed/HospitalizacionesMX_estatal.rds")
colnames(hospitalizaciones) <- c("Estado", "Hospitalizados (%)", 
                                 "Ventilación (%)", "UCI y Ventilación (%)", "Fecha")
stan_fname        <- "model/BModel_ARMA_semaforo.stan"

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
  ungroup() %>%
  identity() 

min_fecha <- min(observados$Fecha)
max_fecha <- max(observados$Fecha)
span_dates <- observados$Fecha %>% unique()

hospitalizaciones_match_estados <- hospitalizaciones %>% 
  select(Estado) %>%
  unique() %>%
  mutate(EstadoNum = row_number())

# Leemos la database del semaforo
message("Processing database semaforo")
semaforo <- read_csv("https://github.com/claudiodanielpc/covid19/raw/master/semaforo_covidmx.csv",
                     locale = locale(encoding = "WINDOWS-1252")) %>%
  mutate(fecha_publica = dmy(fecha_publica), 
         fecha_inicio  = dmy(fecha_inicio), 
         fecha_fin     = dmy(fecha_fin)) %>%
  mutate(nom_ent = if_else(nom_ent == "Veracruz de Ignacio de la Llave", "Veracruz de Ignacio de La Llave", nom_ent)) 


# Lo tranformo para que tenga por día
semaforo_trans <- data.frame()

for (i in 1:nrow(semaforo)){
  aux <- semaforo[i, ]
  vector <- as.matrix(aux)
  sequencia <- seq(from = aux$fecha_inicio, to = aux$fecha_fin, by = 1)
  diferencia <- as.integer(aux$fecha_fin - aux$fecha_inicio)[1] + 1
  aux <- do.call("rbind", replicate(diferencia, aux, simplify = FALSE))
  aux <- aux %>%
    mutate(Fecha = sequencia)
  
  semaforo_trans <- bind_rows(semaforo_trans, aux)
}

# Selecciono lo que necesito
semaforo_filt <- semaforo_trans %>%
  select(nom_ent, Fecha, color_sem) %>%
  filter(Fecha %in% span_dates)   #para quitar los que no tenemos datos de hospitalizaciones
 
semaforo_match_hosp <- semaforo_filt %>%
  select(nom_ent) %>%
  unique() %>%
  left_join(hospitalizaciones_match_estados, by = c("nom_ent" = "Estado")) 

# Le agregamos el estado num para que esté en orden similar al de hospitalizaciones
semaforo_filt <- semaforo_filt %>%
  left_join(semaforo_match_hosp, by = "nom_ent") %>%
  ungroup() %>%
  arrange(EstadoNum)

semaforo_completo <- semaforo_filt %>%
  full_join(observados, by = c("Fecha" = "Fecha", "nom_ent" = "Estado")) %>%
  select(-EstadoNum, -`Hospitalizados (%)`) %>%
  mutate(color_sem = replace_na(color_sem, 0)) %>%
  arrange(Fecha)

rojo <- semaforo_completo %>%
  mutate(Indicadora = if_else(color_sem == "Rojo", 1, 0)) %>%
  pivot_wider(names_from = Fecha, values_from = Indicadora, id_cols = c("nom_ent")) %>% 
  select(-nom_ent) %>% 
  as.matrix() 

naranja <- semaforo_completo %>%
  mutate(Indicadora = if_else(color_sem == "Naranja", 1, 0)) %>%
  pivot_wider(names_from = Fecha, values_from = Indicadora, id_cols = c("nom_ent")) %>% 
  select(-nom_ent) %>% 
  as.matrix() 

amarillo <- semaforo_completo %>%
  mutate(Indicadora = if_else(color_sem == "Amarillo", 1, 0)) %>%
  pivot_wider(names_from = Fecha, values_from = Indicadora, id_cols = c("nom_ent")) %>% 
  select(-nom_ent) %>% 
  as.matrix() 

verde <- semaforo_completo %>%
  mutate(Indicadora = if_else(color_sem == "Verde", 1, 0)) %>%
  pivot_wider(names_from = Fecha, values_from = Indicadora, id_cols = c("nom_ent")) %>% 
  select(-nom_ent) %>% 
  as.matrix() 

hospitalizaciones <- observados %>% #Para q sea + rápido
  mutate(`Hospitalizados (%)` = if_else(`Hospitalizados (%)` < 0.001, 0.001, `Hospitalizados (%)`)) %>%
  pivot_wider(names_from = Fecha, values_from = `Hospitalizados (%)`, 
              id_cols = c("Estado")) 

#Proporción de hospitalizados
PHosp <- (hospitalizaciones %>% select(-Estado) %>% as.matrix()) 

#Caracter?sticas del modelo 
chains = 3; iter_warmup = 250; nsim = 500; pchains = 3; hmin = 3; hmax = 4;
datos  <- list(p = 4, q = 4, r = 2,
               dias_predict = 0, 
               ndias = ncol(PHosp) , nestados = nrow(PHosp), PHosp = PHosp,
               hmin = hmin, hmax = hmax,
               rojo = rojo, naranja = naranja, 
               amarillo = amarillo, verde = verde,
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
       beta_1s      = rnorm(nrow(PHosp)),
       beta_1c      = rnorm(nrow(PHosp)),
       beta_2s      = rnorm(nrow(PHosp)),
       beta_2c      = rnorm(nrow(PHosp)),
       brojo        = rnorm(hmax - hmin + 1, 0, 1) %>% abs(), 
       bnaranja     = rnorm(hmax - hmin + 1, 0, 1) %>% abs(), 
       bamarillo    = rnorm(hmax - hmin + 1, 0, 1) %>% abs(),
       bverde       = rnorm(hmax - hmin + 1, 0, 1) %>% abs(),
       mu_time      = rnorm(1,0.02,0.01),
       sigma_time   = abs(rnorm(1,0.10,0.01))
  )}



# generate a list of lists to specify initial values
init_ll <- lapply(1:chains, function(id) initf2(chain_id = id))

#Vamos a intentar con rstan
message("Fitting model. Go grab a coffee this will take A LOT")
hosp_model <- cmdstan_model(stan_fname, cpp_options = list(
  cxx_flags = "-O3 -march=native", cxx = "/usr/local/opt/llvm/bin/clang++",
  stan_threads = TRUE
))

model_sample <- hosp_model$sample(data = datos, chains = chains, 
                                  seed = 47, 
                                  iter_warmup = iter_warmup,
                                  adapt_delta = 0.95, 
                                  iter_sampling = nsim - iter_warmup,
                                  init = init_ll,
                                  max_treedepth = 2^(11),
                                  output_dir = "predictions",
                                  threads_per_chain = 2)

message("Saving results")
model_sample$save_object(file = "model_fit1.rds")
#model_sample$cmdstan_diagnose()

#---------------------------
#Correr el modelo

#Guardamos las simulaciones por si las dudas
#model_sample <- readRDS("model_fit1.rds")
modelo_ajustado <- summarise_draws(model_sample$draws(), 
                                   ~ quantile(., probs = c(0.005, 0.025, 0.05, 
                                                           0.125, 0.25, 0.325,0.4, 0.5,
                                                           0.6, 0.675,0.75, 0.875, 0.95, 
                                                           0.975, 0.995)))
Hosp            <- modelo_ajustado %>% filter(str_detect(variable, "Hosp"))

colores <- modelo_ajustado %>% 
  filter(str_detect(variable, "brojo|bnaranja|bamarillo|bverde"))

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
        axis.text.x  = element_text(angle = 90, hjust = 1),
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
        axis.ticks = element_line(color = "gray85", size = 1),
        axis.line = element_line(color = "gray85", size = 2)) 

all_states +
  ggsave(paste0("predictions/Hosp_predict_semaforo.pdf"), width = 30, height = 10)


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
          axis.text.x  = element_text(angle = 90, hjust = 1),
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
          axis.ticks = element_line(color = "gray85", size = 1),
          axis.line = element_line(color = "gray85", size = 2)) +
    ggsave(paste0("predictions/Hosp_predict_semaforo",estado,".pdf"), width = 14, height = 8)
}

