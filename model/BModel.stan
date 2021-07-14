data {
  int<lower=1> nestados;                         //Cantidad de estados incluidos en el modelo
  int<lower=1> ndias;                            //Cantidad de días modelados
  int<lower=0> dias_predict;                     //Cantidad de días a predecir (futuro)
  int<lower=0> m;                                //Autoregresive order m
  real<lower=0> sigma_mu_hiper;                     //Sigma del hiperparámetro de la media
  real<lower=0> mu_mu_hiper;                        //Media del hiperparámetro de la media
  real<lower=0> sigma_sigma_hiper;
  real<lower=0> sigma_kappa_hiper;
  real<lower=0> sigma_estado_hiper;
  matrix[nestados, ndias] PHosp; //Proporción de hospitalizados para estado i día j
}

parameters {
  //Efectos autoregresivos
  real mu;
  real<lower=0> sigma;

  //Para la autoregresión con parámetros lambda
  vector[m] lambda;

  vector[nestados] alpha; //Agregamos un random effect
  real<lower=0> kappa[nestados];
  //real<lower=0> sigma_kappa;

  //Efectos de estado
  real mu_estado;    
  real<lower=0> sigma_estado;
  
  real mu_time;
  real<lower=0> sigma_time;
  
  vector[nestados] beta_1c;
  vector[nestados] beta_2c;
  
  
  vector[nestados] beta_1s;
  vector[nestados] beta_2s;
  
}

model {

  //Parámetros
  matrix[nestados, m] matrix_lambda;
  vector[nestados]    logit_p_estado;
  vector[ndias - m]   t_helper;
  vector[ndias - m]   cosine_365;
  vector[ndias - m]   cosine_180;
  vector[ndias - m]   sine_365;
  vector[ndias - m]   sine_180;
  
  //Auxiliary variables to speed-up by avoiding recalculation
  for (i in 1:(ndias - m)){
    t_helper[i] = i + m;
  }
  cosine_365 = cos(2*pi() / 365 * t_helper);
  cosine_180 = cos(2*pi() / 180 * (t_helper - 90));
  sine_365   = sin(2*pi() / 365 * t_helper);
  sine_180   = sin(2*pi() / 180 * (t_helper - 90));
  
  
  matrix_lambda = rep_matrix(lambda, nestados)'; //nestados x m matrix
  
  //Hiperparámetros
  mu           ~ normal(mu_mu_hiper, sigma_mu_hiper);
  sigma        ~ cauchy(0, sigma_mu_hiper);
  mu_estado    ~ normal(mu_mu_hiper, sigma_mu_hiper);
  sigma_estado ~ cauchy(0, sigma_mu_hiper);
  mu_time      ~ normal(mu_mu_hiper, sigma_mu_hiper);
  sigma_time   ~ cauchy(0, sigma_mu_hiper);
  //sigma_kappa  ~ normal(20, sigma_kappa_hiper);

  //Creamos los parámetros
  lambda ~ normal(mu, sigma);
  alpha  ~ normal(mu_estado, sigma_estado);
  kappa  ~ cauchy(200, sigma_kappa_hiper);
  
  //Time params
  beta_1s ~ normal(mu_time, sigma_time);
  beta_1c ~ normal(mu_time, sigma_time);
  
  beta_2s ~ normal(mu_time, sigma_time);
  beta_2c ~ normal(mu_time, sigma_time);


  //Loopeamos
  for (t in (m + 1):ndias){
    logit_p_estado = alpha  + cosine_365[t - m]*beta_1c + 
      sine_365[t - m]*beta_1s + cosine_180[t - m]*beta_2c + sine_180[t - m]*beta_2s + 
      rows_dot_product(matrix_lambda, PHosp[,(t-m):(t-1)]);  
    PHosp[,t] ~ beta_proportion(inv_logit(logit_p_estado), kappa);
  }
}

//Adapted from https://jwalton.info/Stan-posterior-predictives/
generated quantities {
  
  // Generate posterior predictives
  matrix[nestados, dias_predict + ndias] HospPred;
  
  //Helper functions
  matrix[nestados, m] matrix_lambda;
  vector[nestados]    logit_p_estado;
  vector[ndias + dias_predict - m]   t_helper;
  vector[ndias + dias_predict - m]   cosine_365;
  vector[ndias + dias_predict - m]   cosine_180;
  vector[ndias + dias_predict - m]   sine_365;
  vector[ndias + dias_predict - m]   sine_180;
  
  matrix_lambda = rep_matrix(lambda, nestados)'; //nestados x m matrix
  
  //Auxiliary variables to speed-up by avoiding recalculation
  for (i in 1:(ndias +  dias_predict - m)){
    t_helper[i] = i + m;
  }
  cosine_365 = cos(2*pi() / 365 * t_helper);
  cosine_180 = cos(2*pi() / 180 * (t_helper - 90));
  sine_365   = sin(2*pi() / 365 * t_helper);
  sine_180   = sin(2*pi() / 180 * (t_helper - 90));
  
  // First m points are to start model
  HospPred[1:nestados, 1:m] = PHosp[1:nestados, 1:m];

  // Posterior dist for observed
  for (t in (m + 1):ndias){
    logit_p_estado = alpha + cosine_365[t - m]*beta_1c + 
      sine_365[t - m]*beta_1s + cosine_180[t - m]*beta_2c + sine_180[t - m]*beta_2s + 
      rows_dot_product(matrix_lambda, PHosp[,(t-m):(t-1)]);  
    HospPred[, t] = to_vector( beta_proportion_rng(inv_logit(logit_p_estado), kappa) );
  }

  // Posterior dist for unobserved but still using some observed
  for (t in (ndias + 1):(ndias + m)){
    logit_p_estado = alpha + cosine_365[t - m]*beta_1c + 
      sine_365[t-m]*beta_1s + cosine_180[t - m]*beta_2c + sine_180[t-m]*beta_2s; 
    for (k in 1:m){
      if (t - k <= ndias){
        logit_p_estado += lambda[m - (k - 1)]*PHosp[,t - k]; //lambda_1 va con t - m y así...
      } else {
        logit_p_estado += lambda[m - (k - 1)]*HospPred[,t - k];
      }
    }
    HospPred[1:nestados, t] = to_vector( beta_proportion_rng(inv_logit(logit_p_estado), kappa) );
  }

  // Posterior dist for unobserved 
  for (t in (ndias + m + 1):(ndias +  dias_predict)){
    logit_p_estado = alpha  + cosine_365[t - m]*beta_1c + 
      sine_365[t - m]*beta_1s + cosine_180[t - m]*beta_2c + sine_180[t - m]*beta_2s + 
      rows_dot_product(matrix_lambda, HospPred[,(t-m):(t-1)]);  
    HospPred[, t] = to_vector( beta_proportion_rng(inv_logit(logit_p_estado), kappa) );
  }
}