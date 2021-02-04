//Multilevel model for hospital capacity at a hospital level
//----------------------------------------------------------
// Objective
//--------------------
// Model to estimate hospital capacity for each hospital in Mexico adjusting
// for state, healthcare system (IMSS/SSA), hospital
//
// Model description
// -------------------
// Let P denote the hospital capacity. P ~ Beta (mu, phi) where
// logit(mu)= alpha + beta[h] + gamma_inst[i] + delta_est[k] 
//                        + suma_{j=1}^{m} lambda[j] * p[h,l]
//
// with sum(beta_h)=0, sum(gamma_inst)=0, sum(delta_est)=0
//
// 
// Here the parameters represent:
//   alpha .- the global covid effect
//   beta[h] .- effect of hospital h 
//   gamma_inst[i] .- effect of the institute i 
//   delta_est[k] .- the effect of state k (32 states in Mexico)
//   lambda[j] .- effect of historic percetages of hospitalization
//   p[h,l] .-capacity of hospital h at time l
//
// 
// Data
// ----------------------
//  h .- number of hospitals in the model
//  l .- number of days (dates) for the hospitals
//  P .- matrix of total beds used containing h (rows) hospitals and l (columns)
//       is a point in time
//  I .- vector of size h containing a number that represents each institution
//  S .- vector of size h that contains a number indicating the state of Mexico each hospital refers to 
//
//
//
// Authors
// ------------------
// Valeria P?rez valeria.perez.mat@gmail.com


// The input data 
data {
  int<lower=1> h;                     // Total number of hospitals
  int<lower=1> l;                     // Total days where the hospital capacity was measured
  real<lower=0, upper=1> P[h,l];      // P[3,5] refers to number of beds in hospital #3 on day #5
  int<lower=0> I[h];                  // falta ver que numero representa cada institucion
  int<lower=0> S[h];                  // falta ver que numero representa cada estado
  int<lower=1> m;                     // orden de la autoregresi?n
  int<lower=1> inst;   //numero de instituciones
  int<lower=1> est;  //numero de estados
  
}

// The parameters accepted by the model. Our model
parameters {
  
  //Hierarchical model parameters
  real alpha;                         //Global effect
  real mu_global;                     //Mean of global effect
  real mu_beta[l - 1];                //Mean of previous effect for hospitals
  real mu_gamma[l - 1];               //Mean of previous effect for institution
  real mu_delta[l - 1];               //Mean of previous effect for states
  real mu_lambda[m];                  //Mean of previous effects for hospital beds
  real<lower = 0> sigma_global;           //SD of global effect
  real<lower = 0> sigma_beta[l - 1];  //SD of previous effect for hospitals
  real<lower = 0> sigma_gamma[l - 1]; //SD of previous effect for institution
  real<lower = 0> sigma_delta[l - 1]; //SD of previous effect for states
  real<lower = 0> sigma_lambda[m]; //SD of previous effects for hospital beds
  
  //Parameters
  real beta_sim[l - 1];
  real gamma_inst_sim[l - 1];
  real delta_est_sim[l - 1];
  real<lower=0> b;
  real lambda[m];

}

transformed parameters {
   
  //Force sum of betas = 0, gammas=0, sigmas=0, to identify alpha
    real betas[l];
    real gamma_inst[inst];
    real delta_est[est];

  //Betas
  betas[1:(l - 1 )] = beta_sim[1:(l - 1)];
  betas[l]   = -sum(beta_sim);

  //Gammas
  gamma_inst[1:(inst - 1)] = gamma_inst_sim[1:(inst - 1)];
  gamma_inst[inst] = -sum(gamma_inst_sim);
  
  //Deltas
  delta_est[1:(est - 1)] = delta_est_sim[1:(est - 1)];
  delta_est[est] = -sum(delta_est_sim);
  

}

model {
  //Variable instantiation
  real logit_mu[h, l];  //logit(Probability of hospital occupation)
  real mu_true[h, l];
  real mu_real[h, l];
  real p[h, l];
  real q[h, l];
  
  //Hierarchical priors
  //------------------------------------------------------
  mu_global    ~ normal(0,1);
  mu_beta      ~ normal(0,1);
  mu_gamma     ~ normal(0,1);
  mu_delta     ~ normal(0,1);
  mu_lambda    ~ normal(0,1); 
  b            ~ exponential(1); //Se cambio de normal por el error de que el segundo parametro sea 0
  
  sigma_global     ~ gamma(0.01, 0.01);
  sigma_beta       ~ gamma(0.01, 0.01);
  sigma_gamma      ~ gamma(0.01, 0.01);
  sigma_delta      ~ gamma(0.01, 0.01);
  sigma_lambda     ~ gamma(0.01, 0.01);
  
  
  //Multilevel model
  //------------------------------------------------------
  alpha             ~ normal(mu_global, sigma_global);
  beta_sim          ~ normal(mu_beta, sigma_beta);
  gamma_inst_sim    ~ normal(mu_gamma, sigma_gamma);
  delta_est_sim     ~ normal(mu_delta, sigma_delta);
  lambda            ~ normal(mu_lambda, sigma_lambda);
  
  
  
   //Get logistic model

  //------------------------------------------------------
  for (j in 1:h){  
    for (i in (m+1):l){  // chance empieza en m
      
      //Baseline effect
      logit_mu[j,i] = alpha + betas[j] + gamma_inst[I[j]] + delta_est[S[j]]; 
      
      //Add previous measurement effects of positive 
      //chance no sobraba el if >1
      
      for (k in 1:m){
        logit_mu[j,i] += lambda[k]*P[j,(i-k)]; 
      } 
      
      
      //Get true values
      mu_true[j,i] = inv_logit(logit_mu[j,i]);
      p[j, i] = mu_true[j,i]*b;
      q[j, i] = (1 - mu_true[j,i])*b;


      //Establish measured variable
      P[j,i] ~ beta(p[j, i], q[j, i]);

      }
    }
}




