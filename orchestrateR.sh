#ORCHESTRATE
#-----------------------------
#File for downloading info from the IRAG website, creating the R database
#and running the STAN model until uploading the info to github
#Author: Rodrigo Zepeda
#Contact: rzepeda17[at]gmail.com
#----------------------------------------
date=$(date '+%Y-%m-%d')
/home/rod/miniconda3/envs/CapacidadHospitalariaMx/bin/python3 scripts/descarga_estatal.py
/home/rod/miniconda3/envs/CapacidadHospitalariaMx/bin/python3 scripts/descarga_municipal.py
/usr/bin/Rscript scripts/genera_base_unica.R
/usr/bin/git add .
/usr/bin/git commit -m "Se actualizaron datos hasta ${date}"
/usr/bin/git push origin master
/usr/bin/Rscript model/fit_model_hosp_multistate.R
cd predictions
/usr/bin/gs -q -dNOPAUSE  -dBATCH -dAutoRotatePages=/None -dSAFER -sDEVICE=pdfwrite -sOutputFile=PREDICCIONES_HOSP.pdf *.pdf
rm Hosp*.pdf
cd .. 
yes | cp predictions/Predichos.csv docs/data/Predichos.csv
/usr/bin/git add .
/usr/bin/git commit -m "Se actualizaron predicciones hasta ${date}"
/usr/bin/git push origin master