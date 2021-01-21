//Built upon https://github.com/daltonhance/stan_beta_reg
data {
  int<lower=2> Nsemanas;    //Cantidad de semanas
  int<lower=2> Nhospitales; //Cantidad de hospitales
  int<lower=2> Nentidades;  //Cantidad de entidades
  int<lower=1> auto_order;  //Autoregresivo orden k
  int<lower=1> IndicadorEntidad[Nhospitales];  //Codificado del 1 al Nentidades, vector que indica efecto de la entidad
  matrix<lower=0,upper=1>[Nhospitales, Nsemanas] p; //Para cada hospital su proporción de casos semanales
}

parameters {
  real alpha;                    //Efecto global
  real<lower = 0> tau_alpha;     //Precisión de efecto global
  real<lower = 0> tau_delta;     //Precisión de efecto hospital
  real<lower = 0> tau_psi;       //Precisión de efecto arma
  real<lower = 0> tau_beta;      //Precisión de efecto entidad
  real<lower = 0> tau_gamma;     //Precisión de efecto semana
  vector[Nentidades - 1]  beta_raw;  //Efecto de la entidad
  vector[Nhospitales - 1] delta_raw; //Efecto del hospital
  vector[Nsemanas - 1]    psi_raw; //Efecto arma
  vector[Nsemanas - 1]    gamma_raw; //Efecto de la semana
}

transformed parameters{
  
  //Values of regressors
  matrix[Nsemanas, Nsemanas] regresores_x;
  real logit_cons;
  
  //Sum to zero constraint
  vector[Nentidades]  beta  = append_row(beta_raw, -sum(beta_raw));
  vector[Nhospitales] delta = append_row(delta_raw, -sum(delta_raw));
  vector[Nsemanas]    gamma = append_row(gamma_raw, -sum(gamma_raw));
  vector[Nsemanas]    psi   = append_row(psi_raw, -sum(psi_raw));
  
  //Transformed parameters for beta distribution
  matrix<lower=0,upper=1>[Nhospitales, Nsemanas] mu;  // Media transformada
  matrix<lower=0>[Nhospitales, Nsemanas] phi;         // Precisión transformada
  matrix<lower=0>[Nhospitales, Nsemanas] a;           // Parámetro de la beta(a,b)
  matrix<lower=0>[Nhospitales, Nsemanas] b;           // Parámetro de la beta

  //Definition of transformed parameters
  for (i in 1:Nhospitales){
    for (j in 1:Nsemanas){
      
      regresores_x[i,j] = alpha + gamma[j] + delta[i] + gamma[j]*delta[i];
      
      //Escribir todo en términos de media y precisión
      if (j <= auto_order){
        mu[i,j]  = p[i,j];
      } else {
        logit_cons = regresores_x[i,j];
        for (k in 1:auto_order){
           logit_cons = logit_cons + psi[j]*(logit(p[i,j-k]) -  regresores_x[i,j-k]);
        }
        mu[i,j] = inv_logit(logit_cons);
      }
      phi[i,j] = exp(beta[IndicadorEntidad[i]]*gamma[j]); //Efecto de precisión sólo importa el estado y la semana
      
      //Parámetros de la beta
      a[i,j]   = mu[i,j]*phi[i,j];
      b[i,j]   = (1.0 - 0.99*mu[i,j])*phi[i,j];
    }
  }
}

model {
  
  //Priors
  tau_alpha  ~ gamma(0.1, 0.1);
  tau_delta  ~ gamma(0.1, 0.1);
  tau_beta   ~ gamma(0.1, 0.1);
  tau_psi    ~ gamma(0.1, 0.1);
  tau_gamma  ~ gamma(0.1, 0.1);
  
  alpha      ~ normal(0, tau_alpha);
  gamma_raw  ~ normal(0, tau_gamma);
  beta_raw   ~ normal(0, tau_beta);
  delta_raw  ~ normal(0, tau_delta);
  psi_raw    ~ normal(0, tau_psi);
  
  // Likelihood
  for (i in 1:Nhospitales){
    for (j in 1:Nsemanas){
      p[i,j] ~ beta(a[i,j], b[i,j]);   
    }
  }
}

