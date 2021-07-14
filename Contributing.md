# Contribuir a este repositorio 

## Iniciar

Antes de empezar:
- Revisa los [issues existentes](https://github.com/RodrigoZepeda/CapacidadHospitalariaMX/issues). Apoyar en resolverlos es una excelente forma de iniciar. 

### ¿No ves tu problema, abre uno?

Si encuentras una idea o bien un problema (`bug`) en la información actual, por favor abre un `issue`. 

### Apoya en Windows

El orchestrate que se encarga de correr todo está diseñado para `UNIX`. No tenemos acceso a máquinas Windows para construir uno para el sistema. 

## Quiero hacer un modelo nuevo

### Ideas
Algunas ideas de cosas a agregar/cambiar al modelo: 

- **Efecto vacunación**. Nos encantaría agregar efectos sobre las hospitalizaciones resultado de distintos escenarios de vacunación y que puedan predecir.

- **Efecto semáforo**. Nos encantaría poder construir contrafactuales del estilo _qué pasaría si mañana cambia el semáforo a X ó Y color_. 

- **Otras variables** Puedes extender el modelo a que sea multivariado e incluya otras variables de los datos públicos (por ejemplo mortalidad ó casos confirmados). 

- **Cambiar la regresión** Quizá alguno de los factores sobra o falta en el modelo actual. Por ejemplo, podría ser que el modelo funcionara de mejor forma en términos de una transformación, digamos `probit(PHosp)`, o bien cambiando las variables (por ejemplo viendo efecto de las diferencias: `beta*(PHosp[,t] - PHosp[,t-1])`. 

¡Cualquier opción de mejora es bienvenida!

### Evaluación
Cualquier modelo realizado con estos datos es bienvenido. Lo que estamos buscando en un modelo es:

- **Capacidad predictiva**. Este repositorio es para construir modelos que nos sirvan para saber cómo se va ser la ocupación hospitalaria en el país. No necesitamos que el modelo explique, sólo que prediga. 

    - De los modelos involucrados se evalúa siempre la capacidad predictiva ajustando el modelo el `10-jul-2020`, `10-oct-2020`, `10-ene-2021` y calculando la verdadera probabilidad de los intervalos de confianza. Un modelo nuevo debe predecir mejor que el actual a partir de esas fechas bajo sus intervalos.

    - Intervalos cortos. Bajo la misma precisión se prefiere siempre un modelo con intervalos más pequeños. 

    - Futuros realistas. Predicciones donde la capacidad hospitalaria futura se estanque en cero no son realistas pues siempre habrá necesidad.      

- **Velocidad**. El modelo debería poder ajustarse y correr al menos cada dos o tres días. 

- **(EXTRA) Contrafactuales**. Estamos también interesados en modelos que nos permitan saber _qué pasaría sí_ bajo cambios de color en el semáforo, apertura de escuelas, vacunación o cualquier otra medida que permita informar las políticas. 

### Autorías
Contribuciones menores (cambios pequeños donde había una coma y debía ser un punto). Califican para agradecimiento no autoría. 

Contribuciones mayores (generación de un nuevo modelo, mejora del modelo presente). Califican para autoría. 

> Si tú tienes ya tu propio modelo y no te interesa compartir autoría del mismo pero sí quieres compartirlo. ¡Hazlo! Indícalo en tu `pull-request`. 

