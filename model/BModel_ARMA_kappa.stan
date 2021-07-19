//------------------------------------------------------------------------------
// MODELO BETA BAYESIANO DE CAPACIDAD HOSPITALARIA
//------------------------------------------------------------------------------
//
// Github: @RodrigoZepeda/CapacidadHospitalariaMX
// Web:    https://rodrigozepeda.github.io/CapacidadHospitalariaMX/index
//
// Descripción:
// ---------------------------
// Modelo bayesiano para la predicción del % de ocupación hospitalaria
// en la red IRAG a partir de los datos de la página:
// https://www.gits.igg.unam.mx/red-irag-dashboard/reviewHome#
//
// Modelo:
// ---------------------------
// Para cada estado j =1,2,..., nestados se modela el porcentaje de ocupación 
// hospitalaria del estado al tiempo t, PHosp_{j,t} como:
//
// logit(PHosp_{j,t}) = \alpha + 
//     \sum_{i=1}^r [b_{i,j} * cos(2*pi*t*i/365) + a_{i,j} * sin(2*pi*t*i/365)] + 
//     \sum_{k=1}^p \lambda_k * logit(PHosp_{j,t-k}) +  
//     \sum_{k=1}^q \phi_k * error_{j,t-k} 
//
// donde PHosp_{j,t} ~ Beta(logit(PHosp_{j,t}), kappa) y  
// error_{j,t-k} ~ Normal(0, sigma_error). 
// Esto corresponde a una estructura ARIMA(p,q) sobre logit(PHosp_{j,t}).
// De manera simplificada el modelo es de la forma:
//
// % Ocupación = Efecto estatal + Efecto estacional + % Ocupaciones Previas + Errores del modelo
//
// Para el modelo se suponen las siguientes distribuciones jerárquicas:
//
//                      Hiperparámetros
//                -------------------------
// \mu           ~ Normal(mu_mu_hiper, sigma_mu_hiper);
// \sigma        ~ Cauchy(0, sigma_mu_hiper);
// mu_estado     ~ Normal(mu_mu_hiper, sigma_mu_hiper);
// sigma_estado  ~ Cauchy(0, sigma_mu_hiper);
// mu_time       ~ Normal(mu_mu_hiper, sigma_mu_hiper);
// sigma_time    ~ Cauchy(0, sigma_mu_hiper);
// sigma_error   ~ Normal(0, 100);
//
//                         Parámetros
//                -------------------------
// \alpha        ~ Normal(mu_estado, sigma_estado)
// b_i, a_i      ~ Normal(mu_time, sigma_time)  
// \lambda       ~ Normal(mu, sigma)
// \phi          ~ Normal(0, sigma_phi_prior)
// error_{j,t}   ~ Normal(0, sigma_error)
// \kappa        ~ Cauchy(mu_kappa_prior, sigma_jappa)
//
// donde se utilizan como input las siguientes cantidades:
//
// Inputs:
// ---------------------------
// PHosp             .- Matriz de nestados x ndias donde la entrada PHosp[i,j] corresponde
//                      al % de ocupación hospitalaria del estado i en el día j.
// nestados          .- Cantidad de estados (entidades) en el modelo de hospitalizaciones.
// ndias             .- Cantidad de días donde se midió la ocupación hospitalaria.
// dias_predict      .- Número de días (después de ndias) para los cuales realizar la predicción.
// p                 .- Cantidad de términos previos a utilizar en ARIMA(p,q)
// q                 .- Cantidad de términos error previos a utilizar en ARIMA(p,q)
// r                 .- Cantidad de ciclos a tomar en cuenta en la estacionalidad (cosenos y senos)
// mu_kappa_prior    .- Media del término de varianza de la beta
// mu_phi_prior      .- Media del parámetro phi de los errores
// mu_mu_hiper       .- Media del hiperparámetro de la media
// sigma_mu_hiper    .- Sigma del hiperparámetro de la media
// sigma_sigma_hiper .- Sigma del hiperparámetro de la varianza
// sigma_kappa_hiper .- Sigma del prior de la varianza de PHosp
// sigma_phi_prior   .- Sigma del prior de la varianza del parámetro phi de errores
//
// Outputs:
// ---------------------------
// HospPred      .- HospPred[i,j] representa el porcentaje de ocupación hospitalaria predicho por 
//                  el modelo para estado i columna j
// \alpha        .- log efecto del estado sobre ocupación hospitalaria
// \lambda_k     .- log efecto de un aumento en el % de ocupación hospitalaria sobre la razón de 
//                  momios. Es decir, para un cambio Δ en la ocupación hospitalaria del k-ésimo 
//                  día previo, PHosp{,t-k}, el efecto sobre la razón de momios de PHosp{,t} es:
//                  exp(lambda_k*Δ)
// b_i,a_i       .- log efecto de la diferencia entre estar en el tiempo inicial 0y el momento en 
//                  el que ocurre el pico (b_i) / valle (a_i) en el tiempo 180. 
// sigma_error   .- es la varianza del término de error: error_{j,t}.
// \phi_j        .- es el log efecto de un aumento en el error en el tiempo t-j: error_{j,t}.
// kappa         .- es la varianza de PHosp{,t} para todo t.
// mu_estado     .- log efecto promedio (en escala log) del efecto del estado (alpha)
// sigma_estado  .- varianza del log efecto (en escala log) del efecto del estado (alpha)
// mu_time       .- log efecto promedio (escala log) del efecto de las olas en el tiempo (a_i,b_i)
// sigma_time    .- varianza del log efecto promedio del efecto de las olas en el tiempo (a_i,b_i)
// mu            .- log efecto promedio (escala log) del efecto de las hospitalizaciones pasadas
// sigma         .- varianza del log efecto promedio (escala log) del efecto de las 
//                  hospitalizaciones pasadas
//
// Elaborado por:
// ---------------------------
// Rodrigo Zepeda-Tello rodrigo.zepeda[at]imss.gob.mx
// Valeria Pérez        valeria.perez.mat[at]gmail.com
//
//------------------------------------------------------------------------------
//------------------------------------------------------------------------------

data {
  
  //Datos
  //----------------------------------------------------------------------------
  int<lower=1> nestados;            // Cantidad de estados incluidos en el modelo
  int<lower=1> ndias;               // Cantidad de días modelados
  int<lower=0> dias_predict;        // Cantidad de días a predecir (total dias = ndias + dias_predict)
  matrix[nestados, ndias] PHosp;    // % Ocupación hospitalaria al día t para estado j
  
  //Hiperparámetros del modelo
  //----------------------------------------------------------------------------
  int<lower=0> p;                   // ARMA (p,q)
  int<lower=0> q;                   // ARMA (p,q)
  int<lower=0> r;                   // Cantidad de olas a considerar en el modelo 
  
  //Hiperparámetros sobre las distribuciones
  //----------------------------------------------------------------------------
  real mu_kappa_prior;              // Media del término de varianza de la beta
  real mu_phi_prior;                // Media del parámetro phi de los errores
  real mu_mu_hiper;                 // Media del hiperparámetro de la media
  real<lower=0> sigma_mu_hiper;     // Sigma del hiperparámetro de la media
  real<lower=0> sigma_sigma_hiper;  // Sigma del hiperparámetro de la varianza
  real<lower=0> sigma_kappa_hiper;  // Sigma del prior de la varianza de PHosp
  real<lower=0> sigma_phi_prior;    // Sigma del prior de la varianza del parámetro phi de errores
  
}

parameters {
  
  //Efectos autoregresivos
  //----------------------------------------------------------------------------
  real mu;
  real<lower=0> sigma;

  //Para la autoregresión con parámetros lambda
  //----------------------------------------------------------------------------
  real lambda[p];
  
  //Efecto de los términos de error
  //----------------------------------------------------------------------------
  real phi[q];
  
  //Efecto global del estado
  //----------------------------------------------------------------------------
  vector[nestados] alpha; 
  
  //Varianza para PHosp
  //----------------------------------------------------------------------------
  vector[nestados] kappa_alpha;
  vector[nestados] kappa_beta;

  //Efectos de estado
  //----------------------------------------------------------------------------
  real mu_estado;    
  real<lower=0> sigma_estado;
  
  //Efectos de tiempo
  //----------------------------------------------------------------------------
  real mu_time;
  real<lower=0> sigma_time;
  
  //Senos y cosenos para oscilar
  //----------------------------------------------------------------------------
  matrix[nestados,r] a_sine;
  matrix[nestados,r] b_cosine;
  
  //Términos de error
  //----------------------------------------------------------------------------
  real<lower=0> sigma_error[nestados];
  
}

model {

  // Parámetros
  matrix[nestados,ndias] logit_p_estado;
  matrix[nestados,q]     residuals;
  vector[nestados] kappa;
  
  // Hiperparámetros
  mu           ~ normal(mu_mu_hiper, sigma_mu_hiper);
  sigma        ~ cauchy(0, sigma_mu_hiper);
  mu_estado    ~ normal(mu_mu_hiper, sigma_mu_hiper);
  sigma_estado ~ cauchy(0, sigma_mu_hiper);
  mu_time      ~ normal(mu_mu_hiper, sigma_mu_hiper);
  sigma_time   ~ cauchy(0, sigma_mu_hiper);

  // Creamos los parámetros
  lambda ~ normal(mu, sigma);
  phi    ~ normal(mu_phi_prior, sigma_phi_prior);
  alpha  ~ normal(mu_estado, sigma_estado);
  
  kappa_alpha ~ normal(mu_kappa_prior, sigma_kappa_hiper);
  kappa_beta  ~ normal(mu_kappa_prior, sigma_kappa_hiper);
  
  // Parámetros temporales para las oscilaciones
  for (i in 1:r){
    a_sine[,i]   ~ normal(mu_time, sigma_time);
    b_cosine[,i] ~ normal(mu_time, sigma_time);
  }  
  
  // Varianza del término de error
  sigma_error ~ normal(0, 100);

  //Loopeamos
  logit_p_estado[,1:p] = logit(PHosp[,1:p]);
  for (t in (p + 1):(p + q)){
    logit_p_estado[,t] = alpha; 
    for (k in 1:r){
      logit_p_estado[,t] += b_cosine[,k]*cos(2.0*k*pi()*t/365.0) + 
                              a_sine[,k]*sin(2.0*k*pi()*t/365.0);
    }
    for (k in 1:p){
      logit_p_estado[,t] += lambda[k]*logit(PHosp[,t-k]);
    }
    kappa = exp(kappa_alpha + (kappa_beta .* logit(PHosp[,t-1])));
    PHosp[,t] ~ beta_proportion(inv_logit(logit_p_estado[,t]), kappa);
  }
  
  for (t in ((p + q) + 1):ndias){
    logit_p_estado[,t] = alpha;
    for (k in 1:r){
      logit_p_estado[,t] += b_cosine[,k]*cos(2.0*k*pi()*t/365.0) + 
                              a_sine[,k]*sin(2.0*k*pi()*t/365.0);
    }
    for (k in 1:p){
      logit_p_estado[,t] += lambda[k]*logit(PHosp[,t-k]);
    } 
    for (k in 1:q){
      residuals[,k]      = (logit_p_estado[,t - k] - logit(PHosp[,t - k]));
      residuals[,k]      ~ normal(0.0, sigma_error);
      logit_p_estado[,t] += phi[k]*residuals[,k];
    }
    kappa = exp(kappa_alpha + (kappa_beta .* logit(PHosp[,t-1])));
    PHosp[,t] ~ beta_proportion(inv_logit(logit_p_estado[,t]), kappa);
  }
}

//Adapted from https://jwalton.info/Stan-posterior-predictives/
generated quantities {
  
  // Generate posterior predictives
  matrix[nestados, ndias + dias_predict] HospPred;
  matrix[nestados, ndias + dias_predict] logit_p_estado;
  matrix[nestados, q] error_term;
  vector[nestados] kappa;
  
  for (k in 1:q){
      error_term[,k] = to_vector(normal_rng(rep_vector(0.0, nestados), sigma_error));
  }
  
  //Loopeamos
  logit_p_estado[,1:p] = logit(PHosp[,1:p]);
  
  // First m points are to start model
  HospPred[, 1:p] = PHosp[, 1:p];
  
  // Posterior dist for observed
  for (t in (p + 1):(p + q)){
    logit_p_estado[,t] = alpha;
    for (k in 1:r){
      logit_p_estado[,t] += b_cosine[,k]*cos(2.0*k*pi()*t/365.0) + 
                              a_sine[,k]*sin(2.0*k*pi()*t/365.0);
    }
    for (k in 1:p){
      logit_p_estado[,t] += lambda[k]*logit(PHosp[,t-k]);
    }
    kappa = exp(kappa_alpha + (kappa_beta .* logit(PHosp[,t-1])));
    HospPred[, t] = to_vector( beta_proportion_rng(inv_logit(logit_p_estado[,t]), kappa) );
  }

  // Posterior dist for with error
  for (t in ((p + q) + 1):ndias){
    logit_p_estado[,t] = alpha;
    for (k in 1:r){
      logit_p_estado[,t] += b_cosine[,k]*cos(2.0*k*pi()*t/365.0) + 
                              a_sine[,k]*sin(2.0*k*pi()*t/365.0);
    }
    for (k in 1:p){
      logit_p_estado[,t] += lambda[k]*logit(PHosp[,t-k]);
    }  
    for (k in 1:q){
      logit_p_estado[,t] += phi[k]*to_vector( normal_rng(logit_p_estado[,t - k] - logit(PHosp[,t - k]), sigma_error) );
    }
    kappa = exp(kappa_alpha + (kappa_beta .* logit(PHosp[,t-1])));
    HospPred[, t] = to_vector( beta_proportion_rng(inv_logit(logit_p_estado[,t]), kappa) );
  }
  
  // Posterior dist for unobserved but still using some observed
  for (t in (ndias + 1):(ndias + p)){
    logit_p_estado[,t] = alpha;
    for (k in 1:r){
      logit_p_estado[,t] += b_cosine[,k]*cos(2.0*k*pi()*t/365.0) + 
                              a_sine[,k]*sin(2.0*k*pi()*t/365.0);
    }
    for (k in 1:p){
      if (t - k <= ndias){
        logit_p_estado[,t] += lambda[k]*logit(PHosp[,t-k]);
      } else {
        logit_p_estado[,t] += lambda[k]*logit_p_estado[,t-k];
      }
    }
    for (k in 1:q){
      if (t - k <= ndias){
        error_term[,k]      =  to_vector( normal_rng(logit_p_estado[,t - k] - logit(PHosp[,t - k]), sigma_error) );
        logit_p_estado[,t] +=  phi[k]*error_term[,k];
      } else {
        logit_p_estado[,t] +=  phi[k]*error_term[,k];
      }
    }
    if (t == (ndias + 1)){
      kappa = exp(kappa_alpha + (kappa_beta .* logit(PHosp[,t-1])));
    } else {
      kappa = exp(kappa_alpha + (kappa_beta .* logit_p_estado[,t - 1]));
    }
    HospPred[, t] = to_vector( beta_proportion_rng(inv_logit(logit_p_estado[,t]), kappa) );
  }

  // Posterior dist for unobserved 
  for (t in (ndias + p + 1):(ndias +  dias_predict)){
    logit_p_estado[,t] = alpha; 
    for (k in 1:r){
      logit_p_estado[,t] += b_cosine[,k]*cos(2*pi()*t/(365.0/k)) + 
                              a_sine[,k]*sin(2*pi()*t/(365.0/k));
    }
    for (k in 1:p){
      logit_p_estado[,t] += lambda[k]*logit_p_estado[,t-k];;
    }
    //Create error term
    for (k in 1:(q-1)){
        error_term[,q - (k - 1)] = error_term[,q - k];
    }
    error_term[,1] = to_vector(normal_rng(rep_vector(0.0, nestados), sigma_error));
    for (k in 1:q){
      logit_p_estado[,t] += phi[k]*error_term[,k];
    }
    kappa = exp(kappa_alpha + (kappa_beta .* logit_p_estado[,t - 1]));
    HospPred[, t] = to_vector( beta_proportion_rng(inv_logit(logit_p_estado[,t]), kappa) );
  }
}