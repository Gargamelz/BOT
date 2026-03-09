; ============================================================================
; GAME BOT - AutoHotkey v1.1 - MULTI-INSTANCIA (hasta 5)
; Bot genérico para automatizar juegos en segundo plano (background)
; ============================================================================
; HOTKEYS GLOBALES:
;   F12  = Iniciar / Pausar TODAS las instancias activas
;   F11  = Detener TODAS las instancias
;   F10  = Recargar el script
; ============================================================================

#NoEnv
#SingleInstance, Force
#Persistent
SetWorkingDir, %A_ScriptDir%
SetBatchLines, -1
CoordMode, Pixel, Screen

; ============================================================================
; CONSTANTES GLOBALES
; ============================================================================
global MAX_INST := 5
global TotalPasos := 11
global TotalExpansiones := 11
global CarpetaImagenes := A_ScriptDir . "\imagenes"
global ArchivoConfig := A_ScriptDir . "\config.ini"

; Configuración compartida (leída de la GUI)
global Variacion := 50
global IntervaloLoop := 1000
global MaxReintentos := 5
global ModoDebug := true
global VentanaAncho := 960
global VentanaAlto := 540
global AutoAjustar := false

; Scroll compartido
global ScrollActivo := false
global ScrollRelX := 200
global ScrollRelY := 300
global ScrollCantidad := 3
global ScrollDelay := 500
global ScrollEnPaso := 0

; Anti-atasco
global MaxErroresConsecutivos := 30
global MaxTapIntentos := 30
global MaxNuevaBatallaIntentos := 10
global WatchdogSegundos := 300
global UmbralScanPopups := 15

; ADB - Configuración global
global ADB_Ruta := ""              ; Ruta al adb.exe (auto-detectada o manual)
global ADB_Habilitado := false     ; true = usar ADB para clicks/swipes

; Imágenes fijas (compartidas, no cambian por instancia)
global IMG_VICTORIA := CarpetaImagenes . "\pantalla_victoria.bmp"
global IMG_DERROTA  := CarpetaImagenes . "\pantalla_derrota.bmp"
global IMG_TAP  := CarpetaImagenes . "\boton_tap.bmp"
global IMG_NEXT := CarpetaImagenes . "\boton_next.bmp"
global IMG_NUEVA_BATALLA := CarpetaImagenes . "\pantalla_nueva_batalla.bmp"
global IMG_OK            := CarpetaImagenes . "\boton_ok.bmp"
global IMG_EQUIS := CarpetaImagenes . "\boton_equis.bmp"
global IMG_EXPANSIONES := CarpetaImagenes . "\boton_expansiones.bmp"

; Pasos: imágenes y nombres (estáticos, los dinámicos se resuelven en ProcesarInstancia)
global PasoImagenes := {}
global PasoNombres := {}
PasoImagenes[1]  := ""
PasoNombres[1]   := "SeleccionBatalla"
PasoImagenes[2]  := CarpetaImagenes . "\boton_auto.bmp"
PasoNombres[2]   := "Auto"
PasoImagenes[3]  := CarpetaImagenes . "\boton_iniciar.bmp"
PasoNombres[3]   := "Iniciar"
PasoImagenes[4]  := ""
PasoNombres[4]   := "Resultado"
PasoImagenes[5]  := ""
PasoNombres[5]   := "Tap hasta Next"
PasoImagenes[6]  := ""
PasoNombres[6]   := "NuevaBatalla"
PasoImagenes[7]  := CarpetaImagenes . "\boton_ok.bmp"
PasoNombres[7]   := "OK"
PasoImagenes[8]  := ""
PasoNombres[8]   := "SiguienteBatalla"
PasoImagenes[9]  := CarpetaImagenes . "\boton_equis.bmp"
PasoNombres[9]   := "CerrarX"
PasoImagenes[10] := ""
PasoNombres[10]  := "CambiarExpansion"
PasoImagenes[11] := ""
PasoNombres[11]  := "SeleccionarExpansion"

; Nombres de expansiones
global ExpansionNombres := {}
ExpansionNombres[1]  := "Genetic Apex"
ExpansionNombres[2]  := "Mythical Island"
ExpansionNombres[3]  := "Space Time Smackdown"
ExpansionNombres[4]  := "Triumphant Light"
ExpansionNombres[5]  := "Shining Revelry"
ExpansionNombres[6]  := "Celestial Guardians"
ExpansionNombres[7]  := "Extradimensional Crisis"
ExpansionNombres[8]  := "Eevee Grove"
ExpansionNombres[9]  := "Wisdom of Sea and Sky"
ExpansionNombres[10] := "Manantial Oculto"
ExpansionNombres[11] := "Deluxe EX"

; Imágenes de expansiones (menú de selección, paso 11)
global ExpansionImagenes := {}
ExpansionImagenes[1]  := CarpetaImagenes . "\boton_genetic_apex.bmp"
ExpansionImagenes[2]  := CarpetaImagenes . "\boton_mythical_island.bmp"
ExpansionImagenes[3]  := CarpetaImagenes . "\boton_space_time_smackdown.bmp"
ExpansionImagenes[4]  := CarpetaImagenes . "\boton_triumphant_light.bmp"
ExpansionImagenes[5]  := CarpetaImagenes . "\boton_shining_revelry.bmp"
ExpansionImagenes[6]  := CarpetaImagenes . "\boton_celestial_guardians.bmp"
ExpansionImagenes[7]  := CarpetaImagenes . "\boton_extradimensional_crisis.bmp"
ExpansionImagenes[8]  := CarpetaImagenes . "\boton_eevee_grove.bmp"
ExpansionImagenes[9]  := CarpetaImagenes . "\boton_wisdom_sea_sky.bmp"
ExpansionImagenes[10] := CarpetaImagenes . "\boton_manantial_oculto.bmp"
ExpansionImagenes[11] := CarpetaImagenes . "\boton_deluxe_ex.bmp"

; ============================================================================
; DATOS DE BATALLA PRE-CARGADOS (estructura 2D estática)
; BatImg[exp, bat] = ruta imagen, BatNom[exp, bat] = nombre, BatCnt[exp] = total
; ============================================================================
global BatImg := {}
global BatNom := {}
global BatCnt := {}

CargarTodasLasBatallas()

; ============================================================================
; ESTADO PER-INSTANCIA (arrays indexados 1-5)
; ============================================================================
global Inst_Hwnd := {}
global Inst_Titulo := {}
global Inst_Activo := {}
global Inst_Pausado := {}
global Inst_Estado := {}
global Inst_Paso := {}
global Inst_Exp := {}
global Inst_Bat := {}
global Inst_Ataques := {}
global Inst_Ciclos := {}
global Inst_Errores := {}
global Inst_ErrCon := {}
global Inst_P1Int := {}
global Inst_P8Int := {}
global Inst_P10Int := {}
global Inst_P10Menu := {}  ; 0=buscando botón Expansiones, 1=menú abierto (solo buscar expansión destino)
global Inst_P11Int := {}
global Inst_ResInt := {}
global Inst_TapInt := {}
global Inst_NBInt := {}
global Inst_RutaPN := {}
global Inst_Cooldown := {}
global Inst_SkipTick := {}
global Inst_LastExito := {}
global RR_Inst := 0  ; Round-robin: última instancia procesada
global RR_Intervalo := 0  ; Intervalo real del timer (ms)
global Inst_RecuperacionTotal := {}

; ADB por instancia
global Inst_ADB_Puerto := {}       ; Puerto ADB de cada instancia (16384, 16416, etc.)
global Inst_ADB_Device := {}       ; Device string "127.0.0.1:PUERTO"
global Inst_ADB_Conectado := {}    ; true/false - conexión ADB verificada
global Inst_ADB_Res := {}          ; Resolución interna Android {w:, h:} para mapeo de coordenadas

; Estado de recuperación incremental por instancia
global Inst_RecupFase := {}         ; 0=no en recuperación, 1-6=escaneando popup N
global Inst_RecupOrigen := {}       ; paso de origen para log

; Estado de scroll no-bloqueante por instancia
global Inst_ScrollActivo := {}      ; true/false - si hay un scroll en curso
global Inst_ScrollHwndTarget := {}  ; hwnd del target del scroll
global Inst_ScrollChildX := {}      ; coordenada X del scroll
global Inst_ScrollYActual := {}     ; posición Y actual del arrastre
global Inst_ScrollYFin := {}        ; posición Y final del arrastre
global Inst_ScrollDir := {}         ; -1 o +1 dirección del arrastre
global Inst_ScrollPasoSize := {}    ; tamaño de cada paso (8px)
global Inst_ScrollPasos := {}       ; pasos restantes
global Inst_ScrollFase := {}        ; 0=idle, 1=arrastrando, 2=soltar, 3=buscar-post-scroll
global Inst_ScrollPostImg := {}     ; imagen a buscar tras scroll (o "" si ninguna)
global Inst_ScrollRepetir := {}     ; repeticiones de scroll pendientes (para scroll inverso)
global Inst_ScrollCantidad := {}    ; cantidad original (para repeticiones)
global Inst_ScrollRelX := {}        ; relX original (para repeticiones)
global Inst_ScrollRelY := {}        ; relY original (para repeticiones)

; Cache de dimensiones de imagen y existencia de archivos
global ImgDimCache := {}
global FileExistCache := {}

; Log buffering
global LogBuffer := ""
global LogCharCount := 0

; Inicializar estado de todas las instancias
Loop, %MAX_INST% {
    i := A_Index
    Inst_Hwnd[i] := 0
    Inst_Titulo[i] := ""
    Inst_Activo[i] := false
    Inst_Pausado[i] := false
    Inst_Estado[i] := "IDLE"
    Inst_Paso[i] := 1
    Inst_Exp[i] := 1
    Inst_Bat[i] := 1
    Inst_Ataques[i] := 0
    Inst_Ciclos[i] := 0
    Inst_Errores[i] := 0
    Inst_ErrCon[i] := 0
    Inst_P1Int[i] := 0
    Inst_P8Int[i] := 0
    Inst_P10Int[i] := 0
    Inst_P10Menu[i] := 0
    Inst_P11Int[i] := 0
    Inst_ResInt[i] := 0
    Inst_TapInt[i] := 0
    Inst_NBInt[i] := 0
    Inst_RutaPN[i] := 1
    Inst_Cooldown[i] := 0
    Inst_SkipTick[i] := 0
    Inst_LastExito[i] := 0
    Inst_RecuperacionTotal[i] := 0
}

; ============================================================================
; CREAR CARPETA DE IMÁGENES SI NO EXISTE
; ============================================================================
if !FileExist(CarpetaImagenes)
    FileCreateDir, %CarpetaImagenes%

; ============================================================================
; CARGAR CONFIGURACIÓN Y CREAR GUI
; ============================================================================
CargarConfig()
CrearGUI()
return

; ============================================================================
; FUNCIÓN: Pre-cargar TODAS las batallas de TODAS las expansiones
; ============================================================================
CargarTodasLasBatallas() {
    global BatImg, BatNom, BatCnt, CarpetaImagenes
    ci := CarpetaImagenes

    ; Expansion 1: Genetic Apex (6 batallas)
    BatCnt[1] := 6
    BatImg[1,1] := ci . "\boton_venasaur_ex.bmp"
    BatNom[1,1] := "Venasaur EX"
    BatImg[1,2] := ci . "\boton_charizard_ex.bmp"
    BatNom[1,2] := "Charizard EX"
    BatImg[1,3] := ci . "\boton_starmie_ex.bmp"
    BatNom[1,3] := "Starmie EX"
    BatImg[1,4] := ci . "\boton_pikachu_ex.bmp"
    BatNom[1,4] := "Pikachu EX"
    BatImg[1,5] := ci . "\boton_mewtwo_ex.bmp"
    BatNom[1,5] := "Mewtwo EX"
    BatImg[1,6] := ci . "\boton_machamp_ex.bmp"
    BatNom[1,6] := "Machamp EX"

    ; Expansion 2: Mythical Island (8 batallas)
    BatCnt[2] := 8
    BatImg[2,1] := ci . "\boton_venusaur_ex_mi.bmp"
    BatNom[2,1] := "Venusaur EX"
    BatImg[2,2] := ci . "\boton_celebi_ex.bmp"
    BatNom[2,2] := "Celebi EX"
    BatImg[2,3] := ci . "\boton_volcarona_ex.bmp"
    BatNom[2,3] := "Volcarona EX"
    BatImg[2,4] := ci . "\boton_gyarados_ex.bmp"
    BatNom[2,4] := "Gyarados EX"
    BatImg[2,5] := ci . "\boton_raichu_ex.bmp"
    BatNom[2,5] := "Raichu EX"
    BatImg[2,6] := ci . "\boton_mew_ex.bmp"
    BatNom[2,6] := "Mew EX"
    BatImg[2,7] := ci . "\boton_aerodactyl_ex.bmp"
    BatNom[2,7] := "Aerodactyl EX"
    BatImg[2,8] := ci . "\boton_blue_deck.bmp"
    BatNom[2,8] := "Blue Deck"

    ; Expansion 3: Space Time Smackdown (8 batallas)
    BatCnt[3] := 8
    BatImg[3,1] := ci . "\boton_yanmega_ex.bmp"
    BatNom[3,1] := "Yanmega EX"
    BatImg[3,2] := ci . "\boton_infernape_ex.bmp"
    BatNom[3,2] := "Infernape EX"
    BatImg[3,3] := ci . "\boton_palkia_ex.bmp"
    BatNom[3,3] := "Palkia EX"
    BatImg[3,4] := ci . "\boton_pachirisu_ex.bmp"
    BatNom[3,4] := "Pachirisu EX"
    BatImg[3,5] := ci . "\boton_mismagius_ex.bmp"
    BatNom[3,5] := "Mismagius EX"
    BatImg[3,6] := ci . "\boton_gallade_ex.bmp"
    BatNom[3,6] := "Gallade EX"
    BatImg[3,7] := ci . "\boton_darkrai_ex.bmp"
    BatNom[3,7] := "Darkrai EX"
    BatImg[3,8] := ci . "\boton_dialga_ex.bmp"
    BatNom[3,8] := "Dialga EX"

    ; Expansion 4: Triumphant Light (7 batallas)
    BatCnt[4] := 7
    BatImg[4,1] := ci . "\boton_leafeon_ex.bmp"
    BatNom[4,1] := "Leafeon EX"
    BatImg[4,2] := ci . "\boton_arceus_infernape.bmp"
    BatNom[4,2] := "Arceus Infernape"
    BatImg[4,3] := ci . "\boton_glaceon_ex.bmp"
    BatNom[4,3] := "Glaceon EX"
    BatImg[4,4] := ci . "\boton_arceus_pachirisu.bmp"
    BatNom[4,4] := "Arceus Pachirisu"
    BatImg[4,5] := ci . "\boton_garchomp_ex.bmp"
    BatNom[4,5] := "Garchomp EX"
    BatImg[4,6] := ci . "\boton_arceus_weavile.bmp"
    BatNom[4,6] := "Arceus Weavile"
    BatImg[4,7] := ci . "\boton_probopass_ex.bmp"
    BatNom[4,7] := "Probopass EX"

    ; Expansion 5: Shining Revelry (9 batallas)
    BatCnt[5] := 9
    BatImg[5,1] := ci . "\boton_beedrill_ex.bmp"
    BatNom[5,1] := "Beedrill EX"
    BatImg[5,2] := ci . "\boton_charizard_arceus.bmp"
    BatNom[5,2] := "Charizard Arceus"
    BatImg[5,3] := ci . "\boton_wugtrio_ex.bmp"
    BatNom[5,3] := "Wugtrio EX"
    BatImg[5,4] := ci . "\boton_pikachu_magnezone.bmp"
    BatNom[5,4] := "Pikachu Magnezone"
    BatImg[5,5] := ci . "\boton_giratina_ex.bmp"
    BatNom[5,5] := "Giratina EX"
    BatImg[5,6] := ci . "\boton_lucario_ex.bmp"
    BatNom[5,6] := "Lucario EX"
    BatImg[5,7] := ci . "\boton_paldean_clodsire_ex.bmp"
    BatNom[5,7] := "Paldean Clodsire EX"
    BatImg[5,8] := ci . "\boton_tinkaton_ex.bmp"
    BatNom[5,8] := "Tinkaton EX"
    BatImg[5,9] := ci . "\boton_bibarel_ex.bmp"
    BatNom[5,9] := "Bibarel EX"

    ; Expansion 6: Celestial Guardians (8 batallas)
    BatCnt[6] := 8
    BatImg[6,1] := ci . "\boton_decidueye_ex.bmp"
    BatNom[6,1] := "Decidueye EX"
    BatImg[6,2] := ci . "\boton_incineroar_ex.bmp"
    BatNom[6,2] := "Incineroar EX"
    BatImg[6,3] := ci . "\boton_crabominable_ex.bmp"
    BatNom[6,3] := "Crabominable EX"
    BatImg[6,4] := ci . "\boton_alolan_raichu_ex.bmp"
    BatNom[6,4] := "Alolan Raichu EX"
    BatImg[6,5] := ci . "\boton_lunala_ex.bmp"
    BatNom[6,5] := "Lunala EX"
    BatImg[6,6] := ci . "\boton_passimian_ex.bmp"
    BatNom[6,6] := "Passimian EX"
    BatImg[6,7] := ci . "\boton_alolan_muk_ex.bmp"
    BatNom[6,7] := "Alolan Muk EX"
    BatImg[6,8] := ci . "\boton_solgaleo_ex.bmp"
    BatNom[6,8] := "Solgaleo EX"

    ; Expansion 7: Extradimensional Crisis (4 batallas)
    BatCnt[7] := 4
    BatImg[7,1] := ci . "\boton_buzzwole_ex.bmp"
    BatNom[7,1] := "Buzzwole EX"
    BatImg[7,2] := ci . "\boton_tapu_koko_ex.bmp"
    BatNom[7,2] := "Tapu Koko EX"
    BatImg[7,3] := ci . "\boton_lycanroc_ex.bmp"
    BatNom[7,3] := "Lycanroc EX"
    BatImg[7,4] := ci . "\boton_guzzlord_ex.bmp"
    BatNom[7,4] := "Guzzlord EX"

    ; Expansion 8: Eevee Grove (4 batallas)
    BatCnt[8] := 4
    BatImg[8,1] := ci . "\boton_tsareena_ex.bmp"
    BatNom[8,1] := "Tsareena EX"
    BatImg[8,2] := ci . "\boton_flareon_ex.bmp"
    BatNom[8,2] := "Flareon EX"
    BatImg[8,3] := ci . "\boton_primarina_ex.bmp"
    BatNom[8,3] := "Primarina EX"
    BatImg[8,4] := ci . "\boton_sylveon_ex.bmp"
    BatNom[8,4] := "Sylveon EX"

    ; Expansion 9: Wisdom of Sea and Sky (8 batallas)
    BatCnt[9] := 8
    BatImg[9,1] := ci . "\boton_shuckle_ex.bmp"
    BatNom[9,1] := "Shuckle EX"
    BatImg[9,2] := ci . "\boton_lugia_ex.bmp"
    BatNom[9,2] := "Lugia EX"
    BatImg[9,3] := ci . "\boton_kingdra_ex.bmp"
    BatNom[9,3] := "Kingdra EX"
    BatImg[9,4] := ci . "\boton_lanturn_ex.bmp"
    BatNom[9,4] := "Lanturn EX"
    BatImg[9,5] := ci . "\boton_espeon_ex.bmp"
    BatNom[9,5] := "Espeon EX"
    BatImg[9,6] := ci . "\boton_donphan_ex.bmp"
    BatNom[9,6] := "Donphan EX"
    BatImg[9,7] := ci . "\boton_umbreon_ex.bmp"
    BatNom[9,7] := "Umbreon EX"
    BatImg[9,8] := ci . "\boton_skarmory_ex.bmp"
    BatNom[9,8] := "Skarmory EX"

    ; Expansion 10: Manantial Oculto (6 batallas)
    BatCnt[10] := 6
    BatImg[10,1] := ci . "\boton_jumpluff_ex.bmp"
    BatNom[10,1] := "Jumpluff EX"
    BatImg[10,2] := ci . "\boton_entei_ex.bmp"
    BatNom[10,2] := "Entei EX"
    BatImg[10,3] := ci . "\boton_suicune_ex.bmp"
    BatNom[10,3] := "Suicune EX"
    BatImg[10,4] := ci . "\boton_raikou_ex.bmp"
    BatNom[10,4] := "Raikou EX"
    BatImg[10,5] := ci . "\boton_latios_ex.bmp"
    BatNom[10,5] := "Latios EX"
    BatImg[10,6] := ci . "\boton_poliwrath_ex.bmp"
    BatNom[10,6] := "Poliwrath EX"

    ; Expansion 11: Deluxe EX (9 batallas)
    BatCnt[11] := 9
    BatImg[11,1] := ci . "\boton_buzzwole_decidueye.bmp"
    BatNom[11,1] := "Buzzwole Decidueye"
    BatImg[11,2] := ci . "\boton_charizard_moltres.bmp"
    BatNom[11,2] := "Charizard Moltres"
    BatImg[11,3] := ci . "\boton_palkia_articuno.bmp"
    BatNom[11,3] := "Palkia Articuno"
    BatImg[11,4] := ci . "\boton_pikachu_raichu.bmp"
    BatNom[11,4] := "Pikachu Raichu"
    BatImg[11,5] := ci . "\boton_mewtwo_mew.bmp"
    BatNom[11,5] := "Mewtwo Mew"
    BatImg[11,6] := ci . "\boton_lucario_donphan.bmp"
    BatNom[11,6] := "Lucario Donphan"
    BatImg[11,7] := ci . "\boton_guzzlord_darkrai.bmp"
    BatNom[11,7] := "Guzzlord Darkrai"
    BatImg[11,8] := ci . "\boton_solgaleo_dialga.bmp"
    BatNom[11,8] := "Solgaleo Dialga"
    BatImg[11,9] := ci . "\boton_lugia_hooh.bmp"
    BatNom[11,9] := "Lugia HoOh"
}

; ============================================================================
; FUNCIÓN: Guardar configuración en archivo INI
; ============================================================================
GuardarConfig() {
    global ArchivoConfig, Variacion, IntervaloLoop, MaxReintentos, ModoDebug
    global VentanaAncho, VentanaAlto, AutoAjustar
    global ScrollActivo, ScrollRelX, ScrollRelY, ScrollCantidad, ScrollDelay, ScrollEnPaso
    global MAX_INST, Inst_Titulo, Inst_Exp, Inst_Bat

    ; Leer valores actuales de la GUI
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

    tmpScrollEnPaso := 0
    Loop, 3 {
        if InStr(tmpScrollPaso, "Paso " . A_Index) {
            tmpScrollEnPaso := A_Index
            break
        }
    }

    ; Sección General
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

    ; Sección ADB
    GuiControlGet, tmpADB, Main:, ChkADB
    GuiControlGet, tmpADBRuta, Main:, EditADBRuta
    GuiControlGet, tmpADBPuertos, Main:, EditADBPuertos
    IniWrite, %tmpADB%, %ArchivoConfig%, ADB, Habilitado
    IniWrite, %tmpADBRuta%, %ArchivoConfig%, ADB, Ruta
    IniWrite, %tmpADBPuertos%, %ArchivoConfig%, ADB, Puertos

    ; Secciones por instancia
    Loop, %MAX_INST% {
        i := A_Index
        sec := "Instance" . i
        IniWrite, % Inst_Titulo[i], %ArchivoConfig%, %sec%, Ventana
        IniWrite, % Inst_Exp[i], %ArchivoConfig%, %sec%, Expansion
        IniWrite, % Inst_Bat[i], %ArchivoConfig%, %sec%, Batalla
    }
}

; ============================================================================
; FUNCIÓN: Cargar configuración desde archivo INI
; ============================================================================
CargarConfig() {
    global ArchivoConfig, Variacion, IntervaloLoop, MaxReintentos, ModoDebug
    global VentanaAncho, VentanaAlto, AutoAjustar
    global ScrollActivo, ScrollRelX, ScrollRelY, ScrollCantidad, ScrollDelay, ScrollEnPaso
    global MAX_INST, Inst_Titulo, Inst_Exp, Inst_Bat
    global ADB_Habilitado, ADB_Ruta, Inst_ADB_Puerto

    if !FileExist(ArchivoConfig)
        return

    IniRead, tmp, %ArchivoConfig%, General, Variacion, %Variacion%
    Variacion := tmp + 0
    IniRead, tmp, %ArchivoConfig%, General, IntervaloLoop, %IntervaloLoop%
    IntervaloLoop := tmp + 0
    IniRead, tmp, %ArchivoConfig%, General, MaxReintentos, %MaxReintentos%
    MaxReintentos := tmp + 0
    IniRead, tmp, %ArchivoConfig%, General, ModoDebug, %ModoDebug%
    ModoDebug := tmp + 0

    IniRead, tmp, %ArchivoConfig%, Ventana, VentanaAncho, %VentanaAncho%
    VentanaAncho := tmp + 0
    IniRead, tmp, %ArchivoConfig%, Ventana, VentanaAlto, %VentanaAlto%
    VentanaAlto := tmp + 0
    IniRead, tmp, %ArchivoConfig%, Ventana, AutoAjustar, %AutoAjustar%
    AutoAjustar := tmp + 0

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

    ; ADB
    IniRead, tmp, %ArchivoConfig%, ADB, Habilitado, 0
    ADB_Habilitado := tmp + 0
    IniRead, tmp, %ArchivoConfig%, ADB, Ruta, %ADB_Ruta%
    if (tmp != "ERROR" && tmp != "")
        ADB_Ruta := tmp
    IniRead, tmp, %ArchivoConfig%, ADB, Puertos,
    if (tmp != "ERROR" && tmp != "") {
        StringSplit, pArr, tmp, `,
        Loop, %MAX_INST% {
            if (A_Index <= pArr0) {
                p := RegExReplace(pArr%A_Index%, "[^0-9]", "") + 0
                Inst_ADB_Puerto[A_Index] := p
            }
        }
    }

    ; Cargar instancias
    Loop, %MAX_INST% {
        i := A_Index
        sec := "Instance" . i
        IniRead, tmp, %ArchivoConfig%, %sec%, Ventana, % ""
        Inst_Titulo[i] := tmp
        IniRead, tmp, %ArchivoConfig%, %sec%, Expansion, 1
        Inst_Exp[i] := tmp + 0
        IniRead, tmp, %ArchivoConfig%, %sec%, Batalla, 1
        Inst_Bat[i] := tmp + 0
    }
}

; ============================================================================
; FUNCIÓN: Crear la interfaz gráfica principal (Multi-Instancia)
; ============================================================================
CrearGUI() {
    global
    Gui, Main:Destroy
    Gui, Main:Font, s9, Segoe UI
    Gui, Main:Color, 1a1a2e

    ; --- SECCIÓN: INSTANCIAS ---
    Gui, Main:Font, s10 cWhite Bold
    Gui, Main:Add, GroupBox, x10 y10 w660 h260, INSTANCIAS

    Gui, Main:Font, s9 cWhite Normal
    Gui, Main:Add, Button, x520 y10 w70 h20 gAutoDetectar, Auto-Det
    Gui, Main:Add, Button, x595 y10 w70 h20 gAutoAcomodar, Acomodar

    ; Construir lista de expansiones
    listaExp := ""
    Loop, %TotalExpansiones% {
        if (listaExp != "")
            listaExp .= "|"
        listaExp .= A_Index . ": " . ExpansionNombres[A_Index]
    }

    ; Fila de cada instancia
    yBase := 35
    Loop, %MAX_INST% {
        i := A_Index
        yRow := yBase + (i - 1) * 42

        Gui, Main:Font, s9 c0x00FF88 Bold
        Gui, Main:Add, Text, x20 y%yRow% w25 h22 +0x200, #%i%

        Gui, Main:Font, s9 cWhite Normal
        ventTxt := Inst_Titulo[i] != "" ? Inst_Titulo[i] : "(sin ventana)"
        Gui, Main:Add, Edit, x45 y%yRow% w130 h22 vEditVentana%i% ReadOnly, %ventTxt%
        Gui, Main:Add, Button, x178 y%yRow% w30 h22 gDetectarVentana%i%, Det

        ; DDL Expansión
        expChoose := Inst_Exp[i] > 0 ? Inst_Exp[i] : 1
        Gui, Main:Add, DropDownList, x212 y%yRow% w160 h300 vDDLExp%i% Choose%expChoose% gCambiarExpGUI%i%, %listaExp%

        ; DDL Batalla (se llena según expansión)
        expI := Inst_Exp[i] > 0 ? Inst_Exp[i] : 1
        batCount := BatCnt[expI]
        listaBat := ""
        Loop, %batCount% {
            if (listaBat != "")
                listaBat .= "|"
            listaBat .= A_Index . ": " . BatNom[expI, A_Index]
        }
        if (listaBat = "")
            listaBat := "(sin batallas)"
        batChoose := Inst_Bat[i] > 0 && Inst_Bat[i] <= batCount ? Inst_Bat[i] : 1
        Gui, Main:Add, DropDownList, x376 y%yRow% w120 h300 vDDLBat%i% Choose%batChoose%, %listaBat%

        ; Botones control individual
        Gui, Main:Font, s9 cWhite Bold
        Gui, Main:Add, Button, x502 y%yRow% w50 h22 gIniciarInst%i%, Play
        Gui, Main:Add, Button, x555 y%yRow% w50 h22 gPausarInst%i%, Pausa
        Gui, Main:Add, Button, x608 y%yRow% w50 h22 gDetenerInst%i%, Stop
        Gui, Main:Font, s9 cWhite Normal
    }

    ; Botones globales
    yGlobal := yBase + MAX_INST * 42 + 5
    Gui, Main:Font, s9 cWhite Bold
    Gui, Main:Add, Button, x20 y%yGlobal% w200 h28 gIniciarTodos, INICIAR TODOS (F12)
    Gui, Main:Add, Button, x230 y%yGlobal% w200 h28 gPausarTodos, PAUSAR TODOS
    Gui, Main:Add, Button, x440 y%yGlobal% w220 h28 gDetenerTodos, DETENER TODOS (F11)

    ; --- SECCIÓN: CONFIGURACIÓN ---
    yConf := 280
    Gui, Main:Font, s10 cWhite Bold
    Gui, Main:Add, GroupBox, x10 y%yConf% w660 h70, CONFIGURACION

    yConfR := yConf + 25
    Gui, Main:Font, s9 cSilver Normal
    Gui, Main:Add, Text, x25 y%yConfR%, Var:
    Gui, Main:Add, Edit, x50 y%yConfR% w45 h22 vEditVariacion, %Variacion%
    Gui, Main:Add, UpDown, Range0-255, %Variacion%
    Gui, Main:Add, Text, x105 y%yConfR%, Int(ms):
    Gui, Main:Add, Edit, x155 y%yConfR% w60 h22 vEditIntervalo, %IntervaloLoop%
    Gui, Main:Add, UpDown, Range100-10000, %IntervaloLoop%
    Gui, Main:Add, Text, x225 y%yConfR%, Rein:
    Gui, Main:Add, Edit, x260 y%yConfR% w40 h22 vEditReintentos, %MaxReintentos%
    Gui, Main:Add, UpDown, Range1-50, %MaxReintentos%
    chkDebugVal := ModoDebug ? "Checked" : ""
    Gui, Main:Add, CheckBox, x315 y%yConfR% vChkDebug %chkDebugVal% cWhite, Debug

    Gui, Main:Add, Text, x385 y%yConfR%, Res:
    Gui, Main:Add, Edit, x415 y%yConfR% w50 h22 vEditVentanaAncho, %VentanaAncho%
    Gui, Main:Add, Text, x468 y%yConfR%, x
    Gui, Main:Add, Edit, x480 y%yConfR% w50 h22 vEditVentanaAlto, %VentanaAlto%
    chkAutoVal := AutoAjustar ? "Checked" : ""
    Gui, Main:Add, CheckBox, x545 y%yConfR% vChkAutoAjustar %chkAutoVal% cWhite, Auto-aj

    ; --- SECCIÓN: SCROLL ---
    yScroll := 360
    Gui, Main:Font, s10 cWhite Bold
    Gui, Main:Add, GroupBox, x10 y%yScroll% w660 h80, SWIPE AUTOMATICO

    ySR := yScroll + 25
    Gui, Main:Font, s9 cSilver Normal
    chkScrollVal := ScrollActivo ? "Checked" : ""
    Gui, Main:Add, CheckBox, x25 y%ySR% vChkScroll %chkScrollVal% cWhite, Swipe
    Gui, Main:Add, Text, x90 y%ySR%, X:
    Gui, Main:Add, Edit, x105 y%ySR% w45 h22 vEditScrollX, %ScrollRelX%
    Gui, Main:Add, Text, x158 y%ySR%, Y:
    Gui, Main:Add, Edit, x172 y%ySR% w45 h22 vEditScrollY, %ScrollRelY%
    Gui, Main:Add, Text, x225 y%ySR%, Fz:
    Gui, Main:Add, Edit, x245 y%ySR% w35 h22 vEditScrollCant, %ScrollCantidad%
    Gui, Main:Add, UpDown, Range1-20, %ScrollCantidad%
    Gui, Main:Add, Text, x290 y%ySR%, Dl(ms):
    Gui, Main:Add, Edit, x335 y%ySR% w50 h22 vEditScrollDelay, %ScrollDelay%
    Gui, Main:Add, UpDown, Range100-3000, %ScrollDelay%

    scrollPasoIndice := ScrollEnPaso + 1
    Gui, Main:Add, Text, x395 y%ySR%, En:
    Gui, Main:Add, DropDownList, x415 y%ySR% w140 vDDLScrollPaso Choose%scrollPasoIndice%, Todos|Paso 1: Nivel|Paso 2: Auto|Paso 3: Iniciar

    ySR2 := ySR + 28
    Gui, Main:Font, s9 cWhite Normal
    Gui, Main:Add, Button, x25 y%ySR2% w180 h22 gSeleccionarPuntoScroll, Seleccionar Punto (clic)
    Gui, Main:Add, Button, x215 y%ySR2% w180 h22 gProbarScroll, Probar Swipe

    ; --- SECCIÓN: ADB ---
    yADB := 450
    Gui, Main:Font, s10 cWhite Bold
    Gui, Main:Add, GroupBox, x10 y%yADB% w660 h55, ADB (CLICKS DIRECTOS POR INSTANCIA)

    yAR := yADB + 22
    Gui, Main:Font, s9 cSilver Normal
    chkADBVal := ADB_Habilitado ? "Checked" : ""
    Gui, Main:Add, CheckBox, x25 y%yAR% vChkADB %chkADBVal% cWhite gToggleADB, ADB
    Gui, Main:Add, Text, x80 y%yAR%, Ruta:
    Gui, Main:Add, Edit, x110 y%yAR% w310 h22 vEditADBRuta, %ADB_Ruta%
    Gui, Main:Add, Button, x425 y%yAR% w80 h22 gDetectarADBBtn, Detectar
    Gui, Main:Add, Text, x515 y%yAR%, Puertos:
    ; Puertos de cada instancia (separados por coma)
    puertosStr := ""
    Loop, %MAX_INST% {
        p := Inst_ADB_Puerto[A_Index]
        if (p = "" || p = 0)
            p := 16384 + (A_Index - 1) * 32
        if (A_Index > 1)
            puertosStr .= ","
        puertosStr .= p
    }
    Gui, Main:Add, Edit, x568 y%yAR% w95 h22 vEditADBPuertos, %puertosStr%

    ; --- SECCIÓN: ESTADO (5 líneas) ---
    yEst := 515
    Gui, Main:Font, s10 cWhite Bold
    Gui, Main:Add, GroupBox, x10 y%yEst% w660 h130, ESTADO

    Gui, Main:Font, s9 c0x00FF88 Normal, Consolas
    Loop, %MAX_INST% {
        i := A_Index
        yEstR := yEst + 20 + (i - 1) * 20
        Gui, Main:Add, Text, x25 y%yEstR% w630 h18 vTextoEstado%i%, #%i%: IDLE
    }

    ; --- SECCIÓN: LOG ---
    yLog := 655
    Gui, Main:Font, s10 cWhite Bold
    Gui, Main:Add, GroupBox, x10 y%yLog% w660 h200, LOG

    yLogE := yLog + 22
    Gui, Main:Font, s8 c0x00FF88 Normal, Consolas
    Gui, Main:Add, Edit, x25 y%yLogE% w635 h168 vLogText ReadOnly Multi VScroll HScroll -Wrap BackgroundBlack,

    ; --- Mostrar ventana ---
    Gui, Main:Show, w680 h870, Game Bot - Multi-Instancia (5)
    Log("=== Game Bot Multi-Instancia iniciado ===")
    Log("F12: Iniciar/Pausar todos | F11: Detener todos | F10: Reload")
}

; ============================================================================
; FUNCIÓN: Log con buffer (se flushea al final de cada tick)
; ============================================================================
Log(mensaje) {
    global ModoDebug, LogBuffer
    if (!ModoDebug)
        return
    FormatTime, hora,, HH:mm:ss
    LogBuffer .= "[" . hora . "] " . mensaje . "`r`n"
}

LogI(i, mensaje) {
    global ModoDebug, LogBuffer
    if (!ModoDebug)
        return
    FormatTime, hora,, HH:mm:ss
    LogBuffer .= "[" . hora . "][#" . i . "] " . mensaje . "`r`n"
}

FlushLog() {
    global LogBuffer, LogCharCount
    if (LogBuffer = "")
        return

    buf := LogBuffer
    LogBuffer := ""
    LogCharCount += StrLen(buf)

    ; Obtener HWND del control de log
    GuiControlGet, hLogCtrl, Main:Hwnd, LogText

    ; Si el log es muy largo, truncar reseteando todo
    if (LogCharCount > 30000) {
        GuiControlGet, contenido, Main:, LogText
        pos := InStr(contenido, "`n",, StrLen(contenido) // 2)
        if (pos > 0)
            contenido := "... (log recortado) ...`r`n" . SubStr(contenido, pos + 1)
        GuiControl, Main:, LogText, %contenido%
        LogCharCount := StrLen(contenido)
    }

    ; Append-only: mover cursor al final y usar EM_REPLACESEL (más rápido)
    SendMessage, 0x000E, 0, 0,, ahk_id %hLogCtrl%  ; WM_GETTEXTLENGTH
    len := ErrorLevel
    SendMessage, 0x00B1, %len%, %len%,, ahk_id %hLogCtrl%  ; EM_SETSEL (end,end)
    VarSetCapacity(bufW, StrLen(buf) * 2 + 2, 0)
    StrPut(buf, &bufW, "UTF-16")
    SendMessage, 0x00C2, 0, &bufW,, ahk_id %hLogCtrl%  ; EM_REPLACESEL

    ; Auto-scroll al final
    SendMessage, 0x0115, 7, 0,, ahk_id %hLogCtrl%
}

; ============================================================================
; FUNCIÓN: Actualizar estado de una instancia en la GUI
; ============================================================================
ActualizarEstadoInst(i) {
    global Inst_Activo, Inst_Pausado, Inst_Estado, Inst_Ciclos, Inst_Ataques, Inst_Errores, Inst_RecuperacionTotal

    if (!Inst_Activo[i])
        estado := "IDLE"
    else if (Inst_Pausado[i])
        estado := "PAUSADO"
    else
        estado := Inst_Estado[i]

    texto := "#" . i . ": " . estado . "  | C:" . Inst_Ciclos[i] . " A:" . Inst_Ataques[i] . " E:" . Inst_Errores[i] . " R:" . Inst_RecuperacionTotal[i]
    GuiControl, Main:, TextoEstado%i%, %texto%
}

; ============================================================================
; FUNCIÓN: Obtener dimensiones de imagen (con cache)
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

ObtenerDimensionesImagenCached(ruta, ByRef w, ByRef h) {
    global ImgDimCache
    if (ImgDimCache.HasKey(ruta)) {
        w := ImgDimCache[ruta].w
        h := ImgDimCache[ruta].h
        return
    }
    ObtenerDimensionesImagen(ruta, w, h)
    ImgDimCache[ruta] := {w: w, h: h}
}

; ============================================================================
; FUNCIÓN: Buscar imagen en ventana por HWND
; ============================================================================
ArchivoExiste(ruta) {
    global FileExistCache
    if (FileExistCache.HasKey(ruta))
        return FileExistCache[ruta]
    existe := FileExist(ruta) ? true : false
    FileExistCache[ruta] := existe
    return existe
}

BuscarImagenEnVentana(hwnd, ByRef rutaImagen, ByRef foundX, ByRef foundY) {
    global Variacion

    if !ArchivoExiste(rutaImagen)
        return false

    WinGetPos, wx, wy, ww, wh, ahk_id %hwnd%
    if (ww = 0 || wh = 0)
        return false

    x1 := wx
    y1 := wy
    x2 := wx + ww
    y2 := wy + wh

    ImageSearch, foundX, foundY, %x1%, %y1%, %x2%, %y2%, *%Variacion% %rutaImagen%

    if (ErrorLevel = 0) {
        ObtenerDimensionesImagenCached(rutaImagen, imgW, imgH)
        if (imgW > 0 && imgH > 0) {
            ; Calcular centro de la imagen encontrada
            centroX := foundX + (imgW // 2)
            centroY := foundY + (imgH // 2)
        } else {
            centroX := foundX
            centroY := foundY
        }

        ; Validar que el pixel encontrado pertenece a ESTA ventana
        ; y no a otra ventana que se superpone encima
        pt := (centroY << 32) | (centroX & 0xFFFFFFFF)
        hwndEnPunto := DllCall("WindowFromPoint", "Int64", pt, "Ptr")
        hwndRaiz := DllCall("GetAncestor", "Ptr", hwndEnPunto, "UInt", 2, "Ptr")  ; GA_ROOT=2
        if (hwndRaiz + 0 != hwnd + 0) {
            ; La imagen encontrada pertenece a otra ventana superpuesta
            return false
        }

        foundX := centroX
        foundY := centroY
        return true
    }
    return false
}

; ============================================================================
; FUNCIÓN: Auto-detectar ruta de ADB
; ============================================================================
DetectarADB() {
    global ADB_Ruta

    ; Intentar rutas comunes de MuMu Player 12
    rutas := []
    rutas.Push("C:\Program Files\Netease\MuMuPlayer-12.0\shell\adb.exe")
    rutas.Push("D:\Program Files\Netease\MuMuPlayer-12.0\shell\adb.exe")
    rutas.Push("C:\Program Files\Netease\MuMu Player 12\shell\adb.exe")
    rutas.Push("D:\Program Files\Netease\MuMu Player 12\shell\adb.exe")
    ; MuMu Player Pro
    rutas.Push("C:\Program Files\Netease\MuMuPlayerPro-3.0\shell\adb.exe")
    rutas.Push("D:\Program Files\Netease\MuMuPlayerPro-3.0\shell\adb.exe")
    ; MuMu antiguo
    rutas.Push("C:\Program Files\MuMu\emulator\nemu\vmonitor\bin\adb_server.exe")
    rutas.Push("D:\Program Files\MuMu\emulator\nemu\vmonitor\bin\adb_server.exe")
    ; ADB genérico en PATH
    rutas.Push("adb.exe")

    for _, ruta in rutas {
        if (FileExist(ruta)) {
            ADB_Ruta := ruta
            return true
        }
    }
    ; Intentar adb en PATH del sistema
    RunWait, %ComSpec% /c "where adb.exe > ""%A_Temp%\adb_check.txt"" 2>NUL",, Hide
    FileRead, adbPath, %A_Temp%\adb_check.txt
    FileDelete, %A_Temp%\adb_check.txt
    adbPath := Trim(adbPath, " `t`r`n")
    if (adbPath != "" && FileExist(adbPath)) {
        ADB_Ruta := adbPath
        return true
    }
    return false
}

; ============================================================================
; FUNCIÓN: Conectar ADB a una instancia
; ============================================================================
ADB_Conectar(i) {
    global
    puerto := Inst_ADB_Puerto[i]
    if (puerto = 0 || puerto = "")
        return false

    device := "127.0.0.1:" . puerto
    Inst_ADB_Device[i] := device

    ; Archivos temporales únicos por instancia
    tmpConn := A_Temp . "\adb_conn_" . i . ".txt"
    tmpSize := A_Temp . "\adb_size_" . i . ".txt"

    ; Conectar
    cmd := """" . ADB_Ruta . """ connect " . device
    RunWait, %ComSpec% /c "%cmd% > ""%tmpConn%"" 2>&1",, Hide
    FileRead, salida, %tmpConn%
    FileDelete, %tmpConn%

    if (InStr(salida, "connected") || InStr(salida, "already")) {
        Inst_ADB_Conectado[i] := true

        ; Obtener resolución interna del Android
        cmdSize := """" . ADB_Ruta . """ -s " . device . " shell wm size"
        RunWait, %ComSpec% /c "%cmdSize% > ""%tmpSize%"" 2>&1",, Hide
        FileRead, salidaSize, %tmpSize%
        FileDelete, %tmpSize%
        ; Formato: "Physical size: 960x540"
        if (RegExMatch(salidaSize, "(\d+)x(\d+)", m)) {
            Inst_ADB_Res[i] := {w: m1 + 0, h: m2 + 0}
            LogI(i, "ADB conectado: " . device . " (" . m1 . "x" . m2 . ")")
        } else {
            Inst_ADB_Res[i] := {w: 0, h: 0}
            LogI(i, "ADB conectado: " . device . " (resolución desconocida)")
        }
        return true
    }

    Inst_ADB_Conectado[i] := false
    LogI(i, "ADB error conectando a " . device . ": " . salida)
    return false
}

; ============================================================================
; FUNCIÓN: Ejecutar comando ADB (Run directo, sin cmd.exe, oculto)
; ============================================================================
ADB_Cmd(i, comando) {
    global ADB_Ruta
    device := Inst_ADB_Device[i]
    if (device = "" || ADB_Ruta = "")
        return
    Run, "%ADB_Ruta%" -s %device% shell %comando%,, Hide
}

; ============================================================================
; FUNCIÓN: Obtener el offset del área cliente respecto a la ventana
; La barra de título de MuMu hace que WinGetPos devuelva un tamaño mayor
; que el área de renderizado Android. Necesitamos el offset para mapear
; coordenadas de ventana a coordenadas Android correctamente.
; ============================================================================
GetClientOffset(hwnd, ByRef offsetX, ByRef offsetY, ByRef clientW, ByRef clientH) {
    ; Obtener posición de la ventana completa
    WinGetPos, wx, wy, ww, wh, ahk_id %hwnd%

    ; Obtener tamaño del área cliente (sin barra de título ni bordes)
    VarSetCapacity(rect, 16, 0)
    DllCall("GetClientRect", "Ptr", hwnd, "Ptr", &rect)
    clientW := NumGet(rect, 8, "Int")   ; right
    clientH := NumGet(rect, 12, "Int")  ; bottom

    ; Obtener posición del área cliente en coordenadas de pantalla
    VarSetCapacity(pt, 8, 0)
    NumPut(0, pt, 0, "Int")
    NumPut(0, pt, 4, "Int")
    DllCall("ClientToScreen", "Ptr", hwnd, "Ptr", &pt)
    clientScreenX := NumGet(pt, 0, "Int")
    clientScreenY := NumGet(pt, 4, "Int")

    ; Offset = diferencia entre esquina superior de ventana y esquina del área cliente
    offsetX := clientScreenX - wx
    offsetY := clientScreenY - wy
}

; ============================================================================
; FUNCIÓN: Tap ADB (coordenadas relativas a la ventana → Android)
; Mapea usando el ÁREA CLIENTE (sin barra de título) para precisión
; ============================================================================
ADB_Tap(i, relX, relY) {
    global
    res := Inst_ADB_Res[i]
    hwnd := Inst_Hwnd[i]

    ; relX/relY son coordenadas relativas a la ventana completa (WinGetPos).
    ; Necesitamos convertirlas a coordenadas Android.
    ;
    ; La ventana de MuMu puede tener:
    ;   - Barra de título del OS (detectada por GetClientRect)
    ;   - Toolbar interna de MuMu (NO detectada por GetClientRect, está dentro del cliente)
    ;
    ; Para calcular el offset total, comparamos el tamaño del cliente con la
    ; resolución Android. Si clientH > res.h (ajustado por proporción), hay
    ; espacio extra (toolbar interna) que debemos contabilizar.

    GetClientOffset(hwnd, offsetX, offsetY, clientW, clientH)

    ; Paso 1: Convertir de coordenadas de ventana a coordenadas de área cliente
    cX := relX - offsetX
    cY := relY - offsetY

    if (clientW > 0 && clientH > 0 && res.w > 0 && res.h > 0) {
        ; Paso 2: Detectar toolbar interna de MuMu
        ; Si Android es 960x540 (16:9) y el cliente es 960x570, hay 30px de toolbar
        ; Calcular la altura que el juego DEBERÍA ocupar según la proporción Android
        juegoW := clientW
        juegoH := Round(clientW * res.h / res.w)  ; altura proporcional al ancho

        ; Si el cliente es más alto que el juego, hay toolbar interna
        toolbarInterna := 0
        if (clientH > juegoH)
            toolbarInterna := clientH - juegoH

        ; La posición dentro del área de juego (sin toolbar)
        gameY := cY - toolbarInterna

        adbX := Round(cX * res.w / juegoW)
        adbY := Round(gameY * res.h / juegoH)
    } else {
        adbX := cX
        adbY := cY
    }

    if (adbX < 0)
        adbX := 0
    if (adbY < 0)
        adbY := 0

    ADB_Cmd(i, "input tap " . adbX . " " . adbY)
}

; ============================================================================
; FUNCIÓN: Swipe ADB (no-bloqueante)
; ============================================================================
ADB_Swipe(i, relX, relYInicio, relYFin, duracionMs := 500) {
    global
    res := Inst_ADB_Res[i]
    hwnd := Inst_Hwnd[i]

    ; Mismo cálculo que ADB_Tap: ventana → cliente → juego → Android
    GetClientOffset(hwnd, offsetX, offsetY, clientW, clientH)

    cX := relX - offsetX
    cYI := relYInicio - offsetY
    cYF := relYFin - offsetY

    if (clientW > 0 && clientH > 0 && res.w > 0 && res.h > 0) {
        juegoW := clientW
        juegoH := Round(clientW * res.h / res.w)
        toolbarInterna := 0
        if (clientH > juegoH)
            toolbarInterna := clientH - juegoH

        gameYI := cYI - toolbarInterna
        gameYF := cYF - toolbarInterna

        adbX := Round(cX * res.w / juegoW)
        adbYI := Round(gameYI * res.h / juegoH)
        adbYF := Round(gameYF * res.h / juegoH)
    } else {
        adbX := cX
        adbYI := cYI
        adbYF := cYF
    }

    if (adbX < 0)
        adbX := 0
    if (adbYI < 0)
        adbYI := 0
    if (adbYF < 0)
        adbYF := 0

    ADB_Cmd(i, "input swipe " . adbX . " " . adbYI . " " . adbX . " " . adbYF . " " . duracionMs)
}

; ============================================================================
; FUNCIÓN: Hacer clic en ventana por HWND (con soporte ADB)
; ============================================================================
HacerClicEnVentana(hwnd, screenX, screenY, instancia := 0) {
    global ADB_Habilitado
    WinGetPos, wx, wy,,, ahk_id %hwnd%
    relX := screenX - wx
    relY := screenY - wy

    ; Si ADB está habilitado y la instancia está conectada, usar ADB
    if (ADB_Habilitado && instancia > 0 && Inst_ADB_Conectado[instancia]) {
        ADB_Tap(instancia, relX, relY)
        return
    }

    ; Fallback: ControlClick (funciona con MuMu sin ADB)
    ControlClick, x%relX% y%relY%, ahk_id %hwnd%,, Left, 1, NA

    if (ErrorLevel) {
        lParam := (relY << 16) | (relX & 0xFFFF)
        PostMessage, 0x201, 0x0001, %lParam%,, ahk_id %hwnd%
        Sleep, 50
        PostMessage, 0x202, 0x0000, %lParam%,, ahk_id %hwnd%
    }
}

; ============================================================================
; FUNCIÓN: Iniciar swipe NO-BLOQUEANTE en ventana por HWND
; En vez de hacer todo el scroll con Sleeps, programa la máquina de estados
; para que ProcesarScroll() avance unos pasos cada tick del timer.
; repeticiones: cuántas veces repetir el scroll (para scroll inverso grande)
; imgPostScroll: ruta de imagen a buscar después del scroll ("" = ninguna)
; ============================================================================
IniciarScroll(i, hwnd, relX, relY, cantidad, repeticiones := 1, imgPostScroll := "") {
    global

    if (!hwnd)
        return

    Inst_ScrollRepetir[i] := repeticiones
    Inst_ScrollCantidad[i] := cantidad
    Inst_ScrollRelX[i] := relX
    Inst_ScrollRelY[i] := relY
    Inst_ScrollPostImg[i] := imgPostScroll

    ; Si ADB está habilitado, usar ADB swipe
    if (ADB_Habilitado && Inst_ADB_Conectado[i]) {
        distancia := cantidad * 40
        yInicio := relY + (distancia // 2)
        yFin := relY - (distancia // 2)
        if (yInicio < 10)
            yInicio := 10
        if (yFin < 10)
            yFin := 10

        ; Duración proporcional a la distancia para un swipe suave
        duracion := Abs(distancia) * 8
        if (duracion < 300)
            duracion := 300
        if (duracion > 1500)
            duracion := 1500

        ; Ejecutar 1 solo swipe ahora
        ADB_Swipe(i, relX, yInicio, yFin, duracion)

        ; Calcular ticks de espera proporcionales a la duración del swipe
        intervaloActual := RR_Intervalo > 0 ? RR_Intervalo : IntervaloLoop
        ticksEspera := Ceil(duracion / intervaloActual) + 1

        ; Si hay repeticiones, usar la máquina de estados para las restantes
        if (repeticiones > 1) {
            Inst_ScrollActivo[i] := true
            Inst_ScrollFase[i] := 4  ; fase especial: ADB multi-swipe
            Inst_ScrollHwndTarget[i] := hwnd
            Inst_ScrollRepetir[i] := repeticiones - 1  ; ya hicimos 1
            Inst_SkipTick[i] := ticksEspera
        } else if (imgPostScroll != "") {
            ; Solo 1 swipe + búsqueda post-scroll
            Inst_ScrollActivo[i] := true
            Inst_ScrollFase[i] := 3  ; ir a fase búsqueda
            Inst_ScrollHwndTarget[i] := hwnd
            Inst_SkipTick[i] := ticksEspera
        } else {
            ; Solo 1 swipe sin búsqueda: esperar a que termine
            Inst_SkipTick[i] := ticksEspera
        }
        return
    }

    ; Fallback: scroll por mensajes Windows
    _IniciarScrollUnico(i, hwnd, relX, relY, cantidad)
}

; Helper interno: prepara un solo scroll
_IniciarScrollUnico(i, hwnd, relX, relY, cantidad) {
    global

    distancia := cantidad * 40
    yInicio := relY + (distancia // 2)
    yFin := relY - (distancia // 2)
    if (yInicio < 10)
        yInicio := 10
    if (yFin < 10)
        yFin := 10

    pointVal := ((relY & 0xFFFFFFFF) << 32) | (relX & 0xFFFFFFFF)
    hwndHijo := DllCall("RealChildWindowFromPoint", "Ptr", hwnd, "Int64", pointVal, "Ptr")

    if (hwndHijo && hwndHijo != hwnd) {
        hwndTarget := hwndHijo
        VarSetCapacity(ptInicio, 8, 0)
        NumPut(relX, ptInicio, 0, "Int")
        NumPut(yInicio, ptInicio, 4, "Int")
        DllCall("MapWindowPoints", "Ptr", hwnd, "Ptr", hwndHijo, "Ptr", &ptInicio, "UInt", 1)
        childX := NumGet(ptInicio, 0, "Int")
        childYInicio := NumGet(ptInicio, 4, "Int")

        VarSetCapacity(ptFin, 8, 0)
        NumPut(relX, ptFin, 0, "Int")
        NumPut(yFin, ptFin, 4, "Int")
        DllCall("MapWindowPoints", "Ptr", hwnd, "Ptr", hwndHijo, "Ptr", &ptFin, "UInt", 1)
        childYFin := NumGet(ptFin, 4, "Int")
    } else {
        hwndTarget := hwnd
        childX := relX
        childYInicio := yInicio
        childYFin := yFin
    }

    totalDist := Abs(childYInicio - childYFin)
    pasoSize := 8
    pasos := totalDist // pasoSize
    if (pasos < 1)
        pasos := 1
    direccion := (childYInicio > childYFin) ? -1 : 1

    ; Enviar WM_LBUTTONDOWN (inicio del arrastre) - PostMessage no bloquea
    lParamDown := ((childYInicio & 0xFFFF) << 16) | (childX & 0xFFFF)
    PostMessage, 0x201, 0x0001, %lParamDown%,, ahk_id %hwndTarget%

    ; Guardar estado para que ProcesarScroll avance
    Inst_ScrollActivo[i] := true
    Inst_ScrollHwndTarget[i] := hwndTarget
    Inst_ScrollChildX[i] := childX
    Inst_ScrollYActual[i] := childYInicio
    Inst_ScrollYFin[i] := childYFin
    Inst_ScrollDir[i] := direccion
    Inst_ScrollPasoSize[i] := pasoSize
    Inst_ScrollPasos[i] := pasos
    Inst_ScrollFase[i] := 1  ; fase arrastrando
}

; ============================================================================
; FUNCIÓN: Procesar scroll no-bloqueante (llamar desde el loop principal)
; Avanza varios pasos de arrastre por tick sin Sleep. Retorna:
;   0 = scroll aún en curso
;   1 = scroll terminado (sin búsqueda post-scroll)
;   2 = scroll terminado + imagen post-scroll encontrada
;  -1 = scroll terminado + imagen post-scroll NO encontrada
; ============================================================================
ProcesarScroll(i) {
    global

    if (!Inst_ScrollActivo[i])
        return 1

    hwndTarget := Inst_ScrollHwndTarget[i]
    childX := Inst_ScrollChildX[i]
    fase := Inst_ScrollFase[i]

    ; FASE 1: Avanzar arrastre (enviar varios WM_MOUSEMOVE por tick)
    if (fase = 1) {
        pasosRestantes := Inst_ScrollPasos[i]
        pasoSize := Inst_ScrollPasoSize[i]
        dir := Inst_ScrollDir[i]
        yFin := Inst_ScrollYFin[i]

        ; Enviar hasta 10 pasos de movimiento por tick (no bloqueante)
        pasosPorTick := 10
        if (pasosPorTick > pasosRestantes)
            pasosPorTick := pasosRestantes

        Loop, %pasosPorTick% {
            Inst_ScrollYActual[i] := Inst_ScrollYActual[i] + (pasoSize * dir)
            yActual := Inst_ScrollYActual[i]
            if (dir = -1) {
                if (yActual < yFin)
                    yActual := yFin
            } else {
                if (yActual > yFin)
                    yActual := yFin
            }
            Inst_ScrollYActual[i] := yActual
            lParam := ((yActual & 0xFFFF) << 16) | (childX & 0xFFFF)
            PostMessage, 0x200, 0x0001, %lParam%,, ahk_id %hwndTarget%
        }

        Inst_ScrollPasos[i] := pasosRestantes - pasosPorTick
        if (Inst_ScrollPasos[i] <= 0)
            Inst_ScrollFase[i] := 2  ; siguiente tick: soltar
        return 0
    }

    ; FASE 2: Soltar (WM_LBUTTONUP)
    if (fase = 2) {
        yFin := Inst_ScrollYFin[i]
        lParamUp := ((yFin & 0xFFFF) << 16) | (childX & 0xFFFF)
        PostMessage, 0x202, 0x0000, %lParamUp%,, ahk_id %hwndTarget%

        ; ¿Hay más repeticiones? (para scroll inverso grande)
        Inst_ScrollRepetir[i] := Inst_ScrollRepetir[i] - 1
        if (Inst_ScrollRepetir[i] > 0) {
            ; Iniciar siguiente repetición
            hwnd := Inst_Hwnd[i]
            _IniciarScrollUnico(i, hwnd, Inst_ScrollRelX[i], Inst_ScrollRelY[i], Inst_ScrollCantidad[i])
            return 0
        }

        ; ¿Hay imagen post-scroll para buscar?
        if (Inst_ScrollPostImg[i] != "") {
            Inst_ScrollFase[i] := 3  ; siguiente tick: buscar imagen
            return 0
        }

        ; Terminado sin búsqueda
        Inst_ScrollActivo[i] := false
        Inst_ScrollFase[i] := 0
        return 1
    }

    ; FASE 3: Buscar imagen post-scroll
    if (fase = 3) {
        Inst_ScrollActivo[i] := false
        Inst_ScrollFase[i] := 0

        hwnd := Inst_Hwnd[i]
        imgBuscar := Inst_ScrollPostImg[i]
        foundX := 0
        foundY := 0
        if (BuscarImagenEnVentana(hwnd, imgBuscar, foundX, foundY)) {
            Inst_ScrollPostImg[i] := ""
            return 2  ; encontrada - quien llama debe usar foundX/foundY de la instancia
        }
        Inst_ScrollPostImg[i] := ""
        return -1  ; no encontrada
    }

    ; FASE 4: ADB multi-swipe (repeticiones restantes, 1 por tick)
    if (fase = 4) {
        ; Ejecutar 1 swipe ADB
        cantidad := Inst_ScrollCantidad[i]
        relX := Inst_ScrollRelX[i]
        relY := Inst_ScrollRelY[i]
        distancia := cantidad * 40
        yInicio := relY + (distancia // 2)
        yFin := relY - (distancia // 2)
        if (yInicio < 10)
            yInicio := 10
        if (yFin < 10)
            yFin := 10

        ; Duración proporcional a la distancia
        duracion := Abs(distancia) * 8
        if (duracion < 300)
            duracion := 300
        if (duracion > 1500)
            duracion := 1500

        ADB_Swipe(i, relX, yInicio, yFin, duracion)

        ; Esperar proporcionalmente a la duración del swipe
        intervaloActual := RR_Intervalo > 0 ? RR_Intervalo : IntervaloLoop
        ticksEspera := Ceil(duracion / intervaloActual) + 1

        Inst_ScrollRepetir[i] := Inst_ScrollRepetir[i] - 1
        if (Inst_ScrollRepetir[i] <= 0) {
            ; Todas las repeticiones hechas
            imgPostScroll := Inst_ScrollPostImg[i]
            if (imgPostScroll != "") {
                Inst_ScrollFase[i] := 3  ; buscar imagen
                Inst_SkipTick[i] := ticksEspera
            } else {
                Inst_ScrollActivo[i] := false
                Inst_ScrollFase[i] := 0
                return 1
            }
        } else {
            Inst_SkipTick[i] := ticksEspera
        }
        return 0
    }

    ; Estado inválido - resetear
    Inst_ScrollActivo[i] := false
    Inst_ScrollFase[i] := 0
    return 1
}

; ============================================================================
; FUNCIÓN: Hacer swipe BLOQUEANTE (solo para pruebas de GUI / "Probar Swipe")
; ============================================================================
HacerScrollEnVentana(hwnd, relX, relY, cantidad) {
    distancia := cantidad * 40
    yInicio := relY + (distancia // 2)
    yFin := relY - (distancia // 2)
    if (yInicio < 10)
        yInicio := 10
    if (yFin < 10)
        yFin := 10

    if (!hwnd)
        return

    pointVal := ((relY & 0xFFFFFFFF) << 32) | (relX & 0xFFFFFFFF)
    hwndHijo := DllCall("RealChildWindowFromPoint", "Ptr", hwnd, "Int64", pointVal, "Ptr")

    if (hwndHijo && hwndHijo != hwnd) {
        hwndTarget := hwndHijo
        VarSetCapacity(ptInicio, 8, 0)
        NumPut(relX, ptInicio, 0, "Int")
        NumPut(yInicio, ptInicio, 4, "Int")
        DllCall("MapWindowPoints", "Ptr", hwnd, "Ptr", hwndHijo, "Ptr", &ptInicio, "UInt", 1)
        childX := NumGet(ptInicio, 0, "Int")
        childYInicio := NumGet(ptInicio, 4, "Int")

        VarSetCapacity(ptFin, 8, 0)
        NumPut(relX, ptFin, 0, "Int")
        NumPut(yFin, ptFin, 4, "Int")
        DllCall("MapWindowPoints", "Ptr", hwnd, "Ptr", hwndHijo, "Ptr", &ptFin, "UInt", 1)
        childYFin := NumGet(ptFin, 4, "Int")
    } else {
        hwndTarget := hwnd
        childX := relX
        childYInicio := yInicio
        childYFin := yFin
    }

    lParamDown := ((childYInicio & 0xFFFF) << 16) | (childX & 0xFFFF)
    PostMessage, 0x201, 0x0001, %lParamDown%,, ahk_id %hwndTarget%
    Sleep, 50

    totalDist := Abs(childYInicio - childYFin)
    pasoSize := 8
    pasos := totalDist // pasoSize
    if (pasos < 1)
        pasos := 1
    direccion := (childYInicio > childYFin) ? -1 : 1

    Loop, %pasos% {
        yActual := childYInicio + (A_Index * pasoSize * direccion)
        if (direccion = -1) {
            if (yActual < childYFin)
                yActual := childYFin
        } else {
            if (yActual > childYFin)
                yActual := childYFin
        }
        lParam := ((yActual & 0xFFFF) << 16) | (childX & 0xFFFF)
        PostMessage, 0x200, 0x0001, %lParam%,, ahk_id %hwndTarget%
        Sleep, 15
    }

    Sleep, 30
    lParamUp := ((childYFin & 0xFFFF) << 16) | (childX & 0xFFFF)
    PostMessage, 0x202, 0x0000, %lParamUp%,, ahk_id %hwndTarget%
    Sleep, 50
}

; ============================================================================
; HOTKEYS GLOBALES
; ============================================================================
F12::
    GoSub, IniciarTodos
return

F11::
    GoSub, DetenerTodos
return

F10::
    Reload
return

; ============================================================================
; LABELS: Control GLOBAL (Iniciar/Pausar/Detener TODOS)
; ============================================================================
IniciarTodos:
    LeerConfigGUI()

    algunoIniciado := false
    Loop, %MAX_INST% {
        i := A_Index
        if (Inst_Hwnd[i] = 0 || !WinExist("ahk_id " . Inst_Hwnd[i]))
            continue

        if (!Inst_Activo[i]) {
            LeerDDLsInstancia(i)
            AutoAjustarVentana(i)
            ResetInstancia(i)
            LogI(i, "=== INICIADO === Exp:" . Inst_Exp[i] . " Bat:" . Inst_Bat[i] . " (" . BatNom[Inst_Exp[i], Inst_Bat[i]] . ")")
            algunoIniciado := true
        } else if (Inst_Pausado[i]) {
            Inst_Pausado[i] := false
            LogI(i, "=== REANUDADO ===")
            algunoIniciado := true
        }
        ActualizarEstadoInst(i)
    }

    ; Conectar ADB si está habilitado
    if (ADB_Habilitado && algunoIniciado) {
        Loop, %MAX_INST% {
            if (Inst_Activo[A_Index] && !Inst_ADB_Conectado[A_Index])
                ADB_Conectar(A_Index)
        }
    }

    if (algunoIniciado) {
        ; Round-robin: timer más rápido para que cada instancia sea atendida frecuentemente
        activos := 0
        Loop, %MAX_INST% {
            if (Inst_Activo[A_Index] && !Inst_Pausado[A_Index])
                activos := activos + 1
        }
        if (activos < 1)
            activos := 1
        rrIntervalo := IntervaloLoop // activos
        if (rrIntervalo < 50)
            rrIntervalo := 50
        RR_Intervalo := rrIntervalo
        SetTimer, LoopPrincipal, %rrIntervalo%
        Log(">>> Timer round-robin activo cada " . rrIntervalo . "ms (" . activos . " instancias, base " . IntervaloLoop . "ms)")
    } else {
        Log("AVISO: No hay instancias con ventana asignada para iniciar")
    }
    FlushLog()
return

PausarTodos:
    Loop, %MAX_INST% {
        i := A_Index
        if (Inst_Activo[i]) {
            Inst_Pausado[i] := !Inst_Pausado[i]
            if (Inst_Pausado[i])
                LogI(i, "=== PAUSADO ===")
            else
                LogI(i, "=== REANUDADO ===")
            ActualizarEstadoInst(i)
        }
    }
    FlushLog()
return

DetenerTodos:
    SetTimer, LoopPrincipal, Off
    Loop, %MAX_INST% {
        i := A_Index
        if (Inst_Activo[i]) {
            Inst_Activo[i] := false
            Inst_Pausado[i] := false
            Inst_Estado[i] := "IDLE"
            LogI(i, "=== DETENIDO ===")
            ActualizarEstadoInst(i)
        }
    }
    Log(">>> Timer principal detenido")
    FlushLog()
return

; ============================================================================
; LABELS: Control PER-INSTANCIA (generados dinámicamente)
; ============================================================================
IniciarInst1:
    IniciarInstancia(1)
return
IniciarInst2:
    IniciarInstancia(2)
return
IniciarInst3:
    IniciarInstancia(3)
return
IniciarInst4:
    IniciarInstancia(4)
return
IniciarInst5:
    IniciarInstancia(5)
return

PausarInst1:
    PausarInstancia(1)
return
PausarInst2:
    PausarInstancia(2)
return
PausarInst3:
    PausarInstancia(3)
return
PausarInst4:
    PausarInstancia(4)
return
PausarInst5:
    PausarInstancia(5)
return

DetenerInst1:
    DetenerInstancia(1)
return
DetenerInst2:
    DetenerInstancia(2)
return
DetenerInst3:
    DetenerInstancia(3)
return
DetenerInst4:
    DetenerInstancia(4)
return
DetenerInst5:
    DetenerInstancia(5)
return

; ============================================================================
; FUNCIONES: Control per-instancia
; ============================================================================

; Helper: resetear todos los contadores de una instancia
ResetInstancia(i) {
    global
    Inst_Activo[i] := true
    Inst_Pausado[i] := false
    Inst_Paso[i] := 1
    Inst_Ciclos[i] := 0
    Inst_Ataques[i] := 0
    Inst_Errores[i] := 0
    Inst_ErrCon[i] := 0
    Inst_P1Int[i] := 0
    Inst_P8Int[i] := 0
    Inst_P10Int[i] := 0
    Inst_P10Menu[i] := 0
    Inst_P11Int[i] := 0
    Inst_ResInt[i] := 0
    Inst_TapInt[i] := 0
    Inst_NBInt[i] := 0
    Inst_RutaPN[i] := 1
    Inst_Cooldown[i] := 0
    Inst_SkipTick[i] := 0
    Inst_LastExito[i] := A_TickCount
    Inst_RecuperacionTotal[i] := 0
    Inst_ScrollActivo[i] := false
    Inst_ScrollFase[i] := 0
    Inst_RecupFase[i] := 0
}

; Helper: leer expansión/batalla de los DDLs de una instancia
LeerDDLsInstancia(i) {
    global
    GuiControlGet, tmpExp, Main:, DDLExp%i%
    expNum := 1
    Loop, %TotalExpansiones% {
        if InStr(tmpExp, A_Index . ":") {
            expNum := A_Index
            break
        }
    }
    Inst_Exp[i] := expNum

    GuiControlGet, tmpBat, Main:, DDLBat%i%
    batNum := RegExReplace(tmpBat, "[^0-9]", "") + 0
    maxBat := BatCnt[expNum]
    if (batNum < 1 || batNum > maxBat)
        batNum := 1
    Inst_Bat[i] := batNum
}

; Helper: auto-ajustar ventana si está habilitado
AutoAjustarVentana(i) {
    global
    if (AutoAjustar && VentanaAncho >= 100 && VentanaAlto >= 100) {
        hwnd := Inst_Hwnd[i]
        WinGetPos, wx, wy, wwA, whA, ahk_id %hwnd%
        if (wwA != VentanaAncho || whA != VentanaAlto) {
            LogI(i, "Auto-ajustando ventana de " . wwA . "x" . whA . " a " . VentanaAncho . "x" . VentanaAlto)
            WinMove, ahk_id %hwnd%,, wx, wy, %VentanaAncho%, %VentanaAlto%
        }
    }
}

; Helper: verificar si hay al menos una instancia activa
HayInstanciaActiva() {
    global
    Loop, %MAX_INST% {
        if (Inst_Activo[A_Index])
            return true
    }
    return false
}

IniciarInstancia(i) {
    global
    LeerConfigGUI()

    hwnd := Inst_Hwnd[i]
    if (hwnd = 0 || !WinExist("ahk_id " . hwnd)) {
        LogI(i, "ERROR: No hay ventana asignada o no existe")
        FlushLog()
        return
    }

    if (Inst_Activo[i] && Inst_Pausado[i]) {
        Inst_Pausado[i] := false
        LogI(i, "=== REANUDADO ===")
        ActualizarEstadoInst(i)
        FlushLog()
        return
    }

    if (Inst_Activo[i])
        return

    LeerDDLsInstancia(i)
    AutoAjustarVentana(i)
    ResetInstancia(i)

    ; Conectar ADB si está habilitado
    if (ADB_Habilitado && !Inst_ADB_Conectado[i])
        ADB_Conectar(i)

    LogI(i, "=== INICIADO === Exp:" . Inst_Exp[i] . " Bat:" . Inst_Bat[i])
    ActualizarEstadoInst(i)

    if (HayInstanciaActiva()) {
        activos := 0
        Loop, %MAX_INST% {
            if (Inst_Activo[A_Index] && !Inst_Pausado[A_Index])
                activos := activos + 1
        }
        if (activos < 1)
            activos := 1
        rrIntervalo := IntervaloLoop // activos
        if (rrIntervalo < 50)
            rrIntervalo := 50
        RR_Intervalo := rrIntervalo
        SetTimer, LoopPrincipal, %rrIntervalo%
    }
    FlushLog()
}

PausarInstancia(i) {
    global
    if (!Inst_Activo[i])
        return
    Inst_Pausado[i] := !Inst_Pausado[i]
    if (Inst_Pausado[i])
        LogI(i, "=== PAUSADO ===")
    else
        LogI(i, "=== REANUDADO ===")
    ActualizarEstadoInst(i)
    FlushLog()
}

DetenerInstancia(i) {
    global
    if (!Inst_Activo[i])
        return
    Inst_Activo[i] := false
    Inst_Pausado[i] := false
    Inst_ScrollActivo[i] := false
    Inst_ScrollFase[i] := 0
    Inst_RecupFase[i] := 0
    Inst_Estado[i] := "IDLE"
    LogI(i, "=== DETENIDO ===")
    ActualizarEstadoInst(i)

    if (!HayInstanciaActiva())
        SetTimer, LoopPrincipal, Off
    FlushLog()
}

; ============================================================================
; FUNCIÓN: Leer configuración compartida de la GUI
; ============================================================================
LeerConfigGUI() {
    global Variacion, IntervaloLoop, MaxReintentos, ModoDebug
    global VentanaAncho, VentanaAlto, AutoAjustar
    global ScrollActivo, ScrollRelX, ScrollRelY, ScrollCantidad, ScrollDelay, ScrollEnPaso

    GuiControlGet, tmpVariacion, Main:, EditVariacion
    Variacion := RegExReplace(tmpVariacion, ",", "") + 0
    GuiControlGet, tmpIntervalo, Main:, EditIntervalo
    IntervaloLoop := RegExReplace(tmpIntervalo, ",", "") + 0
    GuiControlGet, tmpReintentos, Main:, EditReintentos
    MaxReintentos := RegExReplace(tmpReintentos, ",", "") + 0
    GuiControlGet, tmpDebug, Main:, ChkDebug
    ModoDebug := tmpDebug
    GuiControlGet, tmpAncho, Main:, EditVentanaAncho
    VentanaAncho := RegExReplace(tmpAncho, ",", "") + 0
    GuiControlGet, tmpAlto, Main:, EditVentanaAlto
    VentanaAlto := RegExReplace(tmpAlto, ",", "") + 0
    GuiControlGet, tmpAutoAjustar, Main:, ChkAutoAjustar
    AutoAjustar := tmpAutoAjustar

    GuiControlGet, tmpScroll, Main:, ChkScroll
    ScrollActivo := tmpScroll
    GuiControlGet, tmpScrollX, Main:, EditScrollX
    ScrollRelX := RegExReplace(tmpScrollX, ",", "") + 0
    GuiControlGet, tmpScrollY, Main:, EditScrollY
    ScrollRelY := RegExReplace(tmpScrollY, ",", "") + 0
    GuiControlGet, tmpScrollCant, Main:, EditScrollCant
    ScrollCantidad := RegExReplace(tmpScrollCant, ",", "") + 0
    GuiControlGet, tmpScrollDelay, Main:, EditScrollDelay
    ScrollDelay := RegExReplace(tmpScrollDelay, ",", "") + 0
    GuiControlGet, tmpScrollPaso, Main:, DDLScrollPaso
    ScrollEnPaso := 0
    Loop, 3 {
        if InStr(tmpScrollPaso, "Paso " . A_Index) {
            ScrollEnPaso := A_Index
            break
        }
    }
}

; ============================================================================
; LOOP PRINCIPAL: Round-robin — procesa 1 instancia por tick para paralelismo
; ============================================================================
LoopPrincipal:
    Critical

    ; Decrementar cooldowns de TODAS las instancias cada tick
    Loop, %MAX_INST% {
        idx := A_Index
        if (Inst_Activo[idx] && Inst_SkipTick[idx] > 0)
            Inst_SkipTick[idx] := Inst_SkipTick[idx] - 1
    }

    ; Round-robin: buscar la siguiente instancia activa para procesar
    intentosRR := 0
    i := 0
    Loop, %MAX_INST% {
        RR_Inst := RR_Inst + 1
        if (RR_Inst > MAX_INST)
            RR_Inst := 1
        intentosRR := intentosRR + 1

        if (!Inst_Activo[RR_Inst] || Inst_Pausado[RR_Inst])
            continue
        if (Inst_SkipTick[RR_Inst] > 0)
            continue

        i := RR_Inst
        break
    }

    ; Si no hay instancia para procesar, solo flush y actualizar
    if (i = 0) {
        FlushLog()
        Loop, %MAX_INST% {
            if (Inst_Activo[A_Index])
                ActualizarEstadoInst(A_Index)
        }
        return
    }

    ; Verificar que la ventana sigue existiendo
    hwnd := Inst_Hwnd[i]
    if (!WinExist("ahk_id " . hwnd)) {
        LogI(i, "ERROR: Ventana cerrada. Deteniendo instancia.")
        DetenerInstancia(i)
        FlushLog()
        return
    }

    WinGetPos,,, ww, wh, ahk_id %hwnd%
    if (ww = 0 || wh = 0) {
        FlushLog()
        return
    }

    ; Watchdog: si lleva demasiado tiempo sin éxito, forzar recuperación
    tiempoSinExito := (A_TickCount - Inst_LastExito[i]) // 1000
    if (tiempoSinExito >= WatchdogSegundos) {
        LogI(i, "WATCHDOG: " . tiempoSinExito . "s sin éxito. Recuperación forzada desde P" . Inst_Paso[i])
        Inst_ErrCon[i] := 0
        Inst_P1Int[i] := 0
        Inst_P8Int[i] := 0
        Inst_P10Int[i] := 0
        Inst_P10Menu[i] := 0
        Inst_P11Int[i] := 0
        Inst_ResInt[i] := 0
        Inst_TapInt[i] := 0
        Inst_NBInt[i] := 0
        Inst_RecuperacionTotal[i] := Inst_RecuperacionTotal[i] + 1
        Inst_ScrollActivo[i] := false
        Inst_ScrollFase[i] := 0
        Inst_Paso[i] := RecuperacionInteligente(i, hwnd, Inst_Paso[i])
        Inst_LastExito[i] := A_TickCount
        FlushLog()
        ActualizarEstadoInst(i)
        return
    }

    ; Si hay una recuperación en curso, procesarla (1 popup por tick)
    if (Inst_RecupFase[i] > 0) {
        ProcesarRecuperacion(i)
        FlushLog()
        ActualizarEstadoInst(i)
        return
    }

    ; Si hay un scroll en curso, procesarlo en vez de la lógica normal
    if (Inst_ScrollActivo[i]) {
        resultado := ProcesarScroll(i)
        if (resultado = 0) {
            FlushLog()
            ActualizarEstadoInst(i)
            return
        }
        ; Scroll terminado: si encontró imagen post-scroll, actuar
        if (resultado = 2) {
            hwndS := Inst_Hwnd[i]
            imgS := Inst_ScrollPostImg[i] ? Inst_ScrollPostImg[i] : ""
            paso := Inst_Paso[i]
            if (paso = 1 || paso = 8) {
                exp := Inst_Exp[i]
                bat := Inst_Bat[i]
                imgBuscar := BatImg[exp, bat]
                foundX := 0
                foundY := 0
                if (BuscarImagenEnVentana(hwndS, imgBuscar, foundX, foundY)) {
                    nomBat := BatNom[exp, bat]
                    LogI(i, "P" . paso . ": '" . nomBat . "' encontrado (post-scroll)")
                    HacerClicEnVentana(hwndS, foundX, foundY, i)
                    Inst_Ataques[i] := Inst_Ataques[i] + 1
                    Inst_ErrCon[i] := 0
                    if (paso = 1)
                        Inst_P1Int[i] := 0
                    else
                        Inst_P8Int[i] := 0
                    Inst_Paso[i] := 2
                    ; Esperar más para que cargue la pantalla de batalla
                    intervaloActual := RR_Intervalo > 0 ? RR_Intervalo : IntervaloLoop
                    Inst_SkipTick[i] := Ceil(2000 / intervaloActual)
                    Inst_LastExito[i] := A_TickCount
                }
            }
            FlushLog()
            ActualizarEstadoInst(i)
            return
        }
        ; resultado = 1 o -1: scroll terminado, continuar lógica normal en siguiente tick
        FlushLog()
        ActualizarEstadoInst(i)
        return
    }

    pasoAntes := Inst_Paso[i]
    ProcesarInstancia(i)
    ; Si el paso cambió, hubo progreso => resetear watchdog y contadores de error
    if (Inst_Paso[i] != pasoAntes) {
        Inst_LastExito[i] := A_TickCount
        Inst_ErrCon[i] := 0
    }

    ; Flush log y actualizar estado de esta instancia
    FlushLog()
    ActualizarEstadoInst(i)
return

; ============================================================================
; FUNCIÓN: Escanear popups inesperados (OK, X, TAP, NEXT, victoria, derrota)
; Retorna: "" si no encontró nada, o el nombre del popup clickeado
; NO modifica pasos ni estado - eso lo decide quien llama
; ============================================================================
ScanearPopups(hwnd, ByRef outX, ByRef outY) {
    global IMG_OK, IMG_EQUIS, IMG_TAP, IMG_NEXT, IMG_VICTORIA, IMG_DERROTA

    if (BuscarImagenEnVentana(hwnd, IMG_OK, outX, outY))
        return "OK"
    if (BuscarImagenEnVentana(hwnd, IMG_EQUIS, outX, outY))
        return "X"
    if (BuscarImagenEnVentana(hwnd, IMG_NEXT, outX, outY))
        return "NEXT"
    if (BuscarImagenEnVentana(hwnd, IMG_TAP, outX, outY))
        return "TAP"
    if (BuscarImagenEnVentana(hwnd, IMG_VICTORIA, outX, outY))
        return "VICTORIA"
    if (BuscarImagenEnVentana(hwnd, IMG_DERROTA, outX, outY))
        return "DERROTA"
    return ""
}

; ============================================================================
; FUNCIÓN: Iniciar recuperación inteligente incremental
; En vez de escanear 6 imágenes de golpe, activa modo recuperación.
; ProcesarRecuperacion() se encarga de buscar 1 popup por tick.
; ============================================================================
RecuperacionInteligente(i, hwnd, pasoOrigen) {
    global
    Inst_RecupFase[i] := 1
    Inst_RecupOrigen[i] := pasoOrigen
    LogI(i, "RECUP[P" . pasoOrigen . "]: Iniciando escaneo incremental...")
    ; Retorna el paso actual como placeholder - ProcesarRecuperacion lo cambiará
    return Inst_Paso[i]
}

; ============================================================================
; FUNCIÓN: Procesar recuperación incremental (1 búsqueda por tick)
; Retorna true si la recuperación sigue en curso, false si terminó
; ============================================================================
ProcesarRecuperacion(i) {
    global
    fase := Inst_RecupFase[i]
    if (fase = 0)
        return false

    hwnd := Inst_Hwnd[i]
    pasoOrigen := Inst_RecupOrigen[i]
    foundX := 0
    foundY := 0

    ; Fase 1: Buscar OK
    if (fase = 1) {
        if (BuscarImagenEnVentana(hwnd, IMG_OK, foundX, foundY)) {
            LogI(i, "RECUP[P" . pasoOrigen . "]: Popup OK detectado. Clic + ir a P8")
            HacerClicEnVentana(hwnd, foundX, foundY, i)
            Inst_SkipTick[i] := 2
            Inst_Paso[i] := 8
            Inst_RecupFase[i] := 0
            return true
        }
        Inst_RecupFase[i] := 2
        return true
    }
    ; Fase 2: Buscar X
    if (fase = 2) {
        if (BuscarImagenEnVentana(hwnd, IMG_EQUIS, foundX, foundY)) {
            LogI(i, "RECUP[P" . pasoOrigen . "]: Popup X detectado. Clic + ir a P1")
            HacerClicEnVentana(hwnd, foundX, foundY, i)
            Inst_SkipTick[i] := 2
            Inst_Paso[i] := 1
            Inst_RecupFase[i] := 0
            return true
        }
        Inst_RecupFase[i] := 3
        return true
    }
    ; Fase 3: Buscar NEXT
    if (fase = 3) {
        if (BuscarImagenEnVentana(hwnd, IMG_NEXT, foundX, foundY)) {
            LogI(i, "RECUP[P" . pasoOrigen . "]: NEXT detectado. Clic + ir a P6")
            HacerClicEnVentana(hwnd, foundX, foundY, i)
            Inst_SkipTick[i] := 2
            Inst_RutaPN[i] := 6
            Inst_Paso[i] := 6
            Inst_RecupFase[i] := 0
            return true
        }
        Inst_RecupFase[i] := 4
        return true
    }
    ; Fase 4: Buscar TAP
    if (fase = 4) {
        if (BuscarImagenEnVentana(hwnd, IMG_TAP, foundX, foundY)) {
            LogI(i, "RECUP[P" . pasoOrigen . "]: TAP detectado. Clic + ir a P5")
            HacerClicEnVentana(hwnd, foundX, foundY, i)
            Inst_SkipTick[i] := 2
            Inst_TapInt[i] := 0
            Inst_RutaPN[i] := 6
            Inst_Paso[i] := 5
            Inst_RecupFase[i] := 0
            return true
        }
        Inst_RecupFase[i] := 5
        return true
    }
    ; Fase 5: Buscar VICTORIA
    ; Solo buscar victoria/derrota si el paso origen indica que SÍ hubo una batalla
    ; (P4+ = durante/después de batalla). Si estamos en P1/P2/P3, NO buscar resultado
    ; porque la batalla no se inició y podríamos detectar imágenes de otra ventana.
    if (fase = 5) {
        if (pasoOrigen >= 4) {
            if (BuscarImagenEnVentana(hwnd, IMG_VICTORIA, foundX, foundY)) {
                LogI(i, "RECUP[P" . pasoOrigen . "]: Victoria detectada. Ir a P4")
                Inst_ResInt[i] := 0
                Inst_Paso[i] := 4
                Inst_RecupFase[i] := 0
                return true
            }
        }
        Inst_RecupFase[i] := 6
        return true
    }
    ; Fase 6: Buscar DERROTA
    if (fase = 6) {
        if (pasoOrigen >= 4) {
            if (BuscarImagenEnVentana(hwnd, IMG_DERROTA, foundX, foundY)) {
                LogI(i, "RECUP[P" . pasoOrigen . "]: Derrota detectada. Ir a P4")
                Inst_ResInt[i] := 0
                Inst_Paso[i] := 4
                Inst_RecupFase[i] := 0
                return true
            }
        }
        ; Nada encontrado: ir a P1 como último recurso
        LogI(i, "RECUP[P" . pasoOrigen . "]: Nada detectado. Volviendo a P1")
        Inst_Paso[i] := 1
        Inst_RecupFase[i] := 0
        return true
    }

    Inst_RecupFase[i] := 0
    return false
}

; ============================================================================
; FUNCIÓN: Procesar un tick de una instancia (toda la lógica de 11 pasos)
; ============================================================================
ProcesarInstancia(i) {
    global

    hwnd := Inst_Hwnd[i]
    paso := Inst_Paso[i]
    exp := Inst_Exp[i]
    bat := Inst_Bat[i]

    Inst_Ciclos[i] := Inst_Ciclos[i] + 1

    ; Protección de límites
    if (paso < 1 || paso > TotalPasos) {
        LogI(i, "AVISO: Paso fuera de rango (" . paso . "). Reiniciando a 1.")
        Inst_Paso[i] := 1
        Inst_ErrCon[i] := 0
        return
    }

    nombrePaso := PasoNombres[paso]
    Inst_Estado[i] := "P" . paso . "/" . TotalPasos . ": " . nombrePaso . " [E" . exp . "]"

    ; ================================================================
    ; PASO 4: Escanear victoria O derrota (alternando, 1 búsqueda por tick)
    ; ================================================================
    if (paso = 4) {
        Inst_ResInt[i] := Inst_ResInt[i] + 1
        resInt := Inst_ResInt[i]

        if (resInt = 1)
            LogI(i, "P4: Buscando resultado (40 intentos, 3s c/u)...")

        Inst_Estado[i] := "P4: Resultado... (" . resInt . "/40)"

        ; Alternar: ticks impares buscan DERROTA, pares buscan VICTORIA
        if (Mod(resInt, 2) = 1) {
            if (BuscarImagenEnVentana(hwnd, IMG_DERROTA, foundX, foundY)) {
                LogI(i, "DERROTA en intento " . resInt)
                Inst_ErrCon[i] := 0
                Inst_ResInt[i] := 0
                Inst_TapInt[i] := 0
                Inst_RutaPN[i] := 9
                Inst_Paso[i] := 5
                LogI(i, ">>> Ruta derrota: P5 (Tap->Next->CerrarX)")
                return
            }
        } else {
            if (BuscarImagenEnVentana(hwnd, IMG_VICTORIA, foundX, foundY)) {
                LogI(i, "VICTORIA en intento " . resInt)
                HacerClicEnVentana(hwnd, foundX, foundY, i)
                Inst_ErrCon[i] := 0
                Inst_Ataques[i] := Inst_Ataques[i] + 1
                Inst_ResInt[i] := 0
                Inst_TapInt[i] := 0
                Inst_RutaPN[i] := 6
                Inst_Paso[i] := 5
                Inst_SkipTick[i] := 2
                LogI(i, ">>> Ruta victoria: P5 (Tap->Next->NuevaBatalla)")
                return
            }
        }

        ; Cooldown de ~3 segundos entre intentos (skip ticks)
        intervaloActual := RR_Intervalo > 0 ? RR_Intervalo : IntervaloLoop
        ticksPor3s := Ceil(3000 / intervaloActual)
        if (ticksPor3s < 1)
            ticksPor3s := 1
        Inst_SkipTick[i] := ticksPor3s

        if (resInt >= 40) {
            LogI(i, "RECUPERACION: Sin resultado tras 40 intentos")
            Inst_ResInt[i] := 0
            Inst_ErrCon[i] := 0
            Inst_Paso[i] := RecuperacionInteligente(i, hwnd, 4)
        }
        return
    }

    ; ================================================================
    ; PASO 5: Tap dinámico hasta que aparezca Next
    ; ================================================================
    if (paso = 5) {
        Inst_TapInt[i] := Inst_TapInt[i] + 1
        tapInt := Inst_TapInt[i]

        if (tapInt = 1)
            LogI(i, "P5: Tap hasta Next (destino: P" . Inst_RutaPN[i] . ")...")

        Inst_Estado[i] := "P5: Tap->Next (" . tapInt . "/" . MaxTapIntentos . ")"

        ; Alternar: ticks impares buscan NEXT, pares buscan TAP (1 búsqueda por tick)
        if (Mod(tapInt, 2) = 1) {
            if (BuscarImagenEnVentana(hwnd, IMG_NEXT, foundX, foundY)) {
                LogI(i, "Next encontrado. Clic...")
                HacerClicEnVentana(hwnd, foundX, foundY, i)
                Inst_ErrCon[i] := 0
                Inst_TapInt[i] := 0
                Inst_Paso[i] := Inst_RutaPN[i]
                Inst_SkipTick[i] := 2
                LogI(i, ">>> Volviendo a P" . Inst_RutaPN[i])
                return
            }
        } else {
            if (BuscarImagenEnVentana(hwnd, IMG_TAP, foundX, foundY)) {
                LogI(i, "Tap encontrado. Clic...")
                HacerClicEnVentana(hwnd, foundX, foundY, i)
                Inst_SkipTick[i] := 2
                return
            }
        }

        if (Mod(tapInt, 10) = 0)
            LogI(i, "P5: Ni Tap ni Next (" . tapInt . " intentos)")

        if (tapInt >= MaxTapIntentos) {
            LogI(i, "RECUPERACION: Sin Tap/Next tras " . MaxTapIntentos)
            Inst_TapInt[i] := 0
            Inst_ErrCon[i] := 0
            Inst_Paso[i] := RecuperacionInteligente(i, hwnd, 5)
        }
        return
    }

    ; ================================================================
    ; PASO 6: Detectar pantalla "nueva batalla desbloqueada"
    ; ================================================================
    if (paso = 6) {
        Inst_NBInt[i] := Inst_NBInt[i] + 1
        nbInt := Inst_NBInt[i]

        if (nbInt = 1)
            LogI(i, "P6: Buscando nueva batalla desbloqueada...")

        Inst_Estado[i] := "P6: NuevaBatalla (" . nbInt . "/" . MaxNuevaBatallaIntentos . ")"

        if (BuscarImagenEnVentana(hwnd, IMG_NUEVA_BATALLA, foundX, foundY)) {
            LogI(i, "Nueva batalla detectada en intento " . nbInt)
            Inst_NBInt[i] := 0
            Inst_ErrCon[i] := 0
            Inst_Paso[i] := 7
            return
        }

        if (nbInt >= MaxNuevaBatallaIntentos) {
            LogI(i, "Nueva batalla no encontrada. Saltando a P8...")
            Inst_NBInt[i] := 0
            Inst_ErrCon[i] := 0
            Inst_Paso[i] := 8
        }
        return
    }

    ; ================================================================
    ; PASO 8: Selección de siguiente batalla (rotación)
    ; ================================================================
    if (paso = 8) {
        if (Inst_P8Int[i] = 0) {
            Inst_Bat[i] := Inst_Bat[i] + 1
            maxBat := BatCnt[exp]
            if (Inst_Bat[i] > maxBat) {
                LogI(i, ">>> Exp " . exp . " completada (" . maxBat . " batallas)")

                ; Avanzar a siguiente expansión
                Inst_Exp[i] := Inst_Exp[i] + 1
                if (Inst_Exp[i] > TotalExpansiones)
                    Inst_Exp[i] := 1
                revisadas := 0
                while (BatCnt[Inst_Exp[i]] = 0 && revisadas < TotalExpansiones) {
                    Inst_Exp[i] := Inst_Exp[i] + 1
                    if (Inst_Exp[i] > TotalExpansiones)
                        Inst_Exp[i] := 1
                    revisadas++
                }

                if (BatCnt[Inst_Exp[i]] = 0) {
                    LogI(i, "ERROR: Ninguna expansion tiene batallas")
                    return
                }

                Inst_Bat[i] := 1
                Inst_P8Int[i] := 0
                Inst_P10Int[i] := 0
                Inst_P10Menu[i] := 0
                Inst_P11Int[i] := 0
                Inst_Paso[i] := 10
                LogI(i, ">>> Ir a P10: CambiarExpansion (Exp " . Inst_Exp[i] . ": " . ExpansionNombres[Inst_Exp[i]] . ")")
                return
            }
            exp := Inst_Exp[i]
            bat := Inst_Bat[i]
            LogI(i, ">>> Siguiente batalla: " . BatNom[exp, bat] . " (" . bat . "/" . BatCnt[exp] . ")")
        }

        exp := Inst_Exp[i]
        bat := Inst_Bat[i]
        imgBat := BatImg[exp, bat]
        nomBat := BatNom[exp, bat]

        if (imgBat = "" || !ArchivoExiste(imgBat)) {
            LogI(i, "ERROR: Falta imagen para batalla " . bat . " (" . nomBat . ")")
            Inst_Errores[i] := Inst_Errores[i] + 1
            return
        }

        Inst_P8Int[i] := Inst_P8Int[i] + 1
        Inst_Estado[i] := "P8: Buscando " . nomBat . " (" . Inst_P8Int[i] . ")"

        if (BuscarImagenEnVentana(hwnd, imgBat, foundX, foundY)) {
            LogI(i, "P8: '" . nomBat . "' encontrado. Clic...")
            HacerClicEnVentana(hwnd, foundX, foundY, i)
            Inst_Ataques[i] := Inst_Ataques[i] + 1
            Inst_ErrCon[i] := 0
            Inst_P8Int[i] := 0
            Inst_Paso[i] := 2
            Inst_SkipTick[i] := 2
            return
        }

        ; Cada 10 intentos, volver arriba con scroll inverso grande (no-bloqueante)
        if (Mod(Inst_P8Int[i], 10) = 0) {
            LogI(i, "P8: Scroll inverso para volver arriba (" . Inst_P8Int[i] . ")")
            IniciarScroll(i, hwnd, ScrollRelX, ScrollRelY, -ScrollCantidad * 2, 5)
        } else {
            ; Scroll normal con búsqueda post-scroll (no-bloqueante)
            if (Mod(Inst_P8Int[i], 5) = 0)
                LogI(i, "P8: '" . nomBat . "' no encontrado. Scroll... (" . Inst_P8Int[i] . ")")
            IniciarScroll(i, hwnd, ScrollRelX, ScrollRelY, ScrollCantidad, 1, imgBat)
        }

        Inst_ErrCon[i] := Inst_ErrCon[i] + 1
        Inst_Errores[i] := Inst_Errores[i] + 1
        if (Inst_ErrCon[i] >= MaxErroresConsecutivos) {
            LogI(i, "P8: No encontró batalla. Avanzando a siguiente...")
            Inst_P8Int[i] := 0
            Inst_ErrCon[i] := 0
            ; En vez de recuperación, saltar esta batalla y probar la siguiente
            Inst_Bat[i] := Inst_Bat[i] + 1
            maxBat2 := BatCnt[Inst_Exp[i]]
            if (Inst_Bat[i] > maxBat2) {
                ; Todas las batallas de esta expansión agotadas, ir a cambiar expansión
                Inst_Exp[i] := Inst_Exp[i] + 1
                if (Inst_Exp[i] > TotalExpansiones)
                    Inst_Exp[i] := 1
                revisadas2 := 0
                while (BatCnt[Inst_Exp[i]] = 0 && revisadas2 < TotalExpansiones) {
                    Inst_Exp[i] := Inst_Exp[i] + 1
                    if (Inst_Exp[i] > TotalExpansiones)
                        Inst_Exp[i] := 1
                    revisadas2++
                }
                Inst_Bat[i] := 1
                Inst_P10Int[i] := 0
                Inst_P10Menu[i] := 0
                Inst_P11Int[i] := 0
                Inst_Paso[i] := 10
                LogI(i, ">>> Exp agotada. Ir a P10: CambiarExpansion (Exp " . Inst_Exp[i] . ": " . ExpansionNombres[Inst_Exp[i]] . ")")
            } else {
                LogI(i, ">>> Saltando a batalla " . Inst_Bat[i] . " de Exp " . Inst_Exp[i])
                ; Quedarse en P8 para buscar la nueva batalla
            }
        }
        return
    }

    ; ================================================================
    ; PASO 9: Cerrar X después de derrota
    ; ================================================================
    if (paso = 9) {
        Inst_Estado[i] := "P9: Buscando X..."

        if (BuscarImagenEnVentana(hwnd, IMG_EQUIS, foundX, foundY)) {
            LogI(i, "P9: X encontrado. Clic...")
            HacerClicEnVentana(hwnd, foundX, foundY, i)
            Inst_ErrCon[i] := 0
            ; Después de derrota, avanzar a siguiente batalla (P8) en vez de repetir la misma
            Inst_Paso[i] := 8
            Inst_SkipTick[i] := 2
            LogI(i, ">>> Post-derrota: Ir a P8 (siguiente batalla)")
            return
        }

        Inst_ErrCon[i] := Inst_ErrCon[i] + 1
        Inst_Errores[i] := Inst_Errores[i] + 1
        if (Mod(Inst_ErrCon[i], 10) = 0)
            LogI(i, "P9: X no encontrado (" . Inst_ErrCon[i] . " intentos)")
        if (Inst_ErrCon[i] >= MaxErroresConsecutivos) {
            LogI(i, "RECUPERACION: X no encontrado")
            Inst_ErrCon[i] := 0
            Inst_RecuperacionTotal[i] := Inst_RecuperacionTotal[i] + 1
            Inst_Paso[i] := RecuperacionInteligente(i, hwnd, 9)
        }
        return
    }

    ; ================================================================
    ; PASO 10: Cambiar expansión
    ; Estrategia: Primero scroll arriba para ver la zona de expansiones,
    ; luego buscar el botón de la expansión destino directamente.
    ; Si existe un botón "Expansiones" intermedio, clickearlo primero.
    ; ================================================================
    if (paso = 10) {
        Inst_P10Int[i] := Inst_P10Int[i] + 1

        expDest := Inst_Exp[i]
        nombreExpDest := ExpansionNombres[expDest]
        imgExpDest := ExpansionImagenes[expDest]

        if (Inst_P10Int[i] = 1)
            LogI(i, "P10: Cambiando a expansión '" . nombreExpDest . "'...")

        Inst_Estado[i] := "P10: -> " . nombreExpDest . " (" . Inst_P10Int[i] . ")"

        ; === MODO 1: Menú abierto — solo buscar la expansión destino, NO scroll, NO re-click Expansiones ===
        if (Inst_P10Menu[i] = 1) {
            if (imgExpDest != "" && ArchivoExiste(imgExpDest)) {
                if (BuscarImagenEnVentana(hwnd, imgExpDest, foundX, foundY)) {
                    LogI(i, "P10: Expansión '" . nombreExpDest . "' encontrada en menú. Clic...")
                    HacerClicEnVentana(hwnd, foundX, foundY, i)
                    Inst_P10Int[i] := 0
                    Inst_P10Menu[i] := 0
                    Inst_ErrCon[i] := 0
                    Inst_Paso[i] := 1
                    Inst_SkipTick[i] := 2
                    Inst_LastExito[i] := A_TickCount
                    LogI(i, ">>> Expansión cambiada. Ir a P1.")
                    return
                }
            }
            ; Menú abierto pero expansión no encontrada aún
            Inst_ErrCon[i] := Inst_ErrCon[i] + 1
            if (Mod(Inst_ErrCon[i], 5) = 0)
                LogI(i, "P10: Menú abierto, '" . nombreExpDest . "' no visible (" . Inst_ErrCon[i] . ")")
            ; Después de 2 intentos sin encontrar, hacer scroll abajo dentro del menú
            ; Usar ScrollRelX pero con Y al 70% de la pantalla (más abajo que el centro)
            ; para no tocar el borde del popup y cerrarlo
            if (Inst_ErrCon[i] >= 2) {
                GetClientOffset(hwnd, _ox, _oy, _cw, _ch)
                ; Y al 70% del área de juego (más abajo del centro, dentro del popup)
                menuScrollY := _oy + (_ch * 70 // 100)
                IniciarScroll(i, hwnd, ScrollRelX, menuScrollY, ScrollCantidad)
            }
            ; Después de 20 intentos, el menú probablemente se cerró — volver a modo 0
            if (Inst_ErrCon[i] >= 20) {
                LogI(i, "P10: Expansión no encontrada en menú. Reintentando abrir menú...")
                Inst_P10Menu[i] := 0
                Inst_ErrCon[i] := 0
            }
            return
        }

        ; === MODO 0: Buscar y abrir el menú de expansiones ===

        ; 1) Buscar directamente la expansión destino (puede ser un tab visible sin menú)
        if (imgExpDest != "" && ArchivoExiste(imgExpDest)) {
            if (BuscarImagenEnVentana(hwnd, imgExpDest, foundX, foundY)) {
                LogI(i, "P10: Expansión '" . nombreExpDest . "' encontrada directamente. Clic...")
                HacerClicEnVentana(hwnd, foundX, foundY, i)
                Inst_P10Int[i] := 0
                Inst_P10Menu[i] := 0
                Inst_ErrCon[i] := 0
                Inst_Paso[i] := 1
                Inst_SkipTick[i] := 2
                Inst_LastExito[i] := A_TickCount
                LogI(i, ">>> Expansión cambiada. Ir a P1.")
                return
            }
        }

        ; 2) Buscar botón "Expansiones" para abrir el menú
        if (BuscarImagenEnVentana(hwnd, IMG_EXPANSIONES, foundX, foundY)) {
            LogI(i, "P10: Botón 'Expansiones' encontrado. Clic para abrir menú...")
            HacerClicEnVentana(hwnd, foundX, foundY, i)
            Inst_P10Menu[i] := 1  ; Marcar que el menú está abierto
            Inst_ErrCon[i] := 0   ; Resetear contador para el modo menú
            ; Esperar 3 segundos reales para que la animación del menú termine
            intervaloActual := RR_Intervalo > 0 ? RR_Intervalo : IntervaloLoop
            Inst_SkipTick[i] := Ceil(3000 / intervaloActual)
            ; Quedarse en P10: el siguiente tick buscará la expansión en modo menú
            return
        }

        ; 3) El botón Expansiones siempre está visible — no necesita scroll
        ;    Si no se encontró ni la expansión ni el botón, solo reintentar
        Inst_ErrCon[i] := Inst_ErrCon[i] + 1
        if (Mod(Inst_ErrCon[i], 10) = 0)
            LogI(i, "P10: Ni expansión ni botón encontrados (" . Inst_ErrCon[i] . " intentos)")

        if (Inst_ErrCon[i] >= MaxErroresConsecutivos) {
            LogI(i, "P10: No pudo cambiar a '" . nombreExpDest . "'. Ir a P1.")
            Inst_P10Int[i] := 0
            Inst_P10Menu[i] := 0
            Inst_ErrCon[i] := 0
            Inst_Paso[i] := 1
        }
        return
    }

    ; ================================================================
    ; PASO 11 ya no se usa — la lógica se unificó en P10.
    ; Si por alguna razón se llega aquí, redirigir a P10.
    ; ================================================================
    if (paso = 11) {
        Inst_Paso[i] := 10
        Inst_P10Int[i] := 0
        Inst_P10Menu[i] := 0
        Inst_P11Int[i] := 0
        Inst_ErrCon[i] := 0
        return
    }

    ; ================================================================
    ; PASO 1: Buscar batalla con scroll automático
    ; ================================================================
    if (paso = 1) {
        exp := Inst_Exp[i]
        bat := Inst_Bat[i]
        imgBat1 := BatImg[exp, bat]
        nomBat1 := BatNom[exp, bat]

        if (imgBat1 = "" || !ArchivoExiste(imgBat1)) {
            LogI(i, "ERROR: Falta imagen batalla " . bat . " (" . nomBat1 . ")")
            Inst_Errores[i] := Inst_Errores[i] + 1
            return
        }

        Inst_P1Int[i] := Inst_P1Int[i] + 1
        Inst_Estado[i] := "P1: " . nomBat1 . " (" . Inst_P1Int[i] . ")"

        ; Buscar imagen antes del scroll
        if (BuscarImagenEnVentana(hwnd, imgBat1, foundX, foundY)) {
            LogI(i, "P1: '" . nomBat1 . "' encontrado")
            HacerClicEnVentana(hwnd, foundX, foundY, i)
            Inst_Ataques[i] := Inst_Ataques[i] + 1
            Inst_ErrCon[i] := 0
            Inst_P1Int[i] := 0
            Inst_Paso[i] := 2
            ; Esperar más para que cargue la pantalla de batalla (Auto/Iniciar)
            intervaloActual := RR_Intervalo > 0 ? RR_Intervalo : IntervaloLoop
            Inst_SkipTick[i] := Ceil(2000 / intervaloActual)
            return
        }

        ; Cada 10 intentos, volver arriba con scroll inverso grande (no-bloqueante)
        if (Mod(Inst_P1Int[i], 10) = 0) {
            LogI(i, "P1: Scroll inverso para volver arriba (" . Inst_P1Int[i] . ")")
            IniciarScroll(i, hwnd, ScrollRelX, ScrollRelY, -ScrollCantidad * 2, 5)
        } else {
            ; Scroll normal con búsqueda post-scroll (no-bloqueante)
            if (Mod(Inst_P1Int[i], 5) = 0)
                LogI(i, "P1: '" . nomBat1 . "' no encontrado. Scroll... (" . Inst_P1Int[i] . ")")
            IniciarScroll(i, hwnd, ScrollRelX, ScrollRelY, ScrollCantidad, 1, imgBat1)
        }

        Inst_ErrCon[i] := Inst_ErrCon[i] + 1
        Inst_Errores[i] := Inst_Errores[i] + 1
        if (Inst_ErrCon[i] >= MaxErroresConsecutivos) {
            LogI(i, "RECUPERACION: Atascado P1")
            Inst_P1Int[i] := 0
            Inst_ErrCon[i] := 0
            Inst_RecuperacionTotal[i] := Inst_RecuperacionTotal[i] + 1
            nuevoPaso := RecuperacionInteligente(i, hwnd, 1)
            Inst_Paso[i] := nuevoPaso
        }
        return
    }

    ; ================================================================
    ; PASOS NORMALES (2, 3, 7): Buscar imagen y clicar
    ; ================================================================
    imgActual := PasoImagenes[paso]

    if (imgActual = "" || !ArchivoExiste(imgActual)) {
        LogI(i, "ERROR: Falta imagen P" . paso . " (" . nombrePaso . ")")
        Inst_Errores[i] := Inst_Errores[i] + 1
        return
    }

    ; Buscar imagen (sin scroll bloqueante)
    ; P2 (Auto) y P3 (Iniciar) NO deben hacer scroll: son botones fijos en pantalla
    imagenEncontrada := false
    if (BuscarImagenEnVentana(hwnd, imgActual, foundX, foundY)) {
        imagenEncontrada := true
    } else if (paso != 2 && paso != 3 && ScrollActivo && (ScrollEnPaso = 0 || ScrollEnPaso = paso)) {
        ; No encontrada: scroll no-bloqueante y reintentar en el siguiente tick
        IniciarScroll(i, hwnd, ScrollRelX, ScrollRelY, ScrollCantidad)
    }

    if (imagenEncontrada) {
        LogI(i, "P" . paso . ": '" . nombrePaso . "' encontrado")
        HacerClicEnVentana(hwnd, foundX, foundY, i)
        Inst_Ataques[i] := Inst_Ataques[i] + 1
        Inst_ErrCon[i] := 0
        Inst_Paso[i] := paso + 1
        Inst_SkipTick[i] := 2
        LogI(i, ">>> Avanzando a P" . (paso + 1))
    } else {
        Inst_ErrCon[i] := Inst_ErrCon[i] + 1
        Inst_Errores[i] := Inst_Errores[i] + 1

        ; P2/P3 (Auto/Iniciar): dar más tiempo entre reintentos (pantalla puede estar cargando)
        if (paso = 2 || paso = 3) {
            Inst_SkipTick[i] := 1
        }

        if (Mod(Inst_ErrCon[i], 10) = 0)
            LogI(i, "P" . paso . ": '" . nombrePaso . "' no encontrado (" . Inst_ErrCon[i] . ")")

        if (Inst_ErrCon[i] >= MaxErroresConsecutivos) {
            Inst_ErrCon[i] := 0
            Inst_RecuperacionTotal[i] := Inst_RecuperacionTotal[i] + 1
            if (paso = 2 || paso = 3) {
                ; Auto/Iniciar no encontrados: la pantalla de batalla no cargó.
                ; Volver a P1 para reintentar (NO buscar victoria/derrota)
                LogI(i, "P" . paso . ": '" . nombrePaso . "' no encontrado. Volviendo a P1.")
                Inst_Paso[i] := 1
            } else {
                ; P7 u otros: usar recuperación normal
                LogI(i, "RECUPERACION: Atascado P" . paso)
                Inst_Paso[i] := RecuperacionInteligente(i, hwnd, paso)
            }
        }
    }
}

; ============================================================================
; LABELS: Detectar ventana per-instancia
; ============================================================================
DetectarVentana1:
    DetectarVentanaInst(1)
return
DetectarVentana2:
    DetectarVentanaInst(2)
return
DetectarVentana3:
    DetectarVentanaInst(3)
return
DetectarVentana4:
    DetectarVentanaInst(4)
return
DetectarVentana5:
    DetectarVentanaInst(5)
return

DetectarVentanaInst(i) {
    global Inst_Hwnd, Inst_Titulo, MAX_INST, SelVentLista, SelVentInstancia

    ; Listar ventanas disponibles (excluir la propia GUI, sistema, y ya asignadas)
    listaVentanas := ""
    WinGet, ids, List
    Loop, %ids% {
        hwnd := ids%A_Index%
        WinGetTitle, titulo, ahk_id %hwnd%
        if (titulo = "" || titulo = "Program Manager" || titulo = "Game Bot - Multi-Instancia (5)")
            continue
        WinGet, estilo, Style, ahk_id %hwnd%
        ; Solo ventanas visibles (WS_VISIBLE)
        if !(estilo & 0x10000000)
            continue
        ; Filtrar ventanas child (auxiliares) y ventanas muy pequeñas
        if (estilo & 0x40000000)  ; WS_CHILD
            continue
        WinGetPos,,, tmpW, tmpH, ahk_id %hwnd%
        if (tmpW < 200 || tmpH < 200)
            continue
        ; Excluir ventanas ya asignadas a OTRAS instancias
        yaAsignada := false
        Loop, %MAX_INST% {
            otroHwnd := Inst_Hwnd[A_Index]
            if (A_Index != i && otroHwnd != 0 && otroHwnd != "" && otroHwnd = hwnd) {
                yaAsignada := true
                break
            }
        }
        if (yaAsignada)
            continue

        ; Obtener PID y clase para distinguir ventanas con mismo título
        WinGet, pid, PID, ahk_id %hwnd%
        WinGetClass, clase, ahk_id %hwnd%
        hwndNum := hwnd + 0
        listaVentanas .= hwndNum . "|" . titulo . "|" . pid . "|" . clase . "`n"
    }

    if (listaVentanas = "") {
        MsgBox, 16, Error, No se encontraron ventanas disponibles.`n`n(Las ventanas ya asignadas a otras instancias se excluyen)
        return
    }

    ; Mostrar GUI de selección
    Gui, SelVent:Destroy
    Gui, SelVent:Font, s9, Segoe UI
    Gui, SelVent:Add, Text,, Selecciona la ventana para instancia #%i%:
    Gui, SelVent:Add, ListBox, w500 h300 vSelVentLista

    Loop, Parse, listaVentanas, `n
    {
        if (A_LoopField = "")
            continue
        partes := StrSplit(A_LoopField, "|")
        hwndItem := partes[1]
        tituloItem := partes[2]
        pidItem := partes[3]
        claseItem := partes[4]
        ; Mostrar título + PID + clase para distinguir ventanas de MuMu con mismo nombre
        entrada := tituloItem . " (PID:" . pidItem . " " . claseItem . ") [" . hwndItem . "]"
        GuiControl, SelVent:, SelVentLista, %entrada%
    }

    Gui, SelVent:Add, Button, w200 gSelVentOK, Seleccionar
    Gui, SelVent:Show,, Detectar Ventana #%i%

    ; Guardar instancia actual para el callback
    global SelVentInstancia := i
    return
}

SelVentOK:
    global SelVentInstancia
    i := SelVentInstancia
    GuiControlGet, seleccion, SelVent:, SelVentLista

    if (seleccion = "") {
        MsgBox, 48, Aviso, Selecciona una ventana de la lista.
        return
    }

    ; Extraer HWND del texto "[hwnd]"
    RegExMatch(seleccion, "\[([^\]]+)\]", m)
    hwndSel := m1 + 0
    if (hwndSel = 0) {
        MsgBox, 16, Error, No se pudo obtener el HWND.
        return
    }

    ; Verificar que no esté asignada a otra instancia
    Loop, %MAX_INST% {
        otroHwnd := Inst_Hwnd[A_Index]
        if (A_Index != i && otroHwnd != 0 && otroHwnd != "" && otroHwnd = hwndSel) {
            MsgBox, 48, Aviso, Esta ventana ya está asignada a la instancia #%A_Index%.
            return
        }
    }

    WinGetTitle, tituloReal, ahk_id %hwndSel%
    Inst_Hwnd[i] := hwndSel
    Inst_Titulo[i] := tituloReal
    GuiControl, Main:, EditVentana%i%, %tituloReal%
    Log("Instancia #" . i . ": Ventana asignada -> " . tituloReal . " (HWND: " . hwndSel . ")")
    FlushLog()

    Gui, SelVent:Destroy
return

SelVentGuiClose:
SelVentGuiEscape:
    Gui, SelVent:Destroy
return

; ============================================================================
; LABEL: Auto-detectar ventanas (buscar todas las del emulador)
; ============================================================================
AutoDetectar:
    Log("Auto-detectando ventanas del emulador...")
    ventanasEncontradas := 0

    ; Patrones comunes de emuladores Android
    patrones := ["MuMu", "BlueStacks", "LDPlayer", "NoxPlayer", "MEmu", "Android", "Nox"]

    WinGet, ids, List
    Loop, %ids% {
        if (ventanasEncontradas >= MAX_INST)
            break
        hwnd := ids%A_Index%
        WinGetTitle, titulo, ahk_id %hwnd%
        if (titulo = "")
            continue
        WinGet, estilo, Style, ahk_id %hwnd%
        if !(estilo & 0x10000000)
            continue
        ; Filtrar ventanas child (auxiliares) y ventanas muy pequeñas
        if (estilo & 0x40000000)  ; WS_CHILD
            continue
        WinGetPos,,, tmpW, tmpH, ahk_id %hwnd%
        if (tmpW < 200 || tmpH < 200)
            continue

        esEmulador := false
        for _, patron in patrones {
            if InStr(titulo, patron) {
                esEmulador := true
                break
            }
        }
        if (!esEmulador)
            continue

        ; Verificar que no esté ya asignada
        yaAsignada := false
        Loop, %MAX_INST% {
            otroHwnd := Inst_Hwnd[A_Index]
            if (otroHwnd != 0 && otroHwnd != "" && otroHwnd = hwnd) {
                yaAsignada := true
                break
            }
        }
        if (yaAsignada)
            continue

        ; Asignar al primer slot libre
        Loop, %MAX_INST% {
            slot := A_Index
            if (Inst_Hwnd[slot] = 0 || Inst_Hwnd[slot] = "") {
                Inst_Hwnd[slot] := hwnd
                Inst_Titulo[slot] := titulo
                GuiControl, Main:, EditVentana%slot%, %titulo%
                Log("Auto-detectado #" . slot . ": " . titulo)
                ventanasEncontradas++
                break
            }
        }
    }

    if (ventanasEncontradas = 0)
        Log("No se encontraron ventanas de emuladores")
    else
        Log(ventanasEncontradas . " ventana(s) detectada(s)")
    FlushLog()
return

; ============================================================================
; LABEL: Auto-acomodar ventanas (misma resolución que #1, lado a lado)
; Usa la resolución de la primera ventana asignada como referencia.
; Las coloca una al lado de la otra horizontalmente; si no caben en la
; pantalla, pasa a la siguiente fila.
; ============================================================================
AutoAcomodar:
    ; Encontrar la primera ventana asignada para usar su tamaño de referencia
    refHwnd := 0
    Loop, %MAX_INST% {
        h := Inst_Hwnd[A_Index]
        if (h != 0 && WinExist("ahk_id " . h)) {
            refHwnd := h
            break
        }
    }
    if (refHwnd = 0) {
        Log("No hay ventanas para acomodar")
        FlushLog()
        return
    }

    WinGetPos,,, refW, refH, ahk_id %refHwnd%
    if (refW < 50 || refH < 50) {
        refW := VentanaAncho
        refH := VentanaAlto
    }
    Log("Acomodando ventanas con resolución de referencia: " . refW . "x" . refH)

    SysGet, monW, 78
    maxCols := monW // refW
    if (maxCols < 1)
        maxCols := 1

    idx := 0
    Loop, %MAX_INST% {
        i := A_Index
        hwnd := Inst_Hwnd[i]
        if (hwnd = 0 || !WinExist("ahk_id " . hwnd))
            continue

        col := Mod(idx, maxCols)
        row := idx // maxCols
        posX := col * refW
        posY := row * refH
        WinMove, ahk_id %hwnd%,, %posX%, %posY%, %refW%, %refH%
        Log("Ventana #" . i . " -> (" . posX . "," . posY . ") " . refW . "x" . refH)
        idx++
    }
    Log(idx . " ventana(s) acomodadas lado a lado (" . refW . "x" . refH . ")")
    FlushLog()
return

; ============================================================================
; LABELS: Cambiar expansión en GUI (per-instancia)
; ============================================================================
CambiarExpGUI1:
    CambiarExpGUI(1)
return
CambiarExpGUI2:
    CambiarExpGUI(2)
return
CambiarExpGUI3:
    CambiarExpGUI(3)
return
CambiarExpGUI4:
    CambiarExpGUI(4)
return
CambiarExpGUI5:
    CambiarExpGUI(5)
return

CambiarExpGUI(i) {
    global BatCnt, BatNom, TotalExpansiones

    GuiControlGet, tmpExp, Main:, DDLExp%i%
    expNum := 1
    Loop, %TotalExpansiones% {
        if InStr(tmpExp, A_Index . ":") {
            expNum := A_Index
            break
        }
    }

    ; Reconstruir dropdown de batallas
    batCount := BatCnt[expNum]
    listaBat := ""
    if (batCount > 0) {
        Loop, %batCount% {
            if (listaBat != "")
                listaBat .= "|"
            listaBat .= A_Index . ": " . BatNom[expNum, A_Index]
        }
    } else {
        listaBat := "(sin batallas)"
    }
    GuiControl, Main:, DDLBat%i%, |%listaBat%
    GuiControl, Main:Choose, DDLBat%i%, 1
}

; ============================================================================
; LABELS: Scroll (compartidos, usan la primera ventana activa para pruebas)
; ============================================================================
SeleccionarPuntoScroll:
    ; Encontrar primera ventana asignada
    hwndScroll := 0
    Loop, %MAX_INST% {
        if (Inst_Hwnd[A_Index] != 0) {
            hwndScroll := Inst_Hwnd[A_Index]
            break
        }
    }
    if (hwndScroll = 0) {
        MsgBox, 16, Error, Primero asigna al menos una ventana.
        return
    }
    if (!WinExist("ahk_id " . hwndScroll)) {
        MsgBox, 16, Error, La ventana asignada no existe.
        return
    }

    Log(">>> Coloca el mouse en el punto de swipe y espera 3 segundos...")
    MsgBox, 64, Seleccionar Punto Swipe, Coloca el mouse sobre el punto de la ventana donde quieres hacer swipe.`n`nTienes 3 segundos después de cerrar este mensaje., 5
    Sleep, 3000

    CoordMode, Mouse, Screen
    MouseGetPos, mouseX, mouseY

    WinGetPos, wx, wy, ww, wh, ahk_id %hwndScroll%
    nuevoX := mouseX - wx
    nuevoY := mouseY - wy

    if (nuevoX < 0 || nuevoY < 0 || nuevoX > ww || nuevoY > wh) {
        MsgBox, 16, Error, El mouse está fuera de la ventana.
        return
    }

    GuiControl, Main:, EditScrollX, %nuevoX%
    GuiControl, Main:, EditScrollY, %nuevoY%
    ScrollRelX := nuevoX
    ScrollRelY := nuevoY
    Log("Punto de swipe: (" . nuevoX . ", " . nuevoY . ")")
    MsgBox, 64, Punto Seleccionado, Punto: X=%nuevoX% Y=%nuevoY%
    FlushLog()
return

ProbarScroll:
    hwndScroll := 0
    Loop, %MAX_INST% {
        if (Inst_Hwnd[A_Index] != 0) {
            hwndScroll := Inst_Hwnd[A_Index]
            break
        }
    }
    if (hwndScroll = 0) {
        MsgBox, 16, Error, Primero asigna al menos una ventana.
        return
    }
    if (!WinExist("ahk_id " . hwndScroll)) {
        MsgBox, 16, Error, La ventana no existe.
        return
    }

    GuiControlGet, tmpScrollX, Main:, EditScrollX
    GuiControlGet, tmpScrollY, Main:, EditScrollY
    GuiControlGet, tmpScrollCant, Main:, EditScrollCant
    tmpScrollX := RegExReplace(tmpScrollX, ",", "") + 0
    tmpScrollY := RegExReplace(tmpScrollY, ",", "") + 0

    Log("Probando swipe en (" . tmpScrollX . ", " . tmpScrollY . ") x" . tmpScrollCant . "...")
    HacerScrollEnVentana(hwndScroll, tmpScrollX, tmpScrollY, tmpScrollCant)
    Log("Swipe de prueba enviado")
    FlushLog()
return

; ============================================================================
; LABELS: ADB
; ============================================================================
DetectarADBBtn:
    if (DetectarADB()) {
        GuiControl, Main:, EditADBRuta, %ADB_Ruta%
        Log("ADB detectado: " . ADB_Ruta)
    } else {
        Log("ERROR: No se encontró adb.exe. Indica la ruta manualmente.")
    }
    FlushLog()
return

ToggleADB:
    GuiControlGet, tmpADB, Main:, ChkADB
    ADB_Habilitado := tmpADB
    if (ADB_Habilitado) {
        GuiControlGet, tmpRuta, Main:, EditADBRuta
        ADB_Ruta := Trim(tmpRuta, " `t`r`n")
        if (ADB_Ruta = "" || !FileExist(ADB_Ruta)) {
            if (!DetectarADB()) {
                Log("ERROR: ADB no encontrado. Desactivando.")
                ADB_Habilitado := false
                GuiControl, Main:, ChkADB, 0
                FlushLog()
                return
            }
            GuiControl, Main:, EditADBRuta, %ADB_Ruta%
        }
        ; Parsear puertos
        GuiControlGet, tmpPuertos, Main:, EditADBPuertos
        StringSplit, pArr, tmpPuertos, `,
        Loop, %MAX_INST% {
            if (A_Index <= pArr0) {
                p := RegExReplace(pArr%A_Index%, "[^0-9]", "") + 0
                Inst_ADB_Puerto[A_Index] := p
            } else {
                Inst_ADB_Puerto[A_Index] := 16384 + (A_Index - 1) * 32
            }
        }
        ; Conectar todas las instancias activas
        Loop, %MAX_INST% {
            if (Inst_Activo[A_Index] || Inst_Hwnd[A_Index])
                ADB_Conectar(A_Index)
        }
        Log("ADB habilitado")
    } else {
        Log("ADB deshabilitado - usando ControlClick")
    }
    FlushLog()
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
