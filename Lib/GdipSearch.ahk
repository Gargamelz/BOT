; ============================================================================
; GDI+ IMAGE SEARCH - Búsqueda de imágenes usando PrintWindow + GDI+
; Funciona con ventanas en segundo plano (background), sin importar si están
; tapadas por otras ventanas.
; ============================================================================

; Token global de GDI+
global _gdipToken := 0
global _NeedleCache := {}

; ============================================================================
; Inicializar GDI+ (llamar una vez al inicio del script)
; ============================================================================
Gdip_Iniciar() {
    global _gdipToken

    ; Cargar gdiplus.dll explícitamente
    DllCall("LoadLibrary", "Str", "gdiplus")

    ; GdiplusStartupInput: Version = 1
    VarSetCapacity(si, 24, 0)
    NumPut(1, si, 0, "UInt")
    resultado := DllCall("gdiplus\GdiplusStartup", "Ptr*", _gdipToken, "Ptr", &si, "Ptr", 0)
    return (resultado = 0)
}

; ============================================================================
; Terminar GDI+ (llamar al cerrar el script)
; ============================================================================
Gdip_Terminar() {
    global _gdipToken, _NeedleCache

    ; Liberar needles cacheados
    for ruta, obj in _NeedleCache {
        if (obj.pBitmap)
            DllCall("gdiplus\GdipDisposeImage", "Ptr", obj.pBitmap)
    }
    _NeedleCache := {}

    if (_gdipToken)
        DllCall("gdiplus\GdiplusShutdown", "Ptr", _gdipToken)
    _gdipToken := 0
}

; ============================================================================
; Cargar needle (imagen a buscar) con caché persistente
; ============================================================================
GdipCargarNeedle(rutaImagen, ByRef pBitmap, ByRef w, ByRef h) {
    global _NeedleCache

    if (_NeedleCache.HasKey(rutaImagen)) {
        obj := _NeedleCache[rutaImagen]
        pBitmap := obj.pBitmap
        w := obj.w
        h := obj.h
        return true
    }

    pBitmap := 0
    DllCall("gdiplus\GdipCreateBitmapFromFile", "WStr", rutaImagen, "Ptr*", pBitmap)
    if (!pBitmap)
        return false

    w := 0
    h := 0
    DllCall("gdiplus\GdipGetImageWidth", "Ptr", pBitmap, "UInt*", w)
    DllCall("gdiplus\GdipGetImageHeight", "Ptr", pBitmap, "UInt*", h)
    _NeedleCache[rutaImagen] := {pBitmap: pBitmap, w: w, h: h}
    return true
}

; ============================================================================
; Capturar ventana usando PrintWindow → GDI+ Bitmap
; Retorna pBitmap (debe liberarse con GdipDisposeImage después de usarlo)
; cw, ch = dimensiones del área cliente
; ============================================================================
GdipCapturarVentana(hwnd, ByRef pBitmap, ByRef cw, ByRef ch) {
    ; Obtener dimensiones del área cliente
    VarSetCapacity(rc, 16, 0)
    DllCall("GetClientRect", "Ptr", hwnd, "Ptr", &rc)
    cw := NumGet(rc, 8, "Int")
    ch := NumGet(rc, 12, "Int")
    if (cw <= 0 || ch <= 0)
        return false

    ; Crear DC compatible y bitmap
    hdc := DllCall("GetDC", "Ptr", hwnd, "Ptr")
    mdc := DllCall("CreateCompatibleDC", "Ptr", hdc, "Ptr")
    hbm := DllCall("CreateCompatibleBitmap", "Ptr", hdc, "Int", cw, "Int", ch, "Ptr")
    old := DllCall("SelectObject", "Ptr", mdc, "Ptr", hbm, "Ptr")

    ; PrintWindow con PW_CLIENTONLY | PW_RENDERFULLCONTENT = 0x3
    ; (PW_RENDERFULLCONTENT requiere Windows 8.1+, funciona en emuladores modernos)
    DllCall("PrintWindow", "Ptr", hwnd, "Ptr", mdc, "UInt", 0x3)

    ; Convertir a GDI+ bitmap
    pBitmap := 0
    DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "Ptr", hbm, "Ptr", 0, "Ptr*", pBitmap)

    ; Limpiar objetos GDI
    DllCall("SelectObject", "Ptr", mdc, "Ptr", old)
    DllCall("DeleteObject", "Ptr", hbm)
    DllCall("DeleteDC", "Ptr", mdc)
    DllCall("ReleaseDC", "Ptr", hwnd, "Ptr", hdc)
    return (pBitmap != 0)
}

; ============================================================================
; Buscar imagen needle dentro de haystack con tolerancia
; Retorna true si encontrada; outX, outY = posición top-left del match
; Usa fast-rejection: primer pixel + último pixel antes de comparación completa
; ============================================================================
GdipBuscarImagen(pHaystack, hw, hh, pNeedle, nw, nh, tolerancia, ByRef outX, ByRef outY) {
    ; Lock haystack bits (PixelFormat32bppARGB = 0x26200A)
    VarSetCapacity(rectH, 16, 0)
    NumPut(hw, rectH, 8, "Int")
    NumPut(hh, rectH, 12, "Int")
    VarSetCapacity(bdH, 32, 0)
    DllCall("gdiplus\GdipBitmapLockBits", "Ptr", pHaystack, "Ptr", &rectH
        , "UInt", 1, "Int", 0x26200A, "Ptr", &bdH)
    strideH := NumGet(bdH, 8, "Int")
    scanH := NumGet(bdH, 16, "Ptr")

    ; Lock needle bits
    VarSetCapacity(rectN, 16, 0)
    NumPut(nw, rectN, 8, "Int")
    NumPut(nh, rectN, 12, "Int")
    VarSetCapacity(bdN, 32, 0)
    DllCall("gdiplus\GdipBitmapLockBits", "Ptr", pNeedle, "Ptr", &rectN
        , "UInt", 1, "Int", 0x26200A, "Ptr", &bdN)
    strideN := NumGet(bdN, 8, "Int")
    scanN := NumGet(bdN, 16, "Ptr")

    ; Obtener primer y último pixel del needle para fast rejection
    firstN := NumGet(scanN + 0, "UInt")
    lastN := NumGet(scanN + ((nh - 1) * strideN) + ((nw - 1) * 4), "UInt")

    found := false
    maxY := hh - nh
    maxX := hw - nw

    Loop, % maxY + 1 {
        y := A_Index - 1
        Loop, % maxX + 1 {
            x := A_Index - 1

            ; Fast reject: primer pixel
            pxH := NumGet(scanH + (y * strideH) + (x * 4), "UInt")
            if !PixelCoincide(pxH, firstN, tolerancia)
                continue

            ; Fast reject: último pixel
            pxH2 := NumGet(scanH + ((y + nh - 1) * strideH) + ((x + nw - 1) * 4), "UInt")
            if !PixelCoincide(pxH2, lastN, tolerancia)
                continue

            ; Comparación completa
            match := true
            ny := 0
            while (ny < nh && match) {
                nx := 0
                while (nx < nw && match) {
                    pH := NumGet(scanH + ((y + ny) * strideH) + ((x + nx) * 4), "UInt")
                    pN := NumGet(scanN + (ny * strideN) + (nx * 4), "UInt")
                    if !PixelCoincide(pH, pN, tolerancia)
                        match := false
                    nx++
                }
                ny++
            }

            if (match) {
                outX := x
                outY := y
                found := true
                break 2
            }
        }
    }

    DllCall("gdiplus\GdipBitmapUnlockBits", "Ptr", pHaystack, "Ptr", &bdH)
    DllCall("gdiplus\GdipBitmapUnlockBits", "Ptr", pNeedle, "Ptr", &bdN)
    return found
}

; ============================================================================
; Comparar dos pixeles ARGB con tolerancia por canal RGB
; ============================================================================
PixelCoincide(px1, px2, tol) {
    r1 := (px1 >> 16) & 0xFF, g1 := (px1 >> 8) & 0xFF, b1 := px1 & 0xFF
    r2 := (px2 >> 16) & 0xFF, g2 := (px2 >> 8) & 0xFF, b2 := px2 & 0xFF
    return (Abs(r1 - r2) <= tol && Abs(g1 - g2) <= tol && Abs(b1 - b2) <= tol)
}

; ============================================================================
; Función principal: buscar imagen en ventana (drop-in para BuscarImagenEnVentana)
; Retorna coords del CENTRO de la imagen encontrada (client-relative)
; ============================================================================
BuscarImagenGDI(hwnd, rutaImagen, ByRef cx, ByRef cy, tolerancia) {
    ; Cargar needle (cacheado)
    if !GdipCargarNeedle(rutaImagen, pNeedle, nw, nh)
        return false

    ; Capturar ventana
    if !GdipCapturarVentana(hwnd, pHaystack, cw, ch)
        return false

    ; Buscar
    resultado := GdipBuscarImagen(pHaystack, cw, ch, pNeedle, nw, nh, tolerancia, fx, fy)

    ; Liberar captura (needles quedan cacheados)
    DllCall("gdiplus\GdipDisposeImage", "Ptr", pHaystack)

    if (!resultado)
        return false

    ; Retornar centro de la imagen encontrada
    cx := fx + (nw // 2)
    cy := fy + (nh // 2)
    return true
}
