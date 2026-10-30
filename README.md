# MTA-NFS-Underground-2-Speedo-main

Velocímetro de estilo Need for Speed: Underground 2 para MTA:SA, con velocidad digital, cuentarrevoluciones e indicadores de vida del vehículo y nitro.

- Reloj principal: RPM estimadas a partir de velocidad y marcha, con aguja suavizada y aviso de cambio en la zona roja.
- Velocidad en km/h y marcha N/R.
- Arco azul: nivel real del nitro, con recorte radial. El recurso no instala ni recarga NOS.
- Anillo interior: vida del vehículo; verde, ámbar o rojo según el daño. 1000 HP es lleno; 250 HP, vacío.
- Reloj pequeño: turbo simulado. Sube progresivamente al acelerar, baja al soltar y entra en vacío al circular marcha atrás.
- Se oculta a pie, al morir y mientras el mapa está abierto.

## Activación

1. Copia la carpeta completa `MTA-NFS-Underground-2-Speedo-main` en la carpeta `resources` de tu servidor.
2. En la consola del servidor ejecuta `refresh` y después `start MTA-NFS-Underground-2-Speedo-main`.
3. Para arrancar el recurso con el servidor, añade `<resource src="MTA-NFS-Underground-2-Speedo-main" startup="1" protected="0" />` en `mtaserver.conf`.

El velocímetro está **activado por defecto** para cada jugador y aparece al entrar en un vehículo, también si el recurso se inicia cuando el jugador ya está dentro.

Escribe **`/nfsu2`** en el chat para desactivarlo y repite el comando para volver a activarlo. En la consola F8 utiliza `nfsu2` sin la barra. El cambio solo afecta al jugador que ejecuta el comando, se mantiene al cambiar de vehículo o reaparecer y se restablece a activado al reiniciar el recurso o reconectarse.

La tabla `CFG` de `client.lua` permite ajustar el nombre del comando (sin `/`), ancho, márgenes y límite de RPM. Se adapta a la resolución y se ancla abajo a la derecha. `LAYOUT` conserva los ajustes de posición y pivotes de las imágenes.
