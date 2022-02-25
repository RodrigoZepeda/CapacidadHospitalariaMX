#ORCHESTRATE
#-----------------------------
#File for downloading info from the IRAG website, creating the R database
#and running the STAN model until uploading the info to github
#Author: Rodrigo Zepeda
#Contact: rzepeda17[at]gmail.com
#----------------------------------------
date=$(date '+%Y-%m-%d')
/home/rodrigo/miniconda3/envs/CapacidadHospitalaria/bin/python3 /home/rodrigo/CapacidadHospitalariaMX/scripts/descarga_estatal.py
/home/rodrigo/miniconda3/envs/CapacidadHospitalaria/bin/python3 /home/rodrigo/CapacidadHospitalariaMX/scripts/descarga_municipal.py
/home/rodrigo/miniconda3/envs/CapacidadHospitalaria/bin/python3 /home/rodrigo/CapacidadHospitalariaMX/scripts/genera_base_unica.R
/usr/bin/git -C /home/rodrigo/CapacidadHospitalariaMX add .
/usr/bin/git -C /home/rodrigo/CapacidadHospitalariaMX commit -m "Actualización ${date}"
/usr/bin/git -C /home/rodrigo/CapacidadHospitalariaMX push origin main