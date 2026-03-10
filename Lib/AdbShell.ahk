; ============================================================================
; ADB SHELL - Envía taps y swipes via comandos adb individuales
; Cada comando se ejecuta como proceso separado con ventana oculta (Hide)
; para evitar flasheo de CMD. Simple, confiable, sin overhead perceptible.
; ============================================================================

global _AdbShell_Device := ""
global _AdbShell_Conectado := false

; ============================================================================
; Verificar conexión ADB (ejecuta un comando de prueba)
; adbDevice: serial del dispositivo (ej: "127.0.0.1:5555"), "" para default
; Retorna true si adb responde correctamente
; ============================================================================
AdbShell_Iniciar(adbDevice := "") {
    global _AdbShell_Device, _AdbShell_Conectado

    _AdbShell_Device := adbDevice
    _AdbShell_Conectado := false

    ; Construir comando de prueba
    cmd := _AdbShell_BuildCmd("echo adb_ok")

    ; Ejecutar con RunWait para verificar que funciona
    RunWait, %cmd%,, Hide UseErrorLevel
    if (ErrorLevel = "ERROR" || ErrorLevel != 0) {
        _AdbShell_Conectado := false
        return false
    }

    _AdbShell_Conectado := true
    return true
}

; ============================================================================
; Enviar comando al shell ADB
; Ejecuta: adb [-s device] shell <comando>
; Usa Run con Hide para que no aparezca ventana CMD
; ============================================================================
AdbShell_Enviar(comando, adbDevice := "") {
    global _AdbShell_Device, _AdbShell_Conectado

    ; Usar device guardado si no se especifica uno
    if (adbDevice = "")
        adbDevice := _AdbShell_Device

    cmd := "adb"
    if (adbDevice != "")
        cmd .= " -s " . adbDevice
    cmd .= " shell " . comando

    ; Run (no-wait) con Hide: ejecuta en background sin ventana visible
    Run, %cmd%,, Hide UseErrorLevel
    if (ErrorLevel = "ERROR") {
        _AdbShell_Conectado := false
        return false
    }
    return true
}

; ============================================================================
; Enviar tap ADB (input tap X Y)
; ============================================================================
AdbShell_Tap(x, y, adbDevice := "") {
    return AdbShell_Enviar("input tap " . x . " " . y, adbDevice)
}

; ============================================================================
; Enviar swipe ADB (input swipe X1 Y1 X2 Y2 duracion_ms)
; ============================================================================
AdbShell_Swipe(x1, y1, x2, y2, duracion := 300, adbDevice := "") {
    return AdbShell_Enviar("input swipe " . x1 . " " . y1 . " " . x2 . " " . y2 . " " . duracion, adbDevice)
}

; ============================================================================
; Cerrar / limpiar estado ADB
; ============================================================================
AdbShell_Cerrar() {
    global _AdbShell_Device, _AdbShell_Conectado
    _AdbShell_Device := ""
    _AdbShell_Conectado := false
}

; ============================================================================
; Helper interno: construir la línea de comando completa
; ============================================================================
_AdbShell_BuildCmd(shellCmd) {
    global _AdbShell_Device
    cmd := "adb"
    if (_AdbShell_Device != "")
        cmd .= " -s " . _AdbShell_Device
    cmd .= " shell " . shellCmd
    return cmd
}

; ============================================================================
; Convertir coordenadas client-relative de la ventana a Android screen coords
; hwnd: handle de la ventana del emulador
; clientX, clientY: coords dentro del client area
; adbResX, adbResY: resolución Android (ej: 1080x1920)
; ============================================================================
ClientToAndroid(hwnd, clientX, clientY, adbResX, adbResY, ByRef androidX, ByRef androidY) {
    VarSetCapacity(rc, 16, 0)
    DllCall("GetClientRect", "Ptr", hwnd, "Ptr", &rc)
    cw := NumGet(rc, 8, "Int")
    ch := NumGet(rc, 12, "Int")
    if (cw <= 0 || ch <= 0) {
        androidX := 0
        androidY := 0
        return false
    }
    androidX := Round(clientX * adbResX / cw)
    androidY := Round(clientY * adbResY / ch)
    return true
}
