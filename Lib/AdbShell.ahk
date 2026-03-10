; ============================================================================
; ADB SHELL PERSISTENTE - Envía taps y swipes via shell interactivo
; Mantiene una sesión adb shell abierta para evitar el overhead de crear
; un proceso nuevo por cada comando (~200ms vs ~2000ms).
; Usa CreateProcessW con CREATE_NO_WINDOW para evitar ventanas CMD visibles.
; ============================================================================

global _AdbShell_hProcess := 0
global _AdbShell_hStdinWrite := 0
global _AdbShell_Vivo := false

; ============================================================================
; Iniciar shell ADB persistente (sin ventana CMD visible)
; adbDevice: serial del dispositivo (ej: "127.0.0.1:5555"), "" para default
; ============================================================================
AdbShell_Iniciar(adbDevice := "") {
    global _AdbShell_hProcess, _AdbShell_hStdinWrite, _AdbShell_Vivo

    ; Si ya hay un shell vivo, no crear otro
    if (_AdbShell_Vivo && _AdbShell_hProcess) {
        ; Verificar que el proceso sigue vivo
        exitCode := 0
        DllCall("GetExitCodeProcess", "Ptr", _AdbShell_hProcess, "UInt*", exitCode)
        if (exitCode = 259)  ; STILL_ACTIVE
            return true
        ; El proceso murió, limpiamos y reconectamos
        AdbShell_Cerrar()
    }

    ; --- Crear pipe para stdin ---
    ; SECURITY_ATTRIBUTES con bInheritHandle = TRUE
    VarSetCapacity(saAttr, A_PtrSize == 8 ? 24 : 12, 0)
    NumPut(A_PtrSize == 8 ? 24 : 12, saAttr, 0, "UInt")  ; nLength
    NumPut(1, saAttr, A_PtrSize == 8 ? 16 : 8, "Int")     ; bInheritHandle = TRUE

    hStdinRead := 0
    hStdinWrite := 0
    if !DllCall("CreatePipe", "Ptr*", hStdinRead, "Ptr*", hStdinWrite, "Ptr", &saAttr, "UInt", 0) {
        return false
    }

    ; El extremo de escritura NO debe ser heredable (solo el de lectura va al hijo)
    DllCall("SetHandleInformation", "Ptr", hStdinWrite, "UInt", 1, "UInt", 0)

    ; --- Abrir NUL device para stdout/stderr del hijo ---
    ; adb necesita poder escribir a stdout/stderr, pero no nos interesa leer la salida
    ; GENERIC_WRITE=0x40000000, FILE_SHARE_READ|WRITE=3, OPEN_EXISTING=3
    hNul := DllCall("CreateFileW", "Str", "NUL", "UInt", 0x40000000
        , "UInt", 3, "Ptr", &saAttr, "UInt", 3, "UInt", 0, "Ptr", 0, "Ptr")
    if (hNul = -1) {
        DllCall("CloseHandle", "Ptr", hStdinRead)
        DllCall("CloseHandle", "Ptr", hStdinWrite)
        return false
    }

    ; --- Preparar STARTUPINFOW ---
    siSize := A_PtrSize == 8 ? 104 : 68
    VarSetCapacity(si, siSize, 0)
    NumPut(siSize, si, 0, "UInt")  ; cb

    ; dwFlags = STARTF_USESTDHANDLES (0x100)
    flagsOffset := A_PtrSize == 8 ? 60 : 44
    NumPut(0x100, si, flagsOffset, "UInt")

    ; hStdInput = pipe read end, hStdOutput/hStdError = NUL device
    hStdInputOffset := A_PtrSize == 8 ? 80 : 56
    NumPut(hStdinRead, si, hStdInputOffset, "Ptr")
    hStdOutputOffset := hStdInputOffset + A_PtrSize
    hStdErrorOffset := hStdOutputOffset + A_PtrSize
    NumPut(hNul, si, hStdOutputOffset, "Ptr")
    NumPut(hNul, si, hStdErrorOffset, "Ptr")

    ; --- Preparar PROCESS_INFORMATION ---
    piSize := A_PtrSize == 8 ? 24 : 16
    VarSetCapacity(pi, piSize, 0)

    ; --- Construir comando ---
    cmd := "adb"
    if (adbDevice != "")
        cmd .= " -s " . adbDevice
    cmd .= " shell"

    ; --- CreateProcessW con CREATE_NO_WINDOW (0x08000000) ---
    result := DllCall("CreateProcessW"
        , "Ptr", 0              ; lpApplicationName
        , "Str", cmd            ; lpCommandLine
        , "Ptr", 0              ; lpProcessAttributes
        , "Ptr", 0              ; lpThreadAttributes
        , "Int", 1              ; bInheritHandles = TRUE
        , "UInt", 0x08000000    ; dwCreationFlags = CREATE_NO_WINDOW
        , "Ptr", 0              ; lpEnvironment
        , "Ptr", 0              ; lpCurrentDirectory
        , "Ptr", &si            ; lpStartupInfo
        , "Ptr", &pi)           ; lpProcessInformation

    ; Cerrar handles que ya fueron heredados por el hijo
    DllCall("CloseHandle", "Ptr", hStdinRead)
    DllCall("CloseHandle", "Ptr", hNul)

    if (!result) {
        DllCall("CloseHandle", "Ptr", hStdinWrite)
        return false
    }

    ; Guardar handles
    _AdbShell_hProcess := NumGet(pi, 0, "Ptr")    ; hProcess
    hThread := NumGet(pi, A_PtrSize, "Ptr")        ; hThread
    DllCall("CloseHandle", "Ptr", hThread)         ; No necesitamos el thread handle
    _AdbShell_hStdinWrite := hStdinWrite
    _AdbShell_Vivo := true

    ; Esperar un poco para que el shell inicie
    Sleep, 500
    return true
}

; ============================================================================
; Enviar comando al shell ADB (con auto-reconexión si murió)
; ============================================================================
AdbShell_Enviar(comando, adbDevice := "") {
    global _AdbShell_hProcess, _AdbShell_hStdinWrite, _AdbShell_Vivo

    ; Verificar si el proceso sigue vivo
    if (_AdbShell_Vivo && _AdbShell_hProcess) {
        exitCode := 0
        DllCall("GetExitCodeProcess", "Ptr", _AdbShell_hProcess, "UInt*", exitCode)
        if (exitCode != 259) {  ; No está STILL_ACTIVE
            _AdbShell_Vivo := false
        }
    }

    if (!_AdbShell_Vivo) {
        if !AdbShell_Iniciar(adbDevice)
            return false
    }

    ; Escribir comando + newline al pipe stdin
    cmdBytes := comando . "`n"
    VarSetCapacity(buf, StrLen(cmdBytes) + 1, 0)
    StrPut(cmdBytes, &buf, "UTF-8")
    bytesToWrite := StrLen(cmdBytes)
    bytesWritten := 0

    result := DllCall("WriteFile"
        , "Ptr", _AdbShell_hStdinWrite
        , "Ptr", &buf
        , "UInt", bytesToWrite
        , "UInt*", bytesWritten
        , "Ptr", 0)

    if (!result || bytesWritten = 0) {
        ; Falló la escritura, intentar reconectar una vez
        _AdbShell_Vivo := false
        if (AdbShell_Iniciar(adbDevice)) {
            VarSetCapacity(buf2, StrLen(cmdBytes) + 1, 0)
            StrPut(cmdBytes, &buf2, "UTF-8")
            result := DllCall("WriteFile"
                , "Ptr", _AdbShell_hStdinWrite
                , "Ptr", &buf2
                , "UInt", bytesToWrite
                , "UInt*", bytesWritten
                , "Ptr", 0)
            return (result && bytesWritten > 0)
        }
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
; Cerrar shell ADB
; ============================================================================
AdbShell_Cerrar() {
    global _AdbShell_hProcess, _AdbShell_hStdinWrite, _AdbShell_Vivo

    if (_AdbShell_hStdinWrite) {
        try {
            ; Enviar "exit" antes de cerrar
            exitCmd := "exit`n"
            VarSetCapacity(buf, 10, 0)
            StrPut(exitCmd, &buf, "UTF-8")
            DllCall("WriteFile", "Ptr", _AdbShell_hStdinWrite, "Ptr", &buf, "UInt", 5, "UInt*", bw, "Ptr", 0)
            Sleep, 100
        }
        DllCall("CloseHandle", "Ptr", _AdbShell_hStdinWrite)
    }

    if (_AdbShell_hProcess) {
        DllCall("TerminateProcess", "Ptr", _AdbShell_hProcess, "UInt", 0)
        DllCall("CloseHandle", "Ptr", _AdbShell_hProcess)
    }

    _AdbShell_hProcess := 0
    _AdbShell_hStdinWrite := 0
    _AdbShell_Vivo := false
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
