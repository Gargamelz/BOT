; ============================================================================
; GAME BOT - AutoHotkey v1.1
; Bot genérico para automatizar juegos en segundo plano (background)
; ============================================================================
; HOTKEYS GLOBALES:
;   F12  = Iniciar / Pausar el bot
;   F11  = Detener el bot completamente
;   F10  = Recargar el script
; ============================================================================

#NoEnv
#SingleInstance, Force
#Persistent
SetWorkingDir, %A_ScriptDir%
SetBatchLines, -1
CoordMode, Pixel, Screen

; ============================================================================
; VARIABLES GLOBALES
; ============================================================================
global VentanaObjetivo := ""           ; Título de la ventana del juego
global BotActivo := false              ; Estado del bot (corriendo o no)
global BotPausado := false             ; Estado de pausa
global EstadoActual := "IDLE"          ; Estado actual del bot
global Variacion := 50                 ; Tolerancia de ImageSearch (0-255)
global IntervaloLoop := 1000           ; Milisegundos entre cada ciclo
global MaxReintentos := 5              ; Reintentos antes de cambiar estrategia
global ModoDebug := true               ; Mostrar logs en la GUI
global CarpetaImagenes := A_ScriptDir . "\imagenes"
global ArchivoConfig := A_ScriptDir . "\config.ini"

; Ajuste de ventana (resolución objetivo para ImageSearch)
global VentanaAncho := 960              ; Ancho objetivo en píxeles
global VentanaAlto := 540               ; Alto objetivo en píxeles
global AutoAjustar := false             ; Ajustar automáticamente al iniciar el bot

; Pasos de automatización (secuencia de botones a buscar y clicar)
global TotalPasos := 9
global PasoActual := 1
global PasoImagenes := {}
global PasoNombres := {}
PasoImagenes[1]  := ""  ; Dinámico: se actualiza en cada ciclo desde BatallaImagenes
PasoNombres[1]   := "SeleccionBatalla"
PasoImagenes[2]  := CarpetaImagenes . "\boton_auto.bmp"
PasoNombres[2]   := "Auto"
PasoImagenes[3]  := CarpetaImagenes . "\boton_iniciar.bmp"
PasoNombres[3]   := "Iniciar"
PasoImagenes[4]  := ""  ; Paso especial: escanea victoria/derrota
PasoNombres[4]   := "Resultado"
PasoImagenes[5]  := ""  ; Paso especial: tap dinámico hasta que aparezca Next
PasoNombres[5]   := "Tap hasta Next"
PasoImagenes[6]  := ""  ; Paso especial: detectar nueva batalla desbloqueada
PasoNombres[6]   := "NuevaBatalla"
PasoImagenes[7]  := CarpetaImagenes . "\boton_ok.bmp"
PasoNombres[7]   := "OK"
PasoImagenes[8]  := ""  ; Paso especial: selección de batalla (rotación)
PasoNombres[8]   := "SiguienteBatalla"
PasoImagenes[9]  := CarpetaImagenes . "\boton_equis.bmp"  ; Botón X para cerrar tras derrota
PasoNombres[9]   := "CerrarX"

; Imágenes de resultado de batalla (usadas en paso 4)
global IMG_VICTORIA := CarpetaImagenes . "\pantalla_victoria.bmp"
global IMG_DERROTA  := CarpetaImagenes . "\pantalla_derrota.bmp"

; Imágenes de tap y next (usadas en paso 5)
global IMG_TAP  := CarpetaImagenes . "\boton_tap.bmp"
global IMG_NEXT := CarpetaImagenes . "\boton_next.bmp"

; Imágenes post-victoria (usadas en pasos 6-7)
global IMG_NUEVA_BATALLA := CarpetaImagenes . "\pantalla_nueva_batalla.bmp"
global IMG_OK            := CarpetaImagenes . "\boton_ok.bmp"

; Imagen post-derrota (usada en paso 9)
global IMG_EQUIS := CarpetaImagenes . "\boton_equis.bmp"

; Rotación de batallas (pasos 1 y 8 usan esta lista)
; Paso 1: selecciona batalla actual (inicio/derrota, NO avanza)
; Paso 8: selecciona siguiente batalla (victoria, SÍ avanza)
global BatallaImagenes := {}
global BatallaNombres := {}
global TotalBatallas := 6
global BatallaActual := 1

BatallaImagenes[1] := CarpetaImagenes . "\boton_venasaur_ex.bmp"
BatallaNombres[1]  := "Venasaur EX"
BatallaImagenes[2] := CarpetaImagenes . "\boton_charizard_ex.bmp"
BatallaNombres[2]  := "Charizard EX"
BatallaImagenes[3] := CarpetaImagenes . "\boton_starmie_ex.bmp"
BatallaNombres[3]  := "Starmie EX"
BatallaImagenes[4] := CarpetaImagenes . "\boton_pikachu_ex.bmp"
BatallaNombres[4]  := "Pikachu EX"
BatallaImagenes[5] := CarpetaImagenes . "\boton_mewtwo_ex.bmp"
BatallaNombres[5]  := "Mewtwo EX"
BatallaImagenes[6] := CarpetaImagenes . "\boton_machamp_ex.bmp"
BatallaNombres[6]  := "Machamp EX"

; Repeticiones por batalla (cuántas veces se juega antes de avanzar)
global BatallaRepeticiones := {}
BatallaRepeticiones[1] := 2  ; Venasaur EX se juega 2 veces
BatallaRepeticiones[2] := 1  ; Charizard EX
BatallaRepeticiones[3] := 1  ; Starmie EX
BatallaRepeticiones[4] := 1  ; Pikachu EX
BatallaRepeticiones[5] := 1  ; Mewtwo EX
BatallaRepeticiones[6] := 1  ; Machamp EX
global RepeticionActual := 1 ; Contador de repetición actual

; Scroll automático
global ScrollActivo := false
global ScrollRelX := 200                 ; Coordenada X relativa a la ventana
global ScrollRelY := 300                 ; Coordenada Y relativa a la ventana
global ScrollCantidad := 3               ; Clicks de scroll por ciclo
global ScrollDelay := 500                ; Milisegundos de pausa entre cada scroll individual
global ScrollEnPaso := 0                 ; 0=Todos, 1-3=Paso específico

; Contadores
global ContadorAtaques := 0
global ContadorCiclos := 0
global ContadorErrores := 0

; Anti-atasco: errores consecutivos en el mismo paso
global ErroresConsecutivos := 0          ; Errores seguidos en el paso actual
global MaxErroresConsecutivos := 30      ; Limite antes de intentar recuperación

; Paso 4: contador de intentos (máquina de estados, no-bloqueante)
global ResultadoIntentos := 0

; Paso 5: tap dinámico hasta Next (máquina de estados)
global TapIntentos := 0               ; Intentos en el loop de taps
global MaxTapIntentos := 30            ; Máximo de intentos antes de recuperación
global RutaPostNext := 1              ; A dónde ir después de Next (6=victoria, 1=derrota)

; Paso 6: detección de nueva batalla desbloqueada
global NuevaBatallaIntentos := 0
global MaxNuevaBatallaIntentos := 10  ; ~10 segundos esperando antes de saltar

; ============================================================================
; CREAR CARPETA DE IMÁGENES SI NO EXISTE
; ============================================================================
if !FileExist(CarpetaImagenes)
    FileCreateDir, %CarpetaImagenes%

; ============================================================================
; CARGAR CONFIGURACIÓN GUARDADA Y CREAR GUI
; ============================================================================
CargarConfig()
CrearGUI()
return

; ============================================================================
; FUNCIÓN: Guardar configuración en archivo INI
; ============================================================================
GuardarConfig() {
    global ArchivoConfig, VentanaObjetivo, Variacion, IntervaloLoop, MaxReintentos, ModoDebug
    global VentanaAncho, VentanaAlto, AutoAjustar
    global ScrollActivo, ScrollRelX, ScrollRelY, ScrollCantidad, ScrollDelay, ScrollEnPaso

    ; Leer valores actuales de la GUI (por si el usuario cambió algo sin iniciar el bot)
    GuiControlGet, tmpVariacion, Main:, EditVariacion
    GuiControlGet, tmpIntervalo, Main:, EditIntervalo
    GuiControlGet, tmpReintentos, Main:, EditReintentos
    GuiControlGet, tmpDebug, Main:, ChkDebug
    GuiControlGet, tmpAncho, Main:, EditVentanaAncho
    GuiControlGet, tmpAlto, Main:, EditVentanaAlto
    GuiControlGet, tmpAutoAjustar, Main:, ChkAutoAjustar
    GuiControlGet, tmpScroll, Main:, ChkScroll
    GuiControlGet, tmpScrollX, Main:, EditScrollX
    GuiControlGet, tmpScrollY, Main:, EditScrollY
    GuiControlGet, tmpScrollCant, Main:, EditScrollCant
    GuiControlGet, tmpScrollDelay, Main:, EditScrollDelay
    GuiControlGet, tmpScrollPaso, Main:, DDLScrollPaso

    ; Calcular índice del paso de scroll
    tmpScrollEnPaso := 0
    Loop, 3 {
        if InStr(tmpScrollPaso, "Paso " . A_Index) {
            tmpScrollEnPaso := A_Index
            break
        }
    }

    ; Sección General
    IniWrite, %VentanaObjetivo%, %ArchivoConfig%, General, VentanaObjetivo
    IniWrite, %tmpVariacion%, %ArchivoConfig%, General, Variacion
    IniWrite, %tmpIntervalo%, %ArchivoConfig%, General, IntervaloLoop
    IniWrite, %tmpReintentos%, %ArchivoConfig%, General, MaxReintentos
    IniWrite, %tmpDebug%, %ArchivoConfig%, General, ModoDebug

    ; Sección Ventana
    IniWrite, %tmpAncho%, %ArchivoConfig%, Ventana, VentanaAncho
    IniWrite, %tmpAlto%, %ArchivoConfig%, Ventana, VentanaAlto
    IniWrite, %tmpAutoAjustar%, %ArchivoConfig%, Ventana, AutoAjustar

    ; Sección Scroll
    IniWrite, %tmpScroll%, %ArchivoConfig%, Scroll, ScrollActivo
    IniWrite, %tmpScrollX%, %ArchivoConfig%, Scroll, ScrollRelX
    IniWrite, %tmpScrollY%, %ArchivoConfig%, Scroll, ScrollRelY
    IniWrite, %tmpScrollCant%, %ArchivoConfig%, Scroll, ScrollCantidad
    IniWrite, %tmpScrollDelay%, %ArchivoConfig%, Scroll, ScrollDelay
    IniWrite, %tmpScrollEnPaso%, %ArchivoConfig%, Scroll, ScrollEnPaso
}

; ============================================================================
; FUNCIÓN: Cargar configuración desde archivo INI
; ============================================================================
CargarConfig() {
    global ArchivoConfig, VentanaObjetivo, Variacion, IntervaloLoop, MaxReintentos, ModoDebug
    global VentanaAncho, VentanaAlto, AutoAjustar
    global ScrollActivo, ScrollRelX, ScrollRelY, ScrollCantidad, ScrollDelay, ScrollEnPaso

    ; Si no existe el archivo, usar los valores por defecto (ya definidos en variables globales)
    if !FileExist(ArchivoConfig)
        return

    ; Sección General
    IniRead, tmp, %ArchivoConfig%, General, VentanaObjetivo, %VentanaObjetivo%
    VentanaObjetivo := tmp
    IniRead, tmp, %ArchivoConfig%, General, Variacion, %Variacion%
    Variacion := tmp + 0
    IniRead, tmp, %ArchivoConfig%, General, IntervaloLoop, %IntervaloLoop%
    IntervaloLoop := tmp + 0
    IniRead, tmp, %ArchivoConfig%, General, MaxReintentos, %MaxReintentos%
    MaxReintentos := tmp + 0
    IniRead, tmp, %ArchivoConfig%, General, ModoDebug, %ModoDebug%
    ModoDebug := tmp + 0

    ; Sección Ventana
    IniRead, tmp, %ArchivoConfig%, Ventana, VentanaAncho, %VentanaAncho%
    VentanaAncho := tmp + 0
    IniRead, tmp, %ArchivoConfig%, Ventana, VentanaAlto, %VentanaAlto%
    VentanaAlto := tmp + 0
    IniRead, tmp, %ArchivoConfig%, Ventana, AutoAjustar, %AutoAjustar%
    AutoAjustar := tmp + 0

    ; Sección Scroll
    IniRead, tmp, %ArchivoConfig%, Scroll, ScrollActivo, %ScrollActivo%
    ScrollActivo := tmp + 0
    IniRead, tmp, %ArchivoConfig%, Scroll, ScrollRelX, %ScrollRelX%
    ScrollRelX := tmp + 0
    IniRead, tmp, %ArchivoConfig%, Scroll, ScrollRelY, %ScrollRelY%
    ScrollRelY := tmp + 0
    IniRead, tmp, %ArchivoConfig%, Scroll, ScrollCantidad, %ScrollCantidad%
    ScrollCantidad := tmp + 0
    IniRead, tmp, %ArchivoConfig%, Scroll, ScrollDelay, %ScrollDelay%
    ScrollDelay := tmp + 0
    IniRead, tmp, %ArchivoConfig%, Scroll, ScrollEnPaso, %ScrollEnPaso%
    ScrollEnPaso := tmp + 0
}

; ============================================================================
; FUNCIÓN: Crear la interfaz gráfica principal
; ============================================================================
CrearGUI() {
    global EditVentana, EditVariacion, EditIntervalo, EditReintentos, ChkDebug, TextoEstado, LogText
    global ChkScroll, EditScrollX, EditScrollY, EditScrollCant, EditScrollDelay, DDLScrollPaso
    global EditVentanaAncho, EditVentanaAlto, ChkAutoAjustar
    global VentanaObjetivo, Variacion, IntervaloLoop, MaxReintentos, ModoDebug
    global VentanaAncho, VentanaAlto, AutoAjustar
    global ScrollActivo, ScrollRelX, ScrollRelY, ScrollCantidad, ScrollDelay, ScrollEnPaso

    ; Destruir GUI anterior si existe
    Gui, Main:Destroy

    ; Configurar fuente
    Gui, Main:Font, s9, Segoe UI
    Gui, Main:Color, 1a1a2e

    ; --- SECCIÓN: Selección de Ventana ---
    Gui, Main:Font, s10 cWhite Bold
    Gui, Main:Add, GroupBox, x10 y10 w460 h100, SELECCIÓN DE VENTANA DEL JUEGO

    Gui, Main:Font, s9 cSilver Normal
    Gui, Main:Add, Text, x25 y35, Ventana objetivo:
    Gui, Main:Font, s9 c0x00FF88
    ventanaTexto := (VentanaObjetivo != "") ? VentanaObjetivo : "(ninguna seleccionada)"
    Gui, Main:Add, Edit, x130 y32 w220 h22 vEditVentana ReadOnly, %ventanaTexto%

    Gui, Main:Font, s9 cWhite Normal
    Gui, Main:Add, Button, x360 y30 w100 h25 gDetectarVentana, DETECTAR (clic)
    Gui, Main:Add, Button, x25 y65 w140 h30 gListarVentanas, Listar Ventanas
    Gui, Main:Add, Button, x175 y65 w140 h30 gEscribirVentana, Escribir Título
    Gui, Main:Add, Button, x325 y65 w135 h30 gVerificarVentana, Verificar Ventana

    ; --- SECCIÓN: Ajuste de Ventana ---
    Gui, Main:Font, s10 cWhite Bold
    Gui, Main:Add, GroupBox, x10 y120 w460 h70, AJUSTE DE VENTANA (RESOLUCIÓN)

    Gui, Main:Font, s9 cSilver Normal
    Gui, Main:Add, Text, x25 y145, Ancho:
    Gui, Main:Add, Edit, x70 y142 w60 h22 vEditVentanaAncho, %VentanaAncho%
    Gui, Main:Add, Text, x140 y145, Alto:
    Gui, Main:Add, Edit, x175 y142 w60 h22 vEditVentanaAlto, %VentanaAlto%
    Gui, Main:Font, s9 cWhite Normal
    Gui, Main:Add, Button, x250 y140 w105 h25 gAjustarVentana, Ajustar Ventana
    Gui, Main:Add, Button, x360 y140 w100 h25 gConsultarTamano, Ver Actual
    chkAutoVal := AutoAjustar ? "Checked" : ""
    Gui, Main:Add, CheckBox, x25 y168 vChkAutoAjustar %chkAutoVal% cWhite, Auto-ajustar al iniciar bot

    ; --- SECCIÓN: Configuración ---
    Gui, Main:Font, s10 cWhite Bold
    Gui, Main:Add, GroupBox, x10 y200 w460 h100, CONFIGURACIÓN

    Gui, Main:Font, s9 cSilver Normal
    Gui, Main:Add, Text, x25 y225, Variación (tolerancia):
    Gui, Main:Add, Edit, x170 y222 w50 h22 vEditVariacion, %Variacion%
    Gui, Main:Add, UpDown, Range0-255, %Variacion%

    Gui, Main:Add, Text, x240 y225, Intervalo (ms):
    Gui, Main:Add, Edit, x360 y222 w80 h22 vEditIntervalo, %IntervaloLoop%
    Gui, Main:Add, UpDown, Range100-10000, %IntervaloLoop%

    Gui, Main:Add, Text, x25 y255, Max reintentos:
    Gui, Main:Add, Edit, x170 y252 w50 h22 vEditReintentos, %MaxReintentos%
    Gui, Main:Add, UpDown, Range1-50, %MaxReintentos%

    chkDebugVal := ModoDebug ? "Checked" : ""
    Gui, Main:Add, CheckBox, x240 y255 vChkDebug %chkDebugVal% cWhite, Modo Debug (logs visibles)

    ; --- SECCIÓN: Scroll Automático ---
    Gui, Main:Font, s10 cWhite Bold
    Gui, Main:Add, GroupBox, x10 y310 w460 h120, SCROLL AUTOMÁTICO

    Gui, Main:Font, s9 cSilver Normal
    chkScrollVal := ScrollActivo ? "Checked" : ""
    Gui, Main:Add, CheckBox, x25 y335 vChkScroll %chkScrollVal% cWhite, Activar scroll
    Gui, Main:Add, Text, x150 y336 cSilver, X (rel):
    Gui, Main:Add, Edit, x195 y333 w55 h22 vEditScrollX, %ScrollRelX%
    Gui, Main:Add, Text, x260 y336 cSilver, Y (rel):
    Gui, Main:Add, Edit, x305 y333 w55 h22 vEditScrollY, %ScrollRelY%
    Gui, Main:Add, Text, x370 y336 cSilver, Clicks:
    Gui, Main:Add, Edit, x415 y333 w45 h22 vEditScrollCant, %ScrollCantidad%
    Gui, Main:Add, UpDown, Range1-20, %ScrollCantidad%

    Gui, Main:Add, Text, x25 y363 cSilver, Scroll en paso:
    scrollPasoIndice := ScrollEnPaso + 1
    Gui, Main:Add, DropDownList, x120 y360 w195 vDDLScrollPaso Choose%scrollPasoIndice%, Todos los ciclos|Paso 1: Nivel|Paso 2: Auto|Paso 3: Iniciar
    Gui, Main:Add, Text, x325 y363 cSilver, Delay (ms):
    Gui, Main:Add, Edit, x395 y360 w60 h22 vEditScrollDelay, %ScrollDelay%
    Gui, Main:Add, UpDown, Range100-3000, %ScrollDelay%

    Gui, Main:Font, s9 cWhite Normal
    Gui, Main:Add, Button, x25 y395 w200 h25 gSeleccionarPuntoScroll, Seleccionar Punto (clic)
    Gui, Main:Add, Button, x235 y395 w225 h25 gProbarScroll, Probar Scroll

    ; --- SECCIÓN: Paso Inicial ---
    Gui, Main:Font, s10 cWhite Bold
    Gui, Main:Add, GroupBox, x10 y440 w460 h50, INICIAR EN PASO
    Gui, Main:Font, s9 cSilver Normal
    Gui, Main:Add, Text, x25 y463 cSilver, Paso:
    Gui, Main:Add, DropDownList, x65 y460 w395 vDDLPasoInicio Choose1, 1: SeleccionBatalla|2: Auto|3: Iniciar|4: Resultado|5: Tap hasta Next|6: NuevaBatalla|7: OK|8: SiguienteBatalla|9: CerrarX

    ; --- SECCIÓN: Control del Bot ---
    Gui, Main:Font, s10 cWhite Bold
    Gui, Main:Add, GroupBox, x10 y500 w460 h60, CONTROL DEL BOT

    Gui, Main:Font, s9 cWhite Normal
    Gui, Main:Add, Button, x25 y525 w140 h25 gIniciarBot, INICIAR (F12)
    Gui, Main:Add, Button, x175 y525 w140 h25 gPausarBot, PAUSAR (F12)
    Gui, Main:Add, Button, x325 y525 w135 h25 gDetenerBot, DETENER (F11)

    ; --- SECCIÓN: Estado ---
    Gui, Main:Font, s10 cWhite Bold
    Gui, Main:Add, GroupBox, x10 y570 w460 h50, ESTADO

    Gui, Main:Font, s11 c0x00FF88 Bold
    Gui, Main:Add, Text, x25 y592 w440 h20 vTextoEstado, Estado: DETENIDO  |  Ciclos: 0  |  Ataques: 0  |  Errores: 0

    ; --- SECCIÓN: Log de Depuración ---
    Gui, Main:Font, s10 cWhite Bold
    Gui, Main:Add, GroupBox, x10 y630 w460 h220, LOG DE DEPURACIÓN

    Gui, Main:Font, s8 c0x00FF88 Normal, Consolas
    Gui, Main:Add, Edit, x25 y655 w435 h185 vLogText ReadOnly Multi VScroll HScroll -Wrap BackgroundBlack,

    ; --- Mostrar ventana ---
    Gui, Main:Show, w480 h865, Game Bot - AutoHotkey v1.1
    Log("=== Game Bot iniciado ===")
    Log("Carpeta de imágenes: " . CarpetaImagenes)
    Log("Presiona F12 para iniciar/pausar, F11 para detener")
    Log("Primero selecciona la ventana del juego arriba")
    VerificarImagenes()
}

; ============================================================================
; FUNCIÓN: Escribir log en la GUI
; ============================================================================
Log(mensaje) {
    global ModoDebug
    if (!ModoDebug)
        return

    FormatTime, hora,, HH:mm:ss
    linea := "[" . hora . "] " . mensaje . "`r`n"

    GuiControlGet, contenido, Main:, LogText
    nuevo := contenido . linea

    ; Limitar log a ~500 líneas para evitar consumo excesivo de memoria
    if (StrLen(nuevo) > 30000) {
        ; Cortar la primera mitad del log
        pos := InStr(nuevo, "`n",, StrLen(nuevo) // 2)
        if (pos > 0)
            nuevo := "... (log recortado) ...`r`n" . SubStr(nuevo, pos + 1)
    }

    GuiControl, Main:, LogText, %nuevo%

    ; Auto-scroll al final (WM_VSCROLL + SB_BOTTOM)
    GuiControlGet, hLogCtrl, Main:Hwnd, LogText
    SendMessage, 0x0115, 7, 0,, ahk_id %hLogCtrl%
}

; ============================================================================
; FUNCIÓN: Actualizar barra de estado
; ============================================================================
ActualizarEstado() {
    global EstadoActual, ContadorCiclos, ContadorAtaques, ContadorErrores, BotActivo, BotPausado

    if (!BotActivo)
        estado := "DETENIDO"
    else if (BotPausado)
        estado := "PAUSADO"
    else
        estado := EstadoActual

    texto := "Estado: " . estado . "  |  Ciclos: " . ContadorCiclos . "  |  Ataques: " . ContadorAtaques . "  |  Errores: " . ContadorErrores
    GuiControl, Main:, TextoEstado, %texto%
}

; ============================================================================
; FUNCIÓN: Verificar que las imágenes existan
; ============================================================================
VerificarImagenes() {
    global PasoImagenes, PasoNombres, TotalPasos, CarpetaImagenes
    global IMG_VICTORIA, IMG_DERROTA, IMG_TAP, IMG_NEXT
    global IMG_NUEVA_BATALLA, IMG_OK, IMG_EQUIS
    global BatallaImagenes, BatallaNombres, TotalBatallas

    faltantes := 0
    Loop, %TotalPasos% {
        if (A_Index = 1) {
            Log("OK: Paso 1 -> SeleccionBatalla (dinamico, rotacion)")
            continue
        }
        if (A_Index = 4) {
            Log("OK: Paso 4 -> Resultado (escanea victoria/derrota)")
            continue
        }
        if (A_Index = 5) {
            Log("OK: Paso 5 -> Tap hasta Next (dinamico)")
            continue
        }
        if (A_Index = 6) {
            Log("OK: Paso 6 -> NuevaBatalla (deteccion opcional)")
            continue
        }
        if (A_Index = 8) {
            Log("OK: Paso 8 -> SiguienteBatalla (rotacion)")
            continue
        }
        ruta := PasoImagenes[A_Index]
        nombre := PasoNombres[A_Index]
        if !FileExist(ruta) {
            Log("AVISO: Falta imagen paso " . A_Index . " -> " . nombre)
            faltantes++
        } else {
            Log("OK: Paso " . A_Index . " -> " . nombre)
        }
    }

    ; Verificar imágenes de resultado
    if !FileExist(IMG_VICTORIA) {
        Log("AVISO: Falta imagen -> pantalla_victoria.bmp")
        faltantes++
    } else {
        Log("OK: pantalla_victoria.bmp")
    }
    if !FileExist(IMG_DERROTA) {
        Log("AVISO: Falta imagen -> pantalla_derrota.bmp")
        faltantes++
    } else {
        Log("OK: pantalla_derrota.bmp")
    }

    ; Verificar imágenes de tap y next
    if !FileExist(IMG_TAP) {
        Log("AVISO: Falta imagen -> boton_tap.bmp")
        faltantes++
    } else {
        Log("OK: boton_tap.bmp")
    }
    if !FileExist(IMG_NEXT) {
        Log("AVISO: Falta imagen -> boton_next.bmp")
        faltantes++
    } else {
        Log("OK: boton_next.bmp")
    }

    ; Verificar imágenes post-victoria
    if !FileExist(IMG_NUEVA_BATALLA) {
        Log("AVISO: Falta imagen -> pantalla_nueva_batalla.bmp")
        faltantes++
    } else {
        Log("OK: pantalla_nueva_batalla.bmp")
    }
    if !FileExist(IMG_OK) {
        Log("AVISO: Falta imagen -> boton_ok.bmp")
        faltantes++
    } else {
        Log("OK: boton_ok.bmp")
    }

    ; Verificar imagen post-derrota (botón X)
    if !FileExist(IMG_EQUIS) {
        Log("AVISO: Falta imagen -> boton_equis.bmp")
        faltantes++
    } else {
        Log("OK: boton_equis.bmp")
    }

    ; Verificar imágenes de rotación de batallas
    Loop, %TotalBatallas% {
        rutaBatalla := BatallaImagenes[A_Index]
        nombreBatalla := BatallaNombres[A_Index]
        if !FileExist(rutaBatalla) {
            Log("AVISO: Falta imagen batalla " . A_Index . " -> " . nombreBatalla)
            faltantes++
        } else {
            Log("OK: Batalla " . A_Index . " -> " . nombreBatalla)
        }
    }

    if (faltantes > 0)
        Log("Faltan " . faltantes . " imágenes en: " . CarpetaImagenes)
    else
        Log("Todas las imágenes encontradas correctamente")
}

; ============================================================================
; FUNCIÓN: Detectar ventana haciendo clic en ella
; ============================================================================
DetectarVentana:
    Log(">>> Haz clic en la ventana del juego dentro de 5 segundos...")
    MsgBox, 64, Detectar Ventana, Después de cerrar este mensaje tienes 5 segundos para hacer clic en la ventana del juego., 5

    Sleep, 5000

    ; Obtener ventana bajo el cursor
    MouseGetPos,,, hwndBajoCursor
    WinGetTitle, tituloDetectado, ahk_id %hwndBajoCursor%

    if (tituloDetectado = "" || tituloDetectado = "Game Bot - AutoHotkey v1.1") {
        Log("ERROR: No se detecto una ventana valida")
        MsgBox, 16, Error, No se detectó una ventana válida.`nAsegúrate de hacer clic en la ventana del juego.
        return
    }

    VentanaObjetivo := tituloDetectado
    GuiControl, Main:, EditVentana, %VentanaObjetivo%
    Log("Ventana detectada: " . VentanaObjetivo)
    MsgBox, 64, Ventana Detectada, Ventana seleccionada:`n%VentanaObjetivo%
return

; ============================================================================
; FUNCIÓN: Listar todas las ventanas abiertas para elegir una
; ============================================================================
ListarVentanas:
    Log("Listando ventanas abiertas...")

    Gui, Lista:Destroy
    Gui, Lista:Font, s9, Segoe UI
    Gui, Lista:Add, Text,, Selecciona la ventana del juego:
    Gui, Lista:Add, ListBox, w400 h300 vListaVentanas,

    lista := ""
    WinGet, ids, List
    Loop, %ids% {
        id := ids%A_Index%
        WinGetTitle, titulo, ahk_id %id%
        if (titulo != "" && titulo != "Game Bot - AutoHotkey v1.1" && titulo != "Program Manager") {
            if (lista != "")
                lista .= "|"
            lista .= titulo
        }
    }

    GuiControl, Lista:, ListaVentanas, |%lista%
    Gui, Lista:Add, Button, w400 h30 gSeleccionarVentanaLista, SELECCIONAR ESTA VENTANA
    Gui, Lista:Show,, Seleccionar Ventana
    Log("Se encontraron ventanas disponibles")
return

SeleccionarVentanaLista:
    Gui, Lista:Submit
    if (ListaVentanas = "") {
        MsgBox, 16, Error, No seleccionaste ninguna ventana.
        return
    }
    VentanaObjetivo := ListaVentanas
    GuiControl, Main:, EditVentana, %VentanaObjetivo%
    Log("Ventana seleccionada de la lista: " . VentanaObjetivo)
    MsgBox, 64, Ventana Seleccionada, Ventana seleccionada:`n%VentanaObjetivo%
return

; ============================================================================
; FUNCIÓN: Escribir el título de la ventana manualmente
; ============================================================================
EscribirVentana:
    InputBox, tituloManual, Escribir Título de Ventana, Escribe el título exacto de la ventana del juego:,, 400, 150
    if (ErrorLevel) {
        Log("Escritura manual cancelada")
        return
    }
    if (tituloManual = "") {
        MsgBox, 16, Error, El título no puede estar vacío.
        return
    }
    VentanaObjetivo := tituloManual
    GuiControl, Main:, EditVentana, %VentanaObjetivo%
    Log("Ventana escrita manualmente: " . VentanaObjetivo)
return

; ============================================================================
; FUNCIÓN: Verificar que la ventana exista y sea accesible
; ============================================================================
VerificarVentana:
    if (VentanaObjetivo = "" || VentanaObjetivo = "(ninguna seleccionada)") {
        MsgBox, 16, Error, Primero selecciona una ventana.
        return
    }

    ; Verificar si existe
    IfWinExist, %VentanaObjetivo%
    {
        WinGetPos, wx, wy, ww, wh, %VentanaObjetivo%
        WinGet, pid, PID, %VentanaObjetivo%
        Log("VENTANA OK: '" . VentanaObjetivo . "' [PID:" . pid . "] Pos:" . wx . "," . wy . " Tamaño:" . ww . "x" . wh)
        MsgBox, 64, Ventana Verificada, La ventana existe y es accesible.`n`nTítulo: %VentanaObjetivo%`nPID: %pid%`nPosición: %wx%`, %wy%`nTamaño: %ww% x %wh%
    }
    else
    {
        Log("ERROR: La ventana '" . VentanaObjetivo . "' NO existe o no se encuentra")
        MsgBox, 16, Error, La ventana no se encontró.`nAsegúrate de que el juego esté abierto y el título sea exacto.
    }
return

; ============================================================================
; HOTKEYS GLOBALES
; ============================================================================
F12::
    if (!BotActivo)
        GoSub, IniciarBot
    else
        GoSub, PausarBot
return

F11::
    GoSub, DetenerBot
return

F10::
    Reload
return

; ============================================================================
; CONTROLES DEL BOT
; ============================================================================
IniciarBot:
    ; Leer configuración de la GUI
    GuiControlGet, EditVariacion, Main:
    GuiControlGet, EditIntervalo, Main:
    GuiControlGet, EditReintentos, Main:
    GuiControlGet, ChkDebug, Main:

    Variacion := EditVariacion
    IntervaloLoop := RegExReplace(EditIntervalo, ",", "") + 0
    MaxReintentos := EditReintentos
    ModoDebug := ChkDebug

    ; Leer configuración de scroll
    GuiControlGet, ChkScroll, Main:
    GuiControlGet, EditScrollX, Main:
    GuiControlGet, EditScrollY, Main:
    GuiControlGet, EditScrollCant, Main:
    GuiControlGet, EditScrollDelay, Main:
    ScrollActivo := ChkScroll
    ScrollRelX := RegExReplace(EditScrollX, ",", "") + 0
    ScrollRelY := RegExReplace(EditScrollY, ",", "") + 0
    ScrollCantidad := EditScrollCant
    ScrollDelay := RegExReplace(EditScrollDelay, ",", "") + 0

    ; Leer paso de scroll
    GuiControlGet, DDLScrollPaso, Main:
    ScrollEnPaso := 0
    Loop, 3 {
        if InStr(DDLScrollPaso, "Paso " . A_Index) {
            ScrollEnPaso := A_Index
            break
        }
    }

    ; Validar ventana
    if (VentanaObjetivo = "" || VentanaObjetivo = "(ninguna seleccionada)") {
        MsgBox, 16, Error, Primero debes seleccionar la ventana del juego.
        Log("ERROR: No hay ventana seleccionada")
        return
    }

    IfWinNotExist, %VentanaObjetivo%
    {
        MsgBox, 16, Error, La ventana '%VentanaObjetivo%' no existe.`nAbre el juego primero.
        Log("ERROR: Ventana no encontrada al iniciar")
        return
    }

    ; Auto-ajustar ventana si la opción está activa
    GuiControlGet, ChkAutoAjustar, Main:
    AutoAjustar := ChkAutoAjustar
    if (AutoAjustar) {
        GuiControlGet, EditVentanaAncho, Main:
        GuiControlGet, EditVentanaAlto, Main:
        VentanaAncho := RegExReplace(EditVentanaAncho, ",", "") + 0
        VentanaAlto := RegExReplace(EditVentanaAlto, ",", "") + 0

        if (VentanaAncho >= 100 && VentanaAlto >= 100) {
            WinGetPos, wx, wy, wwActual, whActual, %VentanaObjetivo%
            if (wwActual != VentanaAncho || whActual != VentanaAlto) {
                Log("Auto-ajustando ventana de " . wwActual . "x" . whActual . " a " . VentanaAncho . "x" . VentanaAlto)
                WinMove, %VentanaObjetivo%,, wx, wy, %VentanaAncho%, %VentanaAlto%
                Sleep, 500
                WinGetPos,,, wwNuevo, whNuevo, %VentanaObjetivo%
                if (wwNuevo = VentanaAncho && whNuevo = VentanaAlto)
                    Log("Ventana auto-ajustada correctamente a " . wwNuevo . "x" . whNuevo)
                else
                    Log("AVISO: Auto-ajuste parcial. Resultado: " . wwNuevo . "x" . whNuevo)
            } else {
                Log("Ventana ya tiene el tamano correcto: " . VentanaAncho . "x" . VentanaAlto)
            }
        }
    }

    ; Leer paso inicial seleccionado
    GuiControlGet, DDLPasoInicio, Main:
    PasoInicioSeleccionado := 1
    Loop, 8 {
        if InStr(DDLPasoInicio, A_Index . ":") {
            PasoInicioSeleccionado := A_Index
            break
        }
    }

    BotActivo := true
    BotPausado := false
    PasoActual := PasoInicioSeleccionado
    EstadoActual := "Paso " . PasoActual
    ContadorCiclos := 0
    ContadorAtaques := 0
    ContadorErrores := 0
    ErroresConsecutivos := 0
    ResultadoIntentos := 0
    TapIntentos := 0
    RepeticionActual := 1
    Log("=== BOT INICIADO ===")
    Log("Ventana: " . VentanaObjetivo)
    Log("Iniciando en paso " . PasoActual . ": " . PasoNombres[PasoActual])
    Log("Variación: " . Variacion . " | Intervalo: " . IntervaloLoop . "ms | Reintentos: " . MaxReintentos)
    if (ScrollActivo) {
        pasoNombre := (ScrollEnPaso = 0) ? "Todos los ciclos" : "Paso " . ScrollEnPaso
        Log("Scroll activo en (" . ScrollRelX . ", " . ScrollRelY . ") x" . ScrollCantidad . " clicks | " . pasoNombre)
    } else
        Log("Scroll desactivado")
    ActualizarEstado()

    ; Iniciar el loop principal
    SetTimer, LoopPrincipal, %IntervaloLoop%
return

PausarBot:
    if (!BotActivo)
        return

    BotPausado := !BotPausado
    if (BotPausado) {
        SetTimer, LoopPrincipal, Off
        Log("=== BOT PAUSADO === (F12 para reanudar)")
    } else {
        SetTimer, LoopPrincipal, %IntervaloLoop%
        Log("=== BOT REANUDADO ===")
    }
    ActualizarEstado()
return

DetenerBot:
    BotActivo := false
    BotPausado := false
    EstadoActual := "IDLE"
    ResultadoIntentos := 0
    TapIntentos := 0
    SetTimer, LoopPrincipal, Off
    Log("=== BOT DETENIDO ===")
    ActualizarEstado()
return

; ============================================================================
; LOOP PRINCIPAL DEL BOT
; ============================================================================
LoopPrincipal:
    Critical  ; Prevenir interrupciones durante la ejecución del ciclo

    if (!BotActivo || BotPausado)
        return

    ContadorCiclos++
    ActualizarEstado()

    ; Verificar que la ventana siga abierta
    IfWinNotExist, %VentanaObjetivo%
    {
        Log("ERROR: La ventana del juego se cerró. Deteniendo bot.")
        GoSub, DetenerBot
        MsgBox, 16, Error, La ventana del juego se cerró.`nEl bot se ha detenido.
        return
    }

    ; Obtener posición y tamaño de la ventana
    WinGetPos, WinX, WinY, WinW, WinH, %VentanaObjetivo%

    if (WinW = 0 || WinH = 0) {
        Log("AVISO: Ventana minimizada o sin tamaño. Esperando...")
        return
    }

    ; ================================================================
    ; FLUJO SECUENCIAL - Buscar y clicar el botón del paso actual
    ; ================================================================

    ; Protección de límites: si PasoActual se sale de rango, reiniciar
    if (PasoActual < 1 || PasoActual > TotalPasos) {
        Log("AVISO: PasoActual fuera de rango (" . PasoActual . "). Reiniciando a paso 1.")
        PasoActual := 1
        ErroresConsecutivos := 0
    }

    ; Paso 1 dinámico: siempre usa la batalla actual de la rotación
    PasoImagenes[1] := BatallaImagenes[BatallaActual]
    PasoNombres[1]  := BatallaNombres[BatallaActual]

    nombreActual := PasoNombres[PasoActual]
    EstadoActual := "Paso " . PasoActual . "/" . TotalPasos . ": " . nombreActual
    ActualizarEstado()

    ; ================================================================
    ; PASO 4 ESPECIAL: Escanear victoria O derrota
    ; 15 intentos con 10 segundos entre cada uno (NO-BLOQUEANTE)
    ; Cada tick del timer hace UN solo intento y retorna
    ; ================================================================
    if (PasoActual = 4) {
        ResultadoIntentos++

        ; Primera vez: cambiar timer a 3s y logear
        if (ResultadoIntentos = 1) {
            Log("Paso 4: Buscando resultado de batalla (40 intentos, 3s entre cada uno)...")
            SetTimer, LoopPrincipal, 3000
        }

        EstadoActual := "Paso 4: Esperando resultado... (" . ResultadoIntentos . "/40)"
        ActualizarEstado()

        ; Buscar DERROTA (solo detectar, NO hacer clic)
        if (BuscarImagenEnVentana(IMG_DERROTA, foundX, foundY)) {
            Log("DERROTA detectada en intento " . ResultadoIntentos . "/40")
            ErroresConsecutivos := 0
            ResultadoIntentos := 0
            TapIntentos := 0
            RutaPostNext := 9
            PasoActual := 5
            Log(">>> Ruta derrota: avanzando a paso 5 (Tap hasta Next -> CerrarX -> SeleccionBatalla)")
            SetTimer, LoopPrincipal, %IntervaloLoop%
            ActualizarEstado()
            return
        }

        ; Buscar VICTORIA
        if (BuscarImagenEnVentana(IMG_VICTORIA, foundX, foundY)) {
            Log("VICTORIA detectada en intento " . ResultadoIntentos . "/40")
            HacerClicEnVentana(foundX, foundY)
            ErroresConsecutivos := 0
            ContadorAtaques++
            ResultadoIntentos := 0
            TapIntentos := 0
            RutaPostNext := 6
            PasoActual := 5
            Log(">>> Ruta victoria: avanzando a paso 5 (Tap hasta Next -> NuevaBatalla)")
            SetTimer, LoopPrincipal, %IntervaloLoop%
            ActualizarEstado()
            return
        }

        ; Si se agotaron los 40 intentos sin resultado (120s)
        if (ResultadoIntentos >= 40) {
            Log("RECUPERACION: Sin resultado tras 40 intentos (120s). Reiniciando desde paso 1...")
            PasoActual := 1
            ErroresConsecutivos := 0
            ResultadoIntentos := 0
            SetTimer, LoopPrincipal, %IntervaloLoop%
        }

        ActualizarEstado()
        return
    }

    ; ================================================================
    ; PASO 5 ESPECIAL: Tap dinámico hasta que aparezca Next
    ; Busca Next primero; si no lo encuentra, busca Tap y lo clica
    ; Funciona para victoria y derrota (RutaPostNext define el destino)
    ; ================================================================
    if (PasoActual = 5) {
        TapIntentos++

        if (TapIntentos = 1)
            Log("Paso 5: Tap hasta Next (destino post-next: paso " . RutaPostNext . ")...")

        EstadoActual := "Paso 5: Tap hasta Next... (" . TapIntentos . "/" . MaxTapIntentos . ")"
        ActualizarEstado()

        ; Primero buscar NEXT -> si aparece, clic y terminar
        if (BuscarImagenEnVentana(IMG_NEXT, foundX, foundY)) {
            Log("Next encontrado en intento " . TapIntentos . ". Haciendo clic...")
            HacerClicEnVentana(foundX, foundY)
            Sleep, 2500
            ErroresConsecutivos := 0
            TapIntentos := 0
            PasoActual := RutaPostNext
            Log(">>> Ciclo completado. Volviendo a paso " . RutaPostNext . ": " . PasoNombres[RutaPostNext])
            ActualizarEstado()
            return
        }

        ; Si no hay Next, buscar TAP -> si aparece, clic
        if (BuscarImagenEnVentana(IMG_TAP, foundX, foundY)) {
            Log("Tap encontrado en intento " . TapIntentos . ". Haciendo clic...")
            HacerClicEnVentana(foundX, foundY)
            Sleep, 2500
            ActualizarEstado()
            return
        }

        ; Ni tap ni next encontrados, esperar al siguiente tick
        if (Mod(TapIntentos, 10) = 0)
            Log("Paso 5: Ni Tap ni Next encontrados (" . TapIntentos . " intentos)")

        ; Límite de intentos
        if (TapIntentos >= MaxTapIntentos) {
            Log("RECUPERACION: Sin Tap ni Next tras " . MaxTapIntentos . " intentos. Reiniciando desde paso 1...")
            TapIntentos := 0
            ErroresConsecutivos := 0
            PasoActual := 1
        }

        ActualizarEstado()
        return
    }

    ; ================================================================
    ; PASO 6 ESPECIAL: Detectar pantalla "nueva batalla desbloqueada"
    ; Si aparece -> paso 7 (OK). Si no tras N intentos -> paso 8 (CharizardEX)
    ; ================================================================
    if (PasoActual = 6) {
        NuevaBatallaIntentos++

        if (NuevaBatallaIntentos = 1)
            Log("Paso 6: Buscando pantalla nueva batalla desbloqueada...")

        EstadoActual := "Paso 6: NuevaBatalla... (" . NuevaBatallaIntentos . "/" . MaxNuevaBatallaIntentos . ")"
        ActualizarEstado()

        if (BuscarImagenEnVentana(IMG_NUEVA_BATALLA, foundX, foundY)) {
            Log("Nueva batalla desbloqueada detectada en intento " . NuevaBatallaIntentos)
            NuevaBatallaIntentos := 0
            ErroresConsecutivos := 0
            PasoActual := 7
            Log(">>> Avanzando a paso 7: OK")
            ActualizarEstado()
            return
        }

        ; Si no aparece tras MaxNuevaBatallaIntentos, saltar directamente a CharizardEX
        if (NuevaBatallaIntentos >= MaxNuevaBatallaIntentos) {
            Log("Nueva batalla no encontrada tras " . MaxNuevaBatallaIntentos . " intentos. Saltando a SeleccionBatalla...")
            NuevaBatallaIntentos := 0
            ErroresConsecutivos := 0
            PasoActual := 8
            Log(">>> Saltando a paso 8: SeleccionBatalla")
            ActualizarEstado()
        }
        return
    }

    ; ================================================================
    ; PASO 8 ESPECIAL: Selección de batalla (rotación)
    ; Busca la imagen de la batalla actual de la lista de rotación
    ; Tras clic, avanza BatallaActual y vuelve a paso 2 (Auto)
    ; ================================================================
    if (PasoActual = 8) {
        imgBatalla := BatallaImagenes[BatallaActual]
        nombreBatalla := BatallaNombres[BatallaActual]

        if !FileExist(imgBatalla) {
            Log("ERROR: Falta imagen para batalla " . BatallaActual . " (" . nombreBatalla . "): " . imgBatalla)
            ContadorErrores++
            return
        }

        repInfo := ""
        if (BatallaRepeticiones[BatallaActual] > 1)
            repInfo := " [rep " . RepeticionActual . "/" . BatallaRepeticiones[BatallaActual] . "]"
        EstadoActual := "Paso 8: " . nombreBatalla . " (" . BatallaActual . "/" . TotalBatallas . ")" . repInfo
        ActualizarEstado()

        imagenEncontrada := false
        if (ScrollActivo && (ScrollEnPaso = 0 || ScrollEnPaso = PasoActual)) {
            if (BuscarImagenEnVentana(imgBatalla, foundX, foundY)) {
                imagenEncontrada := true
            } else {
                Loop, %ScrollCantidad% {
                    HacerScrollEnVentana(ScrollRelX, ScrollRelY, 1)
                    Sleep, %ScrollDelay%
                    if (BuscarImagenEnVentana(imgBatalla, foundX, foundY)) {
                        imagenEncontrada := true
                        break
                    }
                }
            }
        } else {
            if (BuscarImagenEnVentana(imgBatalla, foundX, foundY))
                imagenEncontrada := true
        }

        if (imagenEncontrada) {
            Log("Paso 8: '" . nombreBatalla . "' encontrado. Haciendo clic...")
            HacerClicEnVentana(foundX, foundY)
            ContadorAtaques++
            ErroresConsecutivos := 0
            Sleep, 2500

            ; Verificar repeticiones antes de avanzar a siguiente batalla
            if (RepeticionActual >= BatallaRepeticiones[BatallaActual]) {
                ; Todas las repeticiones completadas, avanzar
                RepeticionActual := 1
                BatallaActual := BatallaActual + 1
                if (BatallaActual > TotalBatallas)
                    BatallaActual := 1
                Log(">>> Próxima batalla: " . BatallaNombres[BatallaActual])
            } else {
                ; Más repeticiones necesarias de la misma batalla
                RepeticionActual := RepeticionActual + 1
                Log(">>> Repitiendo " . nombreBatalla . " (" . RepeticionActual . "/" . BatallaRepeticiones[BatallaActual] . ")")
            }

            ; Volver al bucle: paso 2 (Auto)
            PasoActual := 2
            Log(">>> Volviendo a paso 2: Auto")
            ActualizarEstado()
            return
        }

        ; Si no encuentra, contar error
        ErroresConsecutivos++
        ContadorErrores++
        if (Mod(ErroresConsecutivos, 10) = 0)
            Log("Paso 8: '" . nombreBatalla . "' no encontrado (" . ErroresConsecutivos . " intentos)")
        if (ErroresConsecutivos >= MaxErroresConsecutivos) {
            Log("RECUPERACION: Atascado en paso 8. Reiniciando desde paso 1...")
            PasoActual := 1
            ErroresConsecutivos := 0
        }
        ActualizarEstado()
        return
    }

    ; ================================================================
    ; PASO 9 ESPECIAL: Cerrar X después de derrota
    ; Busca el botón X (equis) y lo pulsa, luego vuelve a paso 1
    ; ================================================================
    if (PasoActual = 9) {
        EstadoActual := "Paso 9: Buscando botón X para cerrar..."
        ActualizarEstado()

        if (BuscarImagenEnVentana(IMG_EQUIS, foundX, foundY)) {
            Log("Paso 9: Botón X encontrado. Haciendo clic...")
            HacerClicEnVentana(foundX, foundY)
            Sleep, 2500
            ErroresConsecutivos := 0
            PasoActual := 1
            Log(">>> Cerrado. Volviendo a paso 1: SeleccionBatalla")
            ActualizarEstado()
            return
        }

        ; Si no se encuentra, contar error
        ErroresConsecutivos++
        ContadorErrores++
        if (Mod(ErroresConsecutivos, 10) = 0)
            Log("Paso 9: Botón X no encontrado (" . ErroresConsecutivos . " intentos)")
        if (ErroresConsecutivos >= MaxErroresConsecutivos) {
            Log("RECUPERACION: Botón X no encontrado tras " . MaxErroresConsecutivos . " intentos. Volviendo a paso 1...")
            PasoActual := 1
            ErroresConsecutivos := 0
        }
        ActualizarEstado()
        return
    }

    ; ================================================================
    ; PASOS NORMALES (1-3, 7): Buscar imagen y clicar
    ; ================================================================
    imgActual := PasoImagenes[PasoActual]

    ; Verificar que el archivo de imagen exista
    if !FileExist(imgActual) {
        Log("ERROR: Falta imagen para paso " . PasoActual . " (" . nombreActual . "): " . imgActual)
        ContadorErrores++
        return
    }

    ; Scroll inteligente: buscar imagen ANTES y DESPUÉS de cada scroll individual
    ; (solo aplica a pasos normales donde se configura scroll)
    imagenEncontrada := false
    if (ScrollActivo && (ScrollEnPaso = 0 || ScrollEnPaso = PasoActual)) {
        ; Buscar ANTES del primer scroll (por si ya está visible)
        if (BuscarImagenEnVentana(imgActual, foundX, foundY)) {
            imagenEncontrada := true
        } else {
            ; Hacer scroll de uno en uno, verificando después de cada uno
            Loop, %ScrollCantidad% {
                HacerScrollEnVentana(ScrollRelX, ScrollRelY, 1)
                Sleep, %ScrollDelay%
                if (BuscarImagenEnVentana(imgActual, foundX, foundY)) {
                    imagenEncontrada := true
                    break
                }
            }
        }
    } else {
        ; Sin scroll: buscar directamente
        if (BuscarImagenEnVentana(imgActual, foundX, foundY))
            imagenEncontrada := true
    }

    ; Procesar resultado de la búsqueda
    if (imagenEncontrada) {
        Log("Paso " . PasoActual . ": '" . nombreActual . "' encontrado en (" . foundX . ", " . foundY . ")")
        HacerClicEnVentana(foundX, foundY)
        ContadorAtaques++
        ErroresConsecutivos := 0
        Sleep, 2500

        ; Avanzar al siguiente paso
        PasoActual := PasoActual + 1
        Log(">>> Avanzando a paso " . PasoActual . ": " . PasoNombres[PasoActual])
    } else {
        ErroresConsecutivos++
        ContadorErrores++

        ; Logear cada 10 intentos fallidos para no saturar
        if (Mod(ErroresConsecutivos, 10) = 0) {
            Log("Paso " . PasoActual . ": '" . nombreActual . "' no encontrado (" . ErroresConsecutivos . " intentos consecutivos)")
        }

        ; ANTI-ATASCO: si se superó el límite de errores consecutivos, reiniciar secuencia
        if (ErroresConsecutivos >= MaxErroresConsecutivos) {
            Log("RECUPERACION: Atascado en paso " . PasoActual . " (" . nombreActual . ") por " . ErroresConsecutivos . " ciclos. Reiniciando desde paso 1...")
            PasoActual := 1
            ErroresConsecutivos := 0
            Log(">>> Reiniciado a paso 1: " . PasoNombres[1])
        }
    }

    ActualizarEstado()
return

; ============================================================================
; FUNCIÓN: Obtener dimensiones de una imagen usando GDI (LoadPicture)
; Funciona con cualquier formato: BMP, PNG, JPG, GIF, etc.
; ============================================================================
ObtenerDimensionesImagen(rutaImagen, ByRef imgW, ByRef imgH) {
    imgW := 0
    imgH := 0

    hBitmap := LoadPicture(rutaImagen)
    if (!hBitmap)
        return

    VarSetCapacity(bm, 32, 0)
    DllCall("GetObject", "Ptr", hBitmap, "Int", 32, "Ptr", &bm)
    imgW := NumGet(bm, 4, "Int")
    imgH := NumGet(bm, 8, "Int")
    DllCall("DeleteObject", "Ptr", hBitmap)
}

; ============================================================================
; FUNCIÓN: Buscar una imagen dentro de la ventana del juego
; Retorna true si la encontró, false si no
; foundX y foundY contienen las coordenadas del CENTRO de la imagen (pantalla)
; ============================================================================
BuscarImagenEnVentana(ByRef rutaImagen, ByRef foundX, ByRef foundY) {
    global VentanaObjetivo, Variacion

    ; Verificar que el archivo de imagen existe
    if !FileExist(rutaImagen) {
        return false
    }

    ; Obtener posición de la ventana en la pantalla
    WinGetPos, wx, wy, ww, wh, %VentanaObjetivo%

    if (ww = 0 || wh = 0)
        return false

    ; Calcular coordenadas de búsqueda (área de la ventana)
    x1 := wx
    y1 := wy
    x2 := wx + ww
    y2 := wy + wh

    ; Buscar la imagen con tolerancia alta
    ImageSearch, foundX, foundY, %x1%, %y1%, %x2%, %y2%, *%Variacion% %rutaImagen%

    if (ErrorLevel = 0) {
        ; Ajustar coordenadas al centro de la imagen encontrada
        ObtenerDimensionesImagen(rutaImagen, imgW, imgH)
        if (imgW > 0 && imgH > 0) {
            foundX := foundX + (imgW // 2)
            foundY := foundY + (imgH // 2)
        }
        return true    ; Imagen encontrada
    }

    return false       ; No encontrada o error
}

; ============================================================================
; FUNCIÓN: Hacer clic virtual en la ventana (sin mover el mouse real)
; Las coordenadas recibidas son de pantalla; se convierten a coordenadas
; relativas a la ventana para ControlClick
; ============================================================================
HacerClicEnVentana(screenX, screenY) {
    global VentanaObjetivo

    ; Obtener posición de la ventana
    WinGetPos, wx, wy,,, %VentanaObjetivo%

    ; Convertir coordenadas de pantalla a coordenadas relativas a la ventana
    relX := screenX - wx
    relY := screenY - wy

    ; Hacer clic virtual usando ControlClick (no mueve el mouse real)
    ControlClick, x%relX% y%relY%, %VentanaObjetivo%,, Left, 1, NA

    if (ErrorLevel) {
        Log("AVISO: ControlClick falló en (" . relX . ", " . relY . "). Intentando método alternativo...")
        ; Método alternativo: PostMessage para simular clic
        lParam := (relY << 16) | (relX & 0xFFFF)
        PostMessage, 0x201, 0x0001, %lParam%,, %VentanaObjetivo%  ; WM_LBUTTONDOWN
        Sleep, 50
        PostMessage, 0x202, 0x0000, %lParam%,, %VentanaObjetivo%  ; WM_LBUTTONUP
        Log("Clic alternativo (PostMessage) enviado en (" . relX . ", " . relY . ")")
    } else {
        Log("Clic enviado en (" . relX . ", " . relY . ") de la ventana")
    }
}

; ============================================================================
; FUNCIÓN: Hacer scroll en la ventana en coordenadas relativas
; Usa WM_MOUSEWHEEL (0x20A) via PostMessage para funcionar en segundo plano
; Las coordenadas se convierten a pantalla en cada llamada para que funcione
; aunque la ventana se haya movido
; ============================================================================
HacerScrollEnVentana(relX, relY, cantidad) {
    global VentanaObjetivo

    ; Obtener posición actual de la ventana para convertir a coordenadas de pantalla
    WinGetPos, wx, wy,,, %VentanaObjetivo%
    screenX := relX + wx
    screenY := relY + wy

    ; WM_MOUSEWHEEL = 0x20A
    ; wParam alto: delta (-120 por click hacia abajo)
    ; lParam: posición del cursor en coordenadas de pantalla
    wheelDelta := -120 * cantidad
    wParam := (wheelDelta << 16) & 0xFFFFFFFF
    lParam := ((screenY & 0xFFFF) << 16) | (screenX & 0xFFFF)

    PostMessage, 0x20A, %wParam%, %lParam%,, %VentanaObjetivo%

    if (ErrorLevel)
        Log("AVISO: Scroll falló en (" . relX . ", " . relY . ")")
}

; ============================================================================
; LABEL: Seleccionar punto de scroll haciendo clic en la ventana del juego
; ============================================================================
SeleccionarPuntoScroll:
    if (VentanaObjetivo = "" || VentanaObjetivo = "(ninguna seleccionada)") {
        MsgBox, 16, Error, Primero selecciona una ventana del juego.
        return
    }
    IfWinNotExist, %VentanaObjetivo%
    {
        MsgBox, 16, Error, La ventana '%VentanaObjetivo%' no existe.
        return
    }

    Log(">>> Haz clic en el punto de scroll dentro de 5 segundos...")
    MsgBox, 64, Seleccionar Punto Scroll, Después de cerrar este mensaje tienes 5 segundos para hacer clic en el punto de la ventana del juego donde quieres hacer scroll., 5

    Sleep, 5000

    ; Capturar posición del mouse
    MouseGetPos, mouseX, mouseY, hwndBajo
    WinGetTitle, tituloBajo, ahk_id %hwndBajo%

    ; Verificar que el clic fue en la ventana correcta
    if (tituloBajo != VentanaObjetivo) {
        Log("ERROR: Hiciste clic fuera de la ventana objetivo")
        MsgBox, 16, Error, Hiciste clic fuera de la ventana del juego.`nIntenta de nuevo.
        return
    }

    ; Obtener posición de la ventana para calcular coordenadas relativas
    WinGetPos, wx, wy,,, %VentanaObjetivo%
    nuevoX := mouseX - wx
    nuevoY := mouseY - wy

    ; Actualizar campos en la GUI
    GuiControl, Main:, EditScrollX, %nuevoX%
    GuiControl, Main:, EditScrollY, %nuevoY%

    ; Actualizar variables globales
    ScrollRelX := nuevoX
    ScrollRelY := nuevoY

    Log("Punto de scroll seleccionado: (" . nuevoX . ", " . nuevoY . ")")
    MsgBox, 64, Punto Seleccionado, Punto de scroll establecido en:`nX: %nuevoX%  Y: %nuevoY%`n`n(Coordenadas relativas a la ventana)
return

; ============================================================================
; LABEL: Probar scroll en el punto configurado
; ============================================================================
ProbarScroll:
    if (VentanaObjetivo = "" || VentanaObjetivo = "(ninguna seleccionada)") {
        MsgBox, 16, Error, Primero selecciona una ventana del juego.
        return
    }
    IfWinNotExist, %VentanaObjetivo%
    {
        MsgBox, 16, Error, La ventana '%VentanaObjetivo%' no existe.
        return
    }

    ; Leer valores actuales de la GUI
    GuiControlGet, tmpScrollX, Main:, EditScrollX
    GuiControlGet, tmpScrollY, Main:, EditScrollY
    GuiControlGet, tmpScrollCant, Main:, EditScrollCant
    tmpScrollX := RegExReplace(tmpScrollX, ",", "") + 0
    tmpScrollY := RegExReplace(tmpScrollY, ",", "") + 0

    Log("Probando scroll en (" . tmpScrollX . ", " . tmpScrollY . ") x" . tmpScrollCant . " clicks...")
    HacerScrollEnVentana(tmpScrollX, tmpScrollY, tmpScrollCant)
    Log("Scroll de prueba enviado")
return

; ============================================================================
; LABEL: Ajustar el tamaño de la ventana del juego
; ============================================================================
AjustarVentana:
    if (VentanaObjetivo = "" || VentanaObjetivo = "(ninguna seleccionada)") {
        MsgBox, 16, Error, Primero selecciona una ventana del juego.
        Log("ERROR: No hay ventana seleccionada para ajustar")
        return
    }

    IfWinNotExist, %VentanaObjetivo%
    {
        MsgBox, 16, Error, La ventana '%VentanaObjetivo%' no existe.`nAbre el juego primero.
        Log("ERROR: Ventana no encontrada al intentar ajustar")
        return
    }

    GuiControlGet, EditVentanaAncho, Main:
    GuiControlGet, EditVentanaAlto, Main:
    VentanaAncho := RegExReplace(EditVentanaAncho, ",", "") + 0
    VentanaAlto := RegExReplace(EditVentanaAlto, ",", "") + 0

    if (VentanaAncho < 100 || VentanaAlto < 100) {
        MsgBox, 16, Error, Las dimensiones deben ser al menos 100x100 pixeles.
        Log("ERROR: Dimensiones invalidas: " . VentanaAncho . "x" . VentanaAlto)
        return
    }

    WinGetPos, wx, wy, wwActual, whActual, %VentanaObjetivo%
    Log("Tamano actual de ventana: " . wwActual . "x" . whActual)

    if (wwActual = VentanaAncho && whActual = VentanaAlto) {
        Log("La ventana ya esta en " . VentanaAncho . "x" . VentanaAlto)
        MsgBox, 64, Ajuste de Ventana, La ventana ya tiene el tamano correcto:`n%VentanaAncho% x %VentanaAlto%
        return
    }

    WinMove, %VentanaObjetivo%,, wx, wy, %VentanaAncho%, %VentanaAlto%
    Sleep, 200
    WinGetPos,,, wwNuevo, whNuevo, %VentanaObjetivo%

    if (wwNuevo = VentanaAncho && whNuevo = VentanaAlto) {
        Log("Ventana ajustada exitosamente: " . wwNuevo . "x" . whNuevo)
        MsgBox, 64, Ajuste de Ventana, Ventana redimensionada correctamente:`n%wwNuevo% x %whNuevo%
    } else {
        Log("AVISO: Tamano resultante (" . wwNuevo . "x" . whNuevo . ") difiere del objetivo (" . VentanaAncho . "x" . VentanaAlto . ")")
        MsgBox, 48, Aviso, El tamano resultante difiere del objetivo.`n`nObjetivo: %VentanaAncho% x %VentanaAlto%`nResultado: %wwNuevo% x %whNuevo%`n`nEl juego puede tener restricciones de tamano.
    }
return

; ============================================================================
; LABEL: Consultar tamaño actual de la ventana
; ============================================================================
ConsultarTamano:
    if (VentanaObjetivo = "" || VentanaObjetivo = "(ninguna seleccionada)") {
        MsgBox, 16, Error, Primero selecciona una ventana del juego.
        return
    }

    IfWinNotExist, %VentanaObjetivo%
    {
        MsgBox, 16, Error, La ventana '%VentanaObjetivo%' no existe.
        return
    }

    WinGetPos, wx, wy, ww, wh, %VentanaObjetivo%
    Log("Tamano actual: " . ww . "x" . wh . " en posicion (" . wx . ", " . wy . ")")

    GuiControl, Main:, EditVentanaAncho, %ww%
    GuiControl, Main:, EditVentanaAlto, %wh%

    MsgBox, 64, Tamano Actual, Ventana: %VentanaObjetivo%`n`nTamano: %ww% x %wh%`nPosicion: %wx%`, %wy%`n`nLos campos se han actualizado con el tamano actual.
return

; ============================================================================
; EVENTOS DE LA GUI
; ============================================================================
MainGuiClose:
MainGuiEscape:
    MsgBox, 36, Cerrar Bot, ¿Seguro que quieres cerrar el Game Bot?
    IfMsgBox, Yes
    {
        SetTimer, LoopPrincipal, Off
        GuardarConfig()
        ExitApp
    }
return

ListaGuiClose:
ListaGuiEscape:
    Gui, Lista:Destroy
return
