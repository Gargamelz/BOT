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

; Ajuste de ventana (resolución objetivo para ImageSearch)
global VentanaAncho := 960              ; Ancho objetivo en píxeles
global VentanaAlto := 540               ; Alto objetivo en píxeles
global AutoAjustar := false             ; Ajustar automáticamente al iniciar el bot

; Pasos de automatización (secuencia de botones a buscar y clicar)
global TotalPasos := 11
global PasoActual := 1
global PasoImagenes := {}
global PasoNombres := {}
PasoImagenes[1]  := CarpetaImagenes . "\boton_battle.bmp"
PasoNombres[1]   := "Battle"
PasoImagenes[2]  := CarpetaImagenes . "\boton_solo.bmp"
PasoNombres[2]   := "Solo"
PasoImagenes[3]  := CarpetaImagenes . "\boton_setup.bmp"
PasoNombres[3]   := "Setup"
PasoImagenes[4]  := CarpetaImagenes . "\boton_expert.bmp"
PasoNombres[4]   := "Expert"
PasoImagenes[5]  := CarpetaImagenes . "\boton_nivel.bmp"
PasoNombres[5]   := "Nivel"
PasoImagenes[6]  := CarpetaImagenes . "\boton_auto.bmp"
PasoNombres[6]   := "Auto"
PasoImagenes[7]  := CarpetaImagenes . "\boton_iniciar.bmp"
PasoNombres[7]   := "Iniciar"
PasoImagenes[8]  := ""  ; Paso especial: escanea victoria/derrota
PasoNombres[8]   := "Resultado"
PasoImagenes[9]  := CarpetaImagenes . "\boton_tap.bmp"
PasoNombres[9]   := "Tap 1"
PasoImagenes[10] := CarpetaImagenes . "\boton_tap.bmp"
PasoNombres[10]  := "Tap 2"
PasoImagenes[11] := CarpetaImagenes . "\boton_next.bmp"
PasoNombres[11]  := "Next"

; Imágenes de resultado de batalla (usadas en paso 8)
global IMG_VICTORIA := CarpetaImagenes . "\pantalla_victoria.bmp"
global IMG_DERROTA  := CarpetaImagenes . "\pantalla_derrota.bmp"

; Scroll automático
global ScrollActivo := false
global ScrollRelX := 200                 ; Coordenada X relativa a la ventana
global ScrollRelY := 300                 ; Coordenada Y relativa a la ventana
global ScrollCantidad := 3               ; Clicks de scroll por ciclo
global ScrollDelay := 500                ; Milisegundos de pausa entre cada scroll individual
global ScrollEnPaso := 0                 ; 0=Todos, 1-7=Paso específico

; Contadores
global ContadorAtaques := 0
global ContadorCiclos := 0
global ContadorErrores := 0

; Anti-atasco: errores consecutivos en el mismo paso
global ErroresConsecutivos := 0          ; Errores seguidos en el paso actual
global MaxErroresConsecutivos := 30      ; Limite antes de intentar recuperación

; Paso 8: contador de intentos (máquina de estados, no-bloqueante)
global ResultadoIntentos := 0

; ============================================================================
; CREAR CARPETA DE IMÁGENES SI NO EXISTE
; ============================================================================
if !FileExist(CarpetaImagenes)
    FileCreateDir, %CarpetaImagenes%

; ============================================================================
; INTERFAZ GRÁFICA (GUI)
; ============================================================================
CrearGUI()
return

; ============================================================================
; FUNCIÓN: Crear la interfaz gráfica principal
; ============================================================================
CrearGUI() {
    global EditVentana, EditVariacion, EditIntervalo, EditReintentos, ChkDebug, TextoEstado, LogText
    global ChkScroll, EditScrollX, EditScrollY, EditScrollCant, EditScrollDelay, DDLScrollPaso
    global EditVentanaAncho, EditVentanaAlto, ChkAutoAjustar

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
    Gui, Main:Add, Edit, x130 y32 w220 h22 vEditVentana ReadOnly, (ninguna seleccionada)

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
    Gui, Main:Add, Edit, x70 y142 w60 h22 vEditVentanaAncho, 960
    Gui, Main:Add, Text, x140 y145, Alto:
    Gui, Main:Add, Edit, x175 y142 w60 h22 vEditVentanaAlto, 540
    Gui, Main:Font, s9 cWhite Normal
    Gui, Main:Add, Button, x250 y140 w105 h25 gAjustarVentana, Ajustar Ventana
    Gui, Main:Add, Button, x360 y140 w100 h25 gConsultarTamano, Ver Actual
    Gui, Main:Add, CheckBox, x25 y168 vChkAutoAjustar cWhite, Auto-ajustar al iniciar bot

    ; --- SECCIÓN: Configuración ---
    Gui, Main:Font, s10 cWhite Bold
    Gui, Main:Add, GroupBox, x10 y200 w460 h100, CONFIGURACIÓN

    Gui, Main:Font, s9 cSilver Normal
    Gui, Main:Add, Text, x25 y225, Variación (tolerancia):
    Gui, Main:Add, Edit, x170 y222 w50 h22 vEditVariacion, 50
    Gui, Main:Add, UpDown, Range0-255, 50

    Gui, Main:Add, Text, x240 y225, Intervalo (ms):
    Gui, Main:Add, Edit, x360 y222 w80 h22 vEditIntervalo, 1000
    Gui, Main:Add, UpDown, Range100-10000, 1000

    Gui, Main:Add, Text, x25 y255, Max reintentos:
    Gui, Main:Add, Edit, x170 y252 w50 h22 vEditReintentos, 5
    Gui, Main:Add, UpDown, Range1-50, 5

    Gui, Main:Add, CheckBox, x240 y255 vChkDebug Checked cWhite, Modo Debug (logs visibles)

    ; --- SECCIÓN: Scroll Automático ---
    Gui, Main:Font, s10 cWhite Bold
    Gui, Main:Add, GroupBox, x10 y310 w460 h120, SCROLL AUTOMÁTICO

    Gui, Main:Font, s9 cSilver Normal
    Gui, Main:Add, CheckBox, x25 y335 vChkScroll cWhite, Activar scroll
    Gui, Main:Add, Text, x150 y336 cSilver, X (rel):
    Gui, Main:Add, Edit, x195 y333 w55 h22 vEditScrollX, 200
    Gui, Main:Add, Text, x260 y336 cSilver, Y (rel):
    Gui, Main:Add, Edit, x305 y333 w55 h22 vEditScrollY, 300
    Gui, Main:Add, Text, x370 y336 cSilver, Clicks:
    Gui, Main:Add, Edit, x415 y333 w45 h22 vEditScrollCant, 3
    Gui, Main:Add, UpDown, Range1-20, 3

    Gui, Main:Add, Text, x25 y363 cSilver, Scroll en paso:
    Gui, Main:Add, DropDownList, x120 y360 w195 vDDLScrollPaso Choose1, Todos los ciclos|Paso 1: Battle|Paso 2: Solo|Paso 3: Setup|Paso 4: Expert|Paso 5: Nivel|Paso 6: Auto|Paso 7: Iniciar
    Gui, Main:Add, Text, x325 y363 cSilver, Delay (ms):
    Gui, Main:Add, Edit, x395 y360 w60 h22 vEditScrollDelay, 500
    Gui, Main:Add, UpDown, Range100-3000, 500

    Gui, Main:Font, s9 cWhite Normal
    Gui, Main:Add, Button, x25 y395 w200 h25 gSeleccionarPuntoScroll, Seleccionar Punto (clic)
    Gui, Main:Add, Button, x235 y395 w225 h25 gProbarScroll, Probar Scroll

    ; --- SECCIÓN: Control del Bot ---
    Gui, Main:Font, s10 cWhite Bold
    Gui, Main:Add, GroupBox, x10 y440 w460 h60, CONTROL DEL BOT

    Gui, Main:Font, s9 cWhite Normal
    Gui, Main:Add, Button, x25 y465 w140 h25 gIniciarBot, INICIAR (F12)
    Gui, Main:Add, Button, x175 y465 w140 h25 gPausarBot, PAUSAR (F12)
    Gui, Main:Add, Button, x325 y465 w135 h25 gDetenerBot, DETENER (F11)

    ; --- SECCIÓN: Estado ---
    Gui, Main:Font, s10 cWhite Bold
    Gui, Main:Add, GroupBox, x10 y510 w460 h50, ESTADO

    Gui, Main:Font, s11 c0x00FF88 Bold
    Gui, Main:Add, Text, x25 y532 w440 h20 vTextoEstado, Estado: DETENIDO  |  Ciclos: 0  |  Ataques: 0  |  Errores: 0

    ; --- SECCIÓN: Log de Depuración ---
    Gui, Main:Font, s10 cWhite Bold
    Gui, Main:Add, GroupBox, x10 y570 w460 h220, LOG DE DEPURACIÓN

    Gui, Main:Font, s8 c0x00FF88 Normal, Consolas
    Gui, Main:Add, Edit, x25 y595 w435 h185 vLogText ReadOnly Multi VScroll HScroll -Wrap BackgroundBlack,

    ; --- Mostrar ventana ---
    Gui, Main:Show, w480 h805, Game Bot - AutoHotkey v1.1
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
    global IMG_VICTORIA, IMG_DERROTA

    faltantes := 0
    Loop, %TotalPasos% {
        if (A_Index = 8) {
            Log("OK: Paso 8 -> Resultado (escanea victoria/derrota)")
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
    Loop, 7 {
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

    BotActivo := true
    BotPausado := false
    PasoActual := 1
    EstadoActual := "Paso 1"
    ContadorCiclos := 0
    ContadorAtaques := 0
    ContadorErrores := 0
    ErroresConsecutivos := 0
    ResultadoIntentos := 0
    Log("=== BOT INICIADO ===")
    Log("Ventana: " . VentanaObjetivo)
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

    nombreActual := PasoNombres[PasoActual]
    EstadoActual := "Paso " . PasoActual . "/" . TotalPasos . ": " . nombreActual
    ActualizarEstado()

    ; ================================================================
    ; PASO 8 ESPECIAL: Escanear victoria O derrota
    ; 15 intentos con 10 segundos entre cada uno (NO-BLOQUEANTE)
    ; Cada tick del timer hace UN solo intento y retorna
    ; ================================================================
    if (PasoActual = 8) {
        ResultadoIntentos++

        ; Primera vez: cambiar timer a 10s y logear
        if (ResultadoIntentos = 1) {
            Log("Paso 8: Buscando resultado de batalla (15 intentos, 10s entre cada uno)...")
            SetTimer, LoopPrincipal, 10000
        }

        EstadoActual := "Paso 8: Esperando resultado... (" . ResultadoIntentos . "/15)"
        ActualizarEstado()

        ; Buscar DERROTA (solo detectar, NO hacer clic)
        if (BuscarImagenEnVentana(IMG_DERROTA, foundX, foundY)) {
            Log("DERROTA detectada en intento " . ResultadoIntentos . "/15")
            ErroresConsecutivos := 0
            ResultadoIntentos := 0
            PasoActual := 9
            Log(">>> Ruta derrota: avanzando a paso 9 (Tap 1)")
            SetTimer, LoopPrincipal, %IntervaloLoop%
            ActualizarEstado()
            return
        }

        ; Buscar VICTORIA
        if (BuscarImagenEnVentana(IMG_VICTORIA, foundX, foundY)) {
            Log("VICTORIA detectada en intento " . ResultadoIntentos . "/15")
            HacerClicEnVentana(foundX, foundY)
            ErroresConsecutivos := 0
            ContadorAtaques++
            ResultadoIntentos := 0
            PasoActual := 1
            Log(">>> Victoria: volviendo a paso 1")
            SetTimer, LoopPrincipal, %IntervaloLoop%
            ActualizarEstado()
            return
        }

        ; Si se agotaron los 15 intentos sin resultado
        if (ResultadoIntentos >= 15) {
            Log("RECUPERACION: Sin resultado tras 15 intentos (150s). Reiniciando desde paso 1...")
            PasoActual := 1
            ErroresConsecutivos := 0
            ResultadoIntentos := 0
            SetTimer, LoopPrincipal, %IntervaloLoop%
        }

        ActualizarEstado()
        return
    }

    ; ================================================================
    ; PASOS NORMALES (1-7, 9-11): Buscar imagen y clicar
    ; ================================================================
    imgActual := PasoImagenes[PasoActual]

    ; Verificar que el archivo de imagen exista
    if !FileExist(imgActual) {
        Log("ERROR: Falta imagen para paso " . PasoActual . " (" . nombreActual . "): " . imgActual)
        ContadorErrores++
        return
    }

    ; Scroll inteligente: buscar imagen ANTES y DESPUÉS de cada scroll individual
    ; (solo aplica a pasos 1-7 donde se configura scroll)
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
        Sleep, 1500

        ; Avanzar al siguiente paso con lógica de salto
        if (PasoActual = 11) {
            ; Después de Next (fin de ruta derrota) -> volver a Nivel
            PasoActual := 5
            Log(">>> Ciclo derrota completado. Volviendo a paso 5: " . PasoNombres[5])
        } else {
            PasoActual := PasoActual + 1
            Log(">>> Avanzando a paso " . PasoActual . ": " . PasoNombres[PasoActual])
        }
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
; FUNCIÓN: Buscar una imagen dentro de la ventana del juego
; Retorna true si la encontró, false si no
; foundX y foundY contienen las coordenadas (relativas a pantalla)
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
        ExitApp
    }
return

ListaGuiClose:
ListaGuiEscape:
    Gui, Lista:Destroy
return
