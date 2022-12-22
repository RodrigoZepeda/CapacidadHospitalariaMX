#ORCHESTRATE
#-----------------------------
#File for downloading 
#Author: Rodrigo Zepeda
#Contact: rzepeda17[at]gmail.com
#----------------------------------------
#. ~/.keychain/`/bin/hostname`-sh
cd /home/rod/CapacidadHospitalariaMX
date=$(date '+%Y-%m-%d')
/home/rod/miniconda3/envs/CapacidadHospitalariaMx/bin/python3 /home/rod/CapacidadHospitalariaMX/scripts/descarga_estatal.py
/home/rod/miniconda3/envs/CapacidadHospitalariaMx/bin/python3 /home/rod/CapacidadHospitalariaMX/scripts/descarga_municipal.py
/usr/bin/R < /home/rod/CapacidadHospitalariaMX/scripts/genera_base_unica.R --no-save
/usr/bin/git -C /home/rod/CapacidadHospitalariaMX add .
/usr/bin/git -C /home/rod/CapacidadHospitalariaMX commit -m "Actualización ${date}"
/usr/bin/git -C /home/rod/CapacidadHospitalariaMX push origin master