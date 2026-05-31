# Plantilla de Script AutoHotkey v2.0+

Plantilla base modular y bien documentada para crear scripts de automatización con AutoHotkey v2.0+. Incluye funcionalidades comunes como detección de ventana, escalado automático de coordenadas, sistema de logging, y gestión de colores.

## 📋 Características

- ✅ **Escalado automático**: Define coordenadas en 1920x1080 y se escalan automáticamente a cualquier resolución
- ✅ **Detección de ventana**: Detecta automáticamente la ventana del juego/aplicación con fallback a pantalla completa
- ✅ **Sistema de logging**: Registro detallado de eventos con timestamps
- ✅ **Gestión de colores**: Funciones para detección y comparación de colores con tolerancia RGB
- ✅ **Configuración centralizada**: Todos los parámetros en un solo lugar (Config)
- ✅ **Gestión de estado**: Sistema de estados para tracking de ejecución
- ✅ **Cooldowns incorporados**: Sistema de cooldown para evitar spam de acciones
- ✅ **Hotkeys estándar**: F9 para activar/desactivar, F10 para salir

## 🚀 Inicio Rápido

### 1. Personalizar la configuración inicial

Edita la sección de inicialización en `main.ahk`:

```ahk
; En la función Init():

; Definir ejecutables de la aplicación objetivo
Config["GameWindowExecutables"] := ["MiJuego.exe", "MiApp.exe"]

; Definir colores a detectar
Config["Colors"]["botonVerde"] := 0x00FF00
Config["Colors"]["indicadorRojo"] := 0xFF0000

; Definir puntos de interés (coordenadas en 1920x1080)
Config["PointsBase"]["botonAceptar"] := { x: 960, y: 540 }
Config["PointsBase"]["targetCheck"] := { x: 1500, y: 800 }

; Definir áreas rectangulares para búsqueda de píxeles
Config["AreasBase"]["zonaDeteccion"] := { x1: 800, y1: 400, x2: 1120, y2: 680 }
```

### 2. Implementar la lógica principal

Edita la función `CheckLogic()` con tu lógica de automatización:

```ahk
CheckLogic() {
    global Config, State

    if (!State["toggle"]) {
        return
    }

    ; Ejemplo: Detectar color en punto y ejecutar acción
    if (CheckColorAtPoint("botonAceptar", Config["Colors"]["botonVerde"])) {
        if (CheckCooldown()) {
            ClickPoint("botonAceptar")
            UpdateActionTime()
            Log("ACTION", "Botón aceptar presionado")
        }
    }

    ; Ejemplo: Buscar píxel en área y ejecutar acción
    pixel := FindPixelInArea("zonaDeteccion", Config["Colors"]["indicadorRojo"])
    if (pixel) {
        Log("DETECT", "Píxel rojo encontrado en " . pixel.x . ", " . pixel.y)
        Click(pixel.x . " " . pixel.y)
    }
}
```

### 3. Ajustar timings según necesidad

```ahk
; En Init():
Config["TimerInterval"] := 50           ; Ajustar frecuencia del bucle (ms)
Config["Timings"]["cooldown"] := 2000   ; Ajustar cooldown global (ms)
Config["Tolerance"]["primary"] := 20    ; Ajustar tolerancia de colores
```

## 📚 Funciones Principales

### Detección de Colores

```ahk
; Obtener color en coordenadas específicas
color := GetColorAtXY(100, 200)

; Obtener color en punto configurado
color := GetColorAtPoint("nombrePunto")

; Verificar si un color coincide en un punto
if (CheckColorAtPoint("nombrePunto", 0xFF0000)) {
    ; Color detectado
}

; Comparar dos colores con tolerancia
if (ColorCloseEnough(color1, color2, 15)) {
    ; Colores similares
}
```

### Búsqueda de Píxeles

```ahk
; Buscar píxel de color específico en área rectangular
pixel := FindPixelInArea("nombreArea", 0xFFFFFF)
if (pixel) {
    ; pixel.x, pixel.y contienen las coordenadas
    ; pixel.color contiene el color encontrado
}
```

### Clicks y Acciones

```ahk
; Click en punto configurado
ClickPoint("nombrePunto")

; Click en coordenadas específicas
Click(500 . " " . 300)
```

### Cooldowns

```ahk
; Verificar cooldown global
if (CheckCooldown()) {
    ; Ejecutar acción
    UpdateActionTime()  ; Actualizar timestamp
}

; Verificar cooldown personalizado
if (CheckCooldown(3000)) {  ; 3 segundos
    ; Ejecutar acción
    UpdateActionTime()
}
```

### Logging

```ahk
Log("INFO", "Mensaje informativo")
Log("WARN", "Advertencia")
Log("ERROR", "Error detectado")
Log("ACTION", "Acción ejecutada")
```

## 🎮 Uso

1. **Activar/Desactivar**: Pulsa `F9` para iniciar o detener la automatización
2. **Salir**: Pulsa `F10` para cerrar el script completamente
3. **Ver logs**: Revisa `script.log` en la carpeta del script

## ⚙️ Estructura del Código

```
main.ahk
├── Directivas (#Requires, #SingleInstance, CoordMode)
├── Variables Globales (Config, State)
├── Init() - Inicialización de configuración
├── DetectGameWindow() - Detección de ventana objetivo
├── RebuildScaledPoints() - Escalado de coordenadas
├── Hotkeys (F9, F10)
├── ToggleAutomation() - Activación/desactivación
├── CheckLogic() - BUCLE PRINCIPAL (personalizar aquí)
├── Funciones de Utilidad
│   ├── Colores (GetColorAtXY, ColorCloseEnough, etc.)
│   ├── Píxeles (FindPixelInArea)
│   ├── Acciones (ClickPoint)
│   └── Cooldowns (CheckCooldown, UpdateActionTime)
├── SafeCleanup() - Limpieza al desactivar
├── Log() - Sistema de logging
└── OnExitHandler() - Limpieza al cerrar
```

## 📝 TODOs al Personalizar

Busca los comentarios `TODO` en el código para identificar las secciones a personalizar:

1. ✏️ **Header**: Actualizar nombre, descripción, autor
2. ✏️ **Ejecutables**: Agregar ejecutables del juego/app objetivo
3. ✏️ **Colores**: Definir colores específicos a detectar
4. ✏️ **Puntos**: Definir coordenadas de interés (1920x1080)
5. ✏️ **Áreas**: Definir áreas rectangulares de búsqueda
6. ✏️ **Timings**: Ajustar intervalos y cooldowns
7. ✏️ **CheckLogic()**: Implementar lógica de automatización
8. ✏️ **SafeCleanup()**: Agregar limpieza personalizada si es necesaria

## 🔍 Consejos

- **Depuración**: Activa los logs (`Config["LoggingEnabled"] := true`) durante desarrollo
- **Coordenadas**: Usa Window Spy (incluido con AHK) para obtener coordenadas
- **Colores**: Usa Window Spy o herramientas como ColorPic para obtener códigos hexadecimales
- **Tolerancia**: Si la detección de color es inestable, aumenta la tolerancia
- **Timer**: Ajusta `TimerInterval` según la frecuencia de comprobación necesaria (menor = más rápido pero más CPU)
- **Cooldowns**: Usa cooldowns para evitar spam de acciones y dar tiempo a la aplicación de responder

## 🛠️ Solución de Problemas

### El script no detecta la ventana
- Verifica que el nombre del ejecutable en `Config["GameWindowExecutables"]` sea correcto
- Abre el juego/app ANTES de ejecutar el script
- Revisa `script.log` para ver mensajes de advertencia

### Los clicks no llegan a las coordenadas correctas
- Verifica que las coordenadas base estén en formato 1920x1080
- Asegúrate de que la ventana esté en modo ventana o sin bordes (no fullscreen exclusivo)
- Revisa el log para verificar la escala calculada

### La detección de colores falla
- Verifica el código hexadecimal del color con Window Spy
- Aumenta la tolerancia en `Config["Tolerance"]["primary"]`
- Usa logs para verificar el color actual: `Log("DEBUG", Format("{:06X}", GetColorAtPoint("punto")))`

## 📄 Licencia

Plantilla libre para uso personal y comercial.

## 🤝 Créditos

Basado en patrones de:
- AutoResources.ahk
- BPSR-AutoDungeons.ahk
- AutoFishing.ahk

---

**¡Feliz automatización! 🚀**
