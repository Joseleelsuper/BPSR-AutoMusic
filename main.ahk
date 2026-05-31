#Requires AutoHotkey v2.0
#SingleInstance Force

; ==============================================
;  [NOMBRE DEL SCRIPT]
; ----------------------------------------------
;   @name: [nombre-del-proyecto].ahk
;   @description: [Descripción breve de lo que hace el script]
;   @author: [Tu nombre]
;   @version: 1.0.0
;   @date: [Fecha]
;   @use
;       - Pulsa F9 para activar/desactivar la automatización.
;       - Pulsa F10 para detener el script completamente.
;       - [Instrucciones adicionales específicas del script]
; ==============================================

CoordMode("Pixel", "Screen")
CoordMode("Mouse", "Screen")

; ----------------------------
;  Configuración y Estado
; ----------------------------
global Config := Map()
global State := Map()

; ============================
;  Inicialización
; ============================
Init() {
    global Config, State

    ; -- Parámetros base de referencia (resolución estándar)
    Config["Base"] := { w: 1920, h: 1080 }

    ; -- Temporizadores y tolerancias
    Config["TimerInterval"] := 50            ; ms entre ciclos de comprobación (ajustar según necesidad)
    Config["Tolerance"] := { primary: 15 }   ; tolerancia para comparación de colores

    ; -- Tiempos de espera (centralizados en ms)
    Config["Timings"] := Map()
    Config["Timings"]["clickDelay"] := 50       ; espera antes/después de clicks
    Config["Timings"]["afterAction"] := 200     ; espera tras ejecutar una acción
    Config["Timings"]["cooldown"] := 1000       ; cooldown entre acciones repetidas
    ; TODO: Agregar más timings según necesidades del proyecto

    ; -- Colores objetivo (formato 0xRRGGBB)
    Config["Colors"] := Map()
    Config["Colors"]["target"] := 0xFFFFFF   ; Ejemplo: blanco
    ; TODO: Definir colores específicos a detectar

    ; -- Lista de posibles ejecutables del juego/aplicación
    Config["GameWindowExecutables"] := ["BPSR_STEAM.exe", "BPSR_EPIC.exe", "BPSR.exe"]

    ; -- Coordenadas base (en 1920x1080) - Todas se escalarán automáticamente
    Config["PointsBase"] := Map()
    ; TODO: Definir puntos de interés, ej:
    ; Config["PointsBase"]["botonAceptar"] := { x: 960, y: 540 }
    ; Config["PointsBase"]["targetArea"] := { x1: 100, y1: 100, x2: 200, y2: 200 }

    ; -- Áreas rectangulares base (opcional, para búsquedas de píxeles)
    Config["AreasBase"] := Map()
    ; TODO: Definir áreas de búsqueda, ej:
    ; Config["AreasBase"]["zonaDeteccion"] := { x1: 800, y1: 400, x2: 1120, y2: 680 }

    ; -- Flag para habilitar/deshabilitar logs
    Config["LoggingEnabled"] := true
    ; -- Ruta de log
    Config["LogPath"] := A_ScriptDir . "\script.log"

    ; -- Detectar ventana del juego y obtener dimensiones
    DetectGameWindow()

    ; -- Calcular escala basada en el tamaño de la ventana detectada
    Config["Scale"] := { 
        x: (Config["GameWindow"].w + 0.0) / Config["Base"].w,
        y: (Config["GameWindow"].h + 0.0) / Config["Base"].h
    }

    ; -- Precalcular puntos escalados relativos a la ventana
    Config["Points"] := Map()
    RebuildScaledPoints()

    ; -- Estado inicial
    State["toggle"] := false          ; Automatización activa/inactiva
    State["lastActionTime"] := 0      ; Timestamp de la última acción (para cooldowns)
    ; TODO: Agregar variables de estado según necesidades

    Log("INFO", "Init completado | Ventana: " . Config["GameWindow"].w . "x" . Config["GameWindow"].h 
        . " @ (" . Config["GameWindow"].x . "," . Config["GameWindow"].y . ")"
        . " | Escala: " . Round(Config["Scale"].x, 3) . "x" . Round(Config["Scale"].y, 3))
}

; ============================
;  Detección de Ventana
; ============================
; Detecta la ventana del juego/aplicación y guarda su posición y tamaño
DetectGameWindow() {
    global Config

    hwnd := 0
    detectedExe := ""

    ; Intentar detectar la ventana con cada ejecutable posible
    if (Config["GameWindowExecutables"].Length > 0) {
        for index, exeName in Config["GameWindowExecutables"] {
            try {
                hwnd := WinGetID("ahk_exe " . exeName)
                if (hwnd) {
                    detectedExe := exeName
                    Log("INFO", "Ventana detectada: " . exeName)
                    break
                }
            }
        }
    }

    if (hwnd) {
        ; Obtener posición y tamaño de la ventana
        WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " . hwnd)

        ; Obtener el área cliente (sin bordes de ventana)
        rect := Buffer(16, 0)
        DllCall("GetClientRect", "Ptr", hwnd, "Ptr", rect)
        clientW := NumGet(rect, 8, "Int")
        clientH := NumGet(rect, 12, "Int")

        ; Obtener offset del área cliente respecto a la ventana
        point := Buffer(8, 0)
        DllCall("ClientToScreen", "Ptr", hwnd, "Ptr", point)
        clientX := NumGet(point, 0, "Int")
        clientY := NumGet(point, 4, "Int")

        Config["GameWindow"] := { 
            x: clientX, 
            y: clientY, 
            w: clientW, 
            h: clientH, 
            hwnd: hwnd,
            exe: detectedExe 
        }
        Log("INFO", "Área cliente: " . clientW . "x" . clientH . " @ (" . clientX . "," . clientY . ")")
    } else {
        ; Si no se encuentra ninguna ventana, usar pantalla completa como fallback
        Config["GameWindow"] := { 
            x: 0, 
            y: 0, 
            w: A_ScreenWidth, 
            h: A_ScreenHeight, 
            hwnd: 0,
            exe: "ninguno" 
        }

        if (Config["GameWindowExecutables"].Length > 0) {
            exeList := ""
            for index, exeName in Config["GameWindowExecutables"] {
                exeList .= exeName
                if (index < Config["GameWindowExecutables"].Length)
                    exeList .= ", "
            }
            Log("WARN", "No se detectó ventana. Buscados: " . exeList . " -> Usando pantalla completa")
        } else {
            Log("WARN", "Sin ejecutables configurados -> Usando pantalla completa")
        }
    }
}

; ============================
;  Escalado de Coordenadas
; ============================
; Recalcula todos los puntos y áreas escalados según la ventana detectada
RebuildScaledPoints() {
    global Config

    ; Escalar puntos individuales
    for pointName, basePt in Config["PointsBase"] {
        if (basePt.HasOwnProp("x1")) {
            ; Es un área rectangular (x1, y1, x2, y2)
            Config["Points"][pointName] := {
                x1: Round(basePt.x1 * Config["Scale"].x) + Config["GameWindow"].x,
                y1: Round(basePt.y1 * Config["Scale"].y) + Config["GameWindow"].y,
                x2: Round(basePt.x2 * Config["Scale"].x) + Config["GameWindow"].x,
                y2: Round(basePt.y2 * Config["Scale"].y) + Config["GameWindow"].y
            }
        } else {
            ; Es un punto individual (x, y)
            Config["Points"][pointName] := {
                x: Round(basePt.x * Config["Scale"].x) + Config["GameWindow"].x,
                y: Round(basePt.y * Config["Scale"].y) + Config["GameWindow"].y
            }
        }
    }

    ; Escalar áreas rectangulares (si existen)
    if (Config.Has("AreasBase")) {
        Config["Areas"] := Map()
        for areaName, baseArea in Config["AreasBase"] {
            Config["Areas"][areaName] := {
                x1: Round(baseArea.x1 * Config["Scale"].x) + Config["GameWindow"].x,
                y1: Round(baseArea.y1 * Config["Scale"].y) + Config["GameWindow"].y,
                x2: Round(baseArea.x2 * Config["Scale"].x) + Config["GameWindow"].x,
                y2: Round(baseArea.y2 * Config["Scale"].y) + Config["GameWindow"].y
            }
        }
    }
}

; ============================
;  Inicialización y Salida
; ============================
Init()
OnExit(OnExitHandler)

; ============================
;  Hotkeys
; ============================
F9::ToggleAutomation()
F10::ExitScript()

; ============================
;  Toggle de Automatización
; ============================
ToggleAutomation() {
    global Config, State

    State["toggle"] := !State["toggle"]
    if (State["toggle"]) {
        Log("INFO", "Script ACTIVADO -> Iniciando timer (" . Config["TimerInterval"] . " ms)")
        SetTimer(CheckLogic, Config["TimerInterval"])
        ; TODO: Agregar inicialización adicional si es necesaria
    } else {
        Log("INFO", "Script DESACTIVADO -> Deteniendo timer")
        SetTimer(CheckLogic, 0)
        SafeCleanup()
    }
}

; ============================
;  Bucle Principal
; ============================
CheckLogic() {
    global Config, State

    if (!State["toggle"]) {
        return
    }

    ; TODO: Implementar la lógica principal del script aquí
    ; Ejemplos de tareas comunes:
    ; 1. Detectar colores en puntos específicos
    ; 2. Buscar píxeles en áreas rectangulares
    ; 3. Ejecutar acciones basadas en detecciones
    ; 4. Gestionar cooldowns y delays

    ; Ejemplo de estructura básica:
    ; if (CheckColorAtPoint("nombrePunto", Config["Colors"]["target"])) {
    ;     ExecuteAction()
    ; }
}

; ============================
;  Funciones de Utilidad
; ============================

; Obtiene el color en coordenadas específicas
GetColorAtXY(x, y) {
    return PixelGetColor(x, y, "RGB")
}

; Obtiene el color en un punto configurado
GetColorAtPoint(pointName) {
    global Config
    if (!Config["Points"].Has(pointName)) {
        Log("ERROR", "Punto '" . pointName . "' no existe")
        return 0
    }
    pt := Config["Points"][pointName]
    return GetColorAtXY(pt.x, pt.y)
}

; Compara si dos colores son similares dentro de una tolerancia
ColorCloseEnough(color1, color2, tolerance := 10) {
    c1r := (color1 >> 16) & 0xFF
    c1g := (color1 >> 8) & 0xFF
    c1b := color1 & 0xFF
    c2r := (color2 >> 16) & 0xFF
    c2g := (color2 >> 8) & 0xFF
    c2b := color2 & 0xFF
    return (Abs(c1r - c2r) <= tolerance)
        && (Abs(c1g - c2g) <= tolerance)
        && (Abs(c1b - c2b) <= tolerance)
}

; Verifica si el color en un punto coincide con el objetivo
CheckColorAtPoint(pointName, targetColor, tolerance := -1) {
    global Config
    if (tolerance = -1) {
        tolerance := Config["Tolerance"]["primary"]
    }
    currentColor := GetColorAtPoint(pointName)
    return ColorCloseEnough(currentColor, targetColor, tolerance)
}

; Busca un píxel de color específico en un área rectangular
FindPixelInArea(areaName, targetColor, tolerance := -1) {
    global Config
    if (tolerance = -1) {
        tolerance := Config["Tolerance"]["primary"]
    }
    
    if (!Config.Has("Areas") || !Config["Areas"].Has(areaName)) {
        Log("ERROR", "Área '" . areaName . "' no existe")
        return false
    }

    area := Config["Areas"][areaName]
    
    ; Iterar por cada píxel del área
    Loop area.y2 - area.y1 + 1 {
        y := area.y1 + A_Index - 1
        Loop area.x2 - area.x1 + 1 {
            x := area.x1 + A_Index - 1
            color := GetColorAtXY(x, y)
            if (ColorCloseEnough(color, targetColor, tolerance)) {
                return { x: x, y: y, color: color }
            }
        }
    }
    return false
}

; Click en un punto configurado
ClickPoint(pointName) {
    global Config
    if (!Config["Points"].Has(pointName)) {
        Log("ERROR", "Punto '" . pointName . "' no existe para click")
        return false
    }
    pt := Config["Points"][pointName]
    Click(pt.x . " " . pt.y)
    Sleep(Config["Timings"]["clickDelay"])
    return true
}

; Verifica cooldown antes de ejecutar acción
CheckCooldown(cooldownMs := -1) {
    global Config, State
    if (cooldownMs = -1) {
        cooldownMs := Config["Timings"]["cooldown"]
    }
    currentTime := A_TickCount
    timeSinceLast := currentTime - State["lastActionTime"]
    return (timeSinceLast >= cooldownMs)
}

; Actualiza el timestamp de última acción
UpdateActionTime() {
    global State
    State["lastActionTime"] := A_TickCount
}

; ============================
;  Limpieza y Salida
; ============================

; Limpia el estado al desactivar el script
SafeCleanup() {
    global State
    ; TODO: Liberar recursos, resetear estados, etc.
    Log("INFO", "SafeCleanup: estado limpiado")
}

; Sale del script
ExitScript() {
    global State
    Log("EXIT", "F10 presionado -> Saliendo")
    if (State.Has("toggle") && State["toggle"]) {
        SetTimer(CheckLogic, 0)
        State["toggle"] := false
    }
    SafeCleanup()
    ExitApp
}

; ============================
;  Sistema de Logs
; ============================

Log(type, msg) {
    global Config
    if (!Config.Has("LoggingEnabled") || !Config["LoggingEnabled"]) {
        return
    }
    type := StrUpper(type)
    stamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
    line := "[" . stamp . "] [" . type . "] " . msg . "`r`n"
    try {
        FileAppend(line, Config["LogPath"], "UTF-8")
    } catch as e {
        ; Si falla el logging, no detener el script
    }
}

OnExitHandler(reason, exitCode) {
    Log("EXIT", "OnExit -> Razón=" . reason . " | Code=" . exitCode)
}
