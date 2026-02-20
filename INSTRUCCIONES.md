# Game Bot - AutoHotkey v1.1

Bot generico para automatizar juegos en segundo plano (background).
No mueve tu mouse, no activa la ventana del juego, trabaja en silencio.

---

## Paso 1: Instalar AutoHotkey v1.1

1. Ve a **https://www.autohotkey.com/**
2. Descarga **AutoHotkey v1.1** (NO la version 2.0)
3. Ejecuta el instalador y sigue los pasos (siguiente, siguiente, instalar)
4. Listo, ya puedes ejecutar archivos `.ahk`

---

## Paso 2: Preparar las imagenes del juego

El bot necesita capturas de pantalla de los botones de tu juego para saber donde hacer clic.

1. Abre la carpeta `imagenes/` que esta junto al script
2. Lee el archivo `LEEME.txt` dentro de esa carpeta
3. Haz capturas de los botones de tu juego y guardalas como BMP:
   - `boton_atacar.bmp` - El boton de atacar
   - `boton_recoger.bmp` - El boton para recoger items
   - `boton_aceptar.bmp` - El boton de aceptar/OK
   - `pantalla_victoria.bmp` - Algo unico de la pantalla de victoria
   - `pantalla_derrota.bmp` - Algo unico de la pantalla de derrota
   - `menu_principal.bmp` - Algo unico del menu principal

**Consejo:** Solo necesitas las imagenes que tu juego tenga. Si tu juego no tiene pantalla de victoria, no la necesitas.

---

## Paso 3: Ejecutar el bot

1. Haz doble clic en `GameBot.ahk`
2. Se abrira la ventana del bot con la interfaz grafica

---

## Paso 4: Seleccionar la ventana del juego

Tienes 3 formas de hacerlo:

### Opcion A: Detectar con clic (recomendada)
1. Haz clic en el boton **"DETECTAR (clic)"**
2. Aparece un aviso; tienes 5 segundos para hacer clic en la ventana de tu juego
3. El bot captura automaticamente el titulo de esa ventana

### Opcion B: Listar ventanas
1. Haz clic en **"Listar Ventanas"**
2. Aparece una lista con todas las ventanas abiertas
3. Selecciona la de tu juego y haz clic en "SELECCIONAR ESTA VENTANA"

### Opcion C: Escribir el titulo
1. Haz clic en **"Escribir Titulo"**
2. Escribe el titulo exacto de la ventana de tu juego
3. Haz clic en Aceptar

Despues de seleccionar, usa **"Verificar Ventana"** para confirmar que funciona.

---

## Paso 5: Configurar el bot

- **Variacion (tolerancia):** Que tan flexible es al buscar imagenes (50 es bueno, sube a 80-100 si no encuentra nada)
- **Intervalo (ms):** Cada cuantos milisegundos busca (1000 = 1 segundo)
- **Max reintentos:** Cuantas veces intenta hacer clic antes de rendirse
- **Modo Debug:** Activa/desactiva los mensajes en el log

---

## Paso 6: Iniciar el bot

- Haz clic en **"INICIAR (F12)"** o presiona **F12** en tu teclado
- El bot empezara a buscar las imagenes en la ventana del juego
- Puedes ver lo que hace en el **LOG DE DEPURACION** abajo

---

## Teclas rapidas (Hotkeys)

| Tecla | Accion |
|-------|--------|
| **F12** | Iniciar / Pausar el bot |
| **F11** | Detener el bot completamente |
| **F10** | Recargar el script (reiniciar) |

---

## Como funciona el bot (logica)

El bot sigue esta logica en cada ciclo:

```
1. Verifica que la ventana siga abierta
2. Busca pantalla de VICTORIA -> Si la encuentra, clic en Aceptar
3. Busca pantalla de DERROTA  -> Si la encuentra, clic en Aceptar
4. Busca boton de RECOGER     -> Si lo encuentra, clic para recoger
5. Busca MENU PRINCIPAL       -> Si lo encuentra, busca Atacar
6. Busca boton de ATACAR      -> Si lo encuentra, clic para atacar
7. Si no encuentra nada       -> Espera y reintenta
```

Cada accion tiene reintentos automaticos y verificacion de que el clic funciono.

---

## Solucion de problemas

### El bot no encuentra las imagenes
- Sube la **Variacion** a 80 o 100
- Verifica que las capturas esten en formato BMP
- Asegurate de que el juego este en la misma resolucion que cuando hiciste las capturas
- Recorta solo el boton, no toda la pantalla

### ControlClick no funciona en mi juego
- Algunos juegos bloquean clics virtuales (anti-cheat)
- Intenta ejecutar AutoHotkey como Administrador (clic derecho > Ejecutar como administrador)
- Algunos juegos solo aceptan clics reales; en ese caso el bot no podra funcionar en background

### El bot dice que la ventana no existe
- Verifica que el titulo sea exacto (mayusculas y minusculas importan)
- Usa "Listar Ventanas" para ver el titulo real
- Asegurate de que el juego este abierto

### El bot hace clic en el lugar equivocado
- La ventana del juego NO debe moverse despues de iniciar el bot
- Si moviste la ventana, pausa (F12) y reanuda (F12) para recalcular

---

## Estructura de archivos

```
BOT/
  GameBot.ahk          <- El script principal (ejecuta este)
  INSTRUCCIONES.md     <- Este archivo
  imagenes/            <- Carpeta para las capturas
    LEEME.txt          <- Instrucciones para las capturas
    boton_atacar.bmp   <- (tu captura aqui)
    boton_recoger.bmp  <- (tu captura aqui)
    boton_aceptar.bmp  <- (tu captura aqui)
    pantalla_victoria.bmp
    pantalla_derrota.bmp
    menu_principal.bmp
```

---

## Personalizar para tu juego

Para adaptar el bot a tu juego especifico:

1. **Renombrar imagenes:** Si tu juego tiene botones diferentes, haz capturas y cambialas en la seccion de variables del script (lineas 28-33)
2. **Agregar mas estados:** Duplica un bloque de `if (BuscarImagenEnVentana(...))` en el loop principal
3. **Cambiar tiempos de espera:** Modifica los valores de `Sleep` en el loop principal
4. **Agregar mas botones:** Agrega nuevas variables `IMG_` al inicio del script y nuevos bloques en el loop
