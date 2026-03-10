; ============================================================================
; ADB SHELL PERSISTENTE - Envía taps y swipes via shell interactivo
; Mantiene una sesión adb shell abierta para evitar el overhead de crear
; un proceso nuevo por cada comando (~200ms vs ~2000ms).
; ============================================================================

global _AdbShell := ""
global _AdbVivo := false

; ============================================================================
; Iniciar shell ADB persistente
; adbDevice: serial del dispositivo (ej: "127.0.0.1:5555"), "" para default
; ============================================================================
AdbShell_Iniciar(adbDevice := "") {
    global _AdbShell, _AdbVivo

    ; Si ya hay un shell vivo, no crear otro
    if (_AdbVivo && _AdbShell && _AdbShell.Status = 0)
        return true

    try {
        wsh := ComObjCreate("WScript.Shell")
        cmd := "adb"
        if (adbDevice != "")
            cmd .= " -s " . adbDevice
        cmd .= " shell"
        _AdbShell := wsh.Exec(cmd)
        Sleep, 500

        if (_AdbShell.Status = 0) {
            _AdbVivo := true
            return true
        }
    } catch e {
        ; Error al crear shell (adb no instalado, device no conectado, etc.)
    }
    _AdbVivo := false
    return false
}

; ============================================================================
; Enviar comando al shell ADB (con auto-reconexión si murió)
; ============================================================================
AdbShell_Enviar(comando, adbDevice := "") {
    global _AdbShell, _AdbVivo

    if (!_AdbVivo || !_AdbShell || _AdbShell.Status != 0) {
        if !AdbShell_Iniciar(adbDevice)
            return false
    }

    try {
        _AdbShell.StdIn.WriteLine(comando)
        return true
    } catch {
        _AdbVivo := false
        ; Un reintento
        if (AdbShell_Iniciar(adbDevice)) {
            try {
                _AdbShell.StdIn.WriteLine(comando)
                return true
            }
        }
    }
    return false
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
; Cerrar shell ADB
; ============================================================================
AdbShell_Cerrar() {
    global _AdbShell, _AdbVivo

    if (_AdbShell) {
        try {
            _AdbShell.StdIn.WriteLine("exit")
            _AdbShell.Terminate()
        }
    }
    _AdbVivo := false
    _AdbShell := ""
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
