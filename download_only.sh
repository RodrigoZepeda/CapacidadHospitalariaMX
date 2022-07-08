#ORCHESTRATE
#-----------------------------
#File for downloading 
#Author: Rodrigo Zepeda
#Contact: rzepeda17[at]gmail.com
#----------------------------------------
. ~/.keychain/`/bin/hostname`-sh
cd /home/rodrigo/CapacidadHospitalariaMX
date=$(date '+%Y-%m-%d')
/home/rodrigo/miniconda3/envs/CapacidadHospitalaria/bin/python3 /media/rodrigo/covid/CapacidadHospitalariaMX/scripts/descarga_estatal.py
/home/rodrigo/miniconda3/envs/CapacidadHospitalaria/bin/python3 /media/rodrigo/covid/CapacidadHospitalariaMX/scripts/descarga_municipal.py
/usr/bin/R < /media/rodrigo/covid/CapacidadHospitalariaMX/scripts/genera_base_unica.R --no-save
/usr/bin/git -C /media/rodrigo/covid/CapacidadHospitalariaMX add .
/usr/bin/git -C /media/rodrigo/covid/CapacidadHospitalariaMX commit -m "Actualización ${date}"
/usr/bin/git -C /media/rodrigo/covid/CapacidadHospitalariaMX push origin master