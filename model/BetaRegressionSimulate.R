setwd("~/Dropbox/HospitalizacionesCOVIDMX")
#https://arxiv.org/pdf/1404.3533.pdf
library(betareg)
library(rstan)
library(dplyr)
library(boot)
set.seed(888)
hospitales <- c(1,2,3,4,5)
entidad    <- c(1,2,1,2,1)
semanas    <- 10
pmat       <- rbeta(length(hospitales), 1, 2)
alfa       <- rnorm(1)
gamma      <- rnorm(semanas)
delta      <- rnorm(length(unique(hospitales)))
beta       <- rnorm(length(unique(entidad)))
mu         <- matrix(NA, nrow = length(hospitales), ncol = semanas)
phi        <- matrix(NA, nrow = length(hospitales), ncol = semanas)
a          <- matrix(NA, nrow = length(hospitales), ncol = semanas)
b          <- matrix(NA, nrow = length(hospitales), ncol = semanas)
mu[,1]     <- pmat
phi[,1]    <- 0
datos      <- matrix(NA, nrow = length(hospitales), ncol = semanas)
datos[,1]  <- pmat

for (i in 2:semanas){
  for (j in hospitales){
    mu[j,i]  <- inv.logit(datos[j, i-1]*(alfa + gamma[i] + delta[j] + gamma[i]*delta[j]))
    phi[j,i] <- exp(beta[entidad[j]]*gamma[i])
    a[j,i]   <- mu[j,i]*phi[j,i];
    b[j,i]   <- (1.0 - mu[j,i])*phi[j,i];
    datos[j,i] <- rbeta(1, a[j,i],b[j,i])
  }
}



# Stan data list
dat = list(Nsemanas = ncol(datos), 
           auto_order = 1,
           Nhospitales = nrow(datos),
           Nentidades = length(unique(entidad)),
           IndicadorEntidad = entidad, 
           p = datos)

beta_stan_test <- stan(file   = 'model/BetaRegressionModel_v2.stan',
                       data   = dat,
                       iter   = 2000,
                       pars = c("beta","gamma","delta","alpha"))

#pairs(beta_stan_test)
#summary(beta_stan_test)$summary
