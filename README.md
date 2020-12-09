# HospitalizacionesCOVIDMX

El presente repositorio contiene los datos de capacidad hospitalaria divulgados por la Secretaría de Salud a través del portal de la UNAM
[https://www.gits.igg.unam.mx/red-irag-dashboard/reviewHome#](https://www.gits.igg.unam.mx/red-irag-dashboard/reviewHome#)

## Datos
Los datos descargados están en la carpeta `data/`. 

## Descarga de datos via chromedriver

Si deseas descargar los datos por ti misma, el archivo `Descarga_Resumen.py` contiene el webscrapper para entrar al portal y bajar los datos de manera automática. Para hacerlo es necesario que tengas `chromedriver` ([descarga aquí](https://chromedriver.chromium.org)) y GoogleChrome o Chromium. Dentro del archivo es necesario que cambies las primeras líneas:

```{python}  
folder_of_download = "/Users/rod/Dropbox/ 3DashboardCONACYT/data"
direccion_chromedriver = '/Users/rod/Dropbox/DashboardCONACYT/chromedriver'
descargar_desde = "2020-04-01"
descargar_hasta = "2020-04-05"
```

donde `folder_of_download` es la carpeta en tu máquina donde quieres guardar los datos, `direccion_chromedriver` es la dirección donde descargaste el `chromedriver`, `descargar_desde`y `descargar_hasta` son las fechas en formato `año-mes-día` de cuándo a cuándo quieres descargar. 

**Ojo** Te recomiendo ir de 30 en 30 días porque si no arroja error. 