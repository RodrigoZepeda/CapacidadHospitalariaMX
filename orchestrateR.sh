#ORCHESTRATE
#-----------------------------
#File for downloading info from the IRAG website, creating the R database
#and running the STAN model until uploading the info to github
#Author: Rodrigo Zepeda
#Contact: rzepeda17[at]gmail.com
#----------------------------------------
date=$(date '+%Y-%m-%d')
python3 scripts/descarga_estatal.py
python3 scripts/descarga_municipal.py
Rscript scripts/genera_base_unica.R
git add .
git commit -m "Se actualizadon datos hasta ${date}"
git push origin master
Rscript model/fit_model_hosp_multistate.R
cd predictions
gs -q -dNOPAUSE  -dBATCH -dAutoRotatePages=/None -dSAFER -sDEVICE=pdfwrite -sOutputFile=PREDICCIONES_HOSP.pdf *.pdf
rm Hosp*.pdf
cd .. 
yes | cp predictions/Predichos.csv docs/data/Predichos.csv
git add .
git commit -m "Se actualizadon predicciones hasta ${date}"
git push origin master