; Test script: verifica que Run con Hide no muestra ventana CMD
; Ejecutar este script y observar que NO aparezca ninguna ventana de consola
#NoEnv
#SingleInstance Force

MsgBox, 64, Test ADB Hide, Se ejecutaran 5 comandos adb con Hide.`nNO deberia aparecer ninguna ventana de CMD.`n`nPresiona OK para iniciar.

; Test 1: RunWait con Hide (como AdbShell_Iniciar)
RunWait, adb shell echo test_1,, Hide UseErrorLevel
if (ErrorLevel = "ERROR")
    MsgBox, 16, Error, No se encontro adb en PATH
else if (ErrorLevel != 0)
    MsgBox, 16, Error, adb fallo (no hay device conectado?). ExitCode: %ErrorLevel%
else
    MsgBox, 64, Test 1 OK, RunWait + Hide funciono sin ventana visible. ExitCode: %ErrorLevel%

; Test 2-5: Run (no-wait) con Hide (como AdbShell_Enviar)
Loop, 4 {
    Run, adb shell input tap 100 200,, Hide UseErrorLevel
    if (ErrorLevel = "ERROR") {
        MsgBox, 16, Error, Run + Hide fallo en iteracion %A_Index%
        break
    }
    Sleep, 300
}

MsgBox, 64, Test Completo, Todos los tests completados.`n`nSi NO aparecio ninguna ventana CMD el fix es correcto.

ExitApp
