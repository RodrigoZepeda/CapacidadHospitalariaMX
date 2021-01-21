# HospitalizacionesCOVIDMX

El presente repositorio contiene los datos de capacidad hospitalaria divulgados por la Secretaría de Salud a través del portal de la UNAM
[https://www.gits.igg.unam.mx/red-irag-dashboard/reviewHome#](https://www.gits.igg.unam.mx/red-irag-dashboard/reviewHome#)

## Datos
Los datos descargados sin procesar están en la carpeta [`raw/`](https://github.com/RodrigoZepeda/CapacidadHospitalariaMX/tree/master/data) mientras que la base de datos única procesada está en [`processed/`](https://github.com/RodrigoZepeda/CapacidadHospitalariaMX/tree/master/processed)

## Visualizaciones
En la carpeta [`images/`](https://github.com/RodrigoZepeda/CapacidadHospitalariaMX/tree/master/images) puedes encontrar las imágenes de ocupación hospitalaria para cada hospital.  

## Descarga de datos via chromedriver

Si deseas descargar los datos por ti misma, el archivo `scripts/descarga_datos.py` contiene el webscrapper para entrar al portal y bajar los datos de manera automática. Para hacerlo es necesario que tengas `chromedriver` ([descarga aquí](https://chromedriver.chromium.org)) y GoogleChrome o Chromium. Dentro del archivo es necesario que cambies las primeras líneas:

```python
folder_of_download = "/Users/rod/Dropbox/ 3DashboardCONACYT/raw"
direccion_chromedriver = '/Users/rod/Dropbox/DashboardCONACYT/chromedriver'
descargar_desde = "2020-04-01"
descargar_hasta = "2020-04-05"
```

donde `folder_of_download` es la carpeta en tu máquina donde quieres guardar los datos, `direccion_chromedriver` es la dirección donde descargaste el `chromedriver`, `descargar_desde`y `descargar_hasta` son las fechas en formato `año-mes-día` de cuándo a cuándo quieres descargar. 

**Ojo** Te recomiendo ir de 20 en 20 días porque si no arroja error. 

## Limpieza de datos

El archivo `scripts/genera_base_unica.R` se encarga de generar una única base en `.rds` con la información completa. 

## Generación de imágenes

El archivo `scripts/genera_graficas.R` se encarga de generar una gráfica histórica única para cada unidad médica (identificada por CLUES). 

## ¡Colabora!

1. Por favor ayúdame a mejorar el scrapper para que no se trabe cuando quieres descargar todo el periodo.

2. Apoyo en la generación de modelos estadísticos o de aprendizaje de máquina que permitan predecir la ocupación hospitalaria a futuro sería excelente. (Yo estoy por agregar unos preliminares)