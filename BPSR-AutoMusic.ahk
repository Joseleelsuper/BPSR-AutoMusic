#Requires AutoHotkey v2.0
#SingleInstance Force

; ==============================================
;  BPSR-AutoMusic
; ----------------------------------------------
;   @name: BPSR-AutoMusic
;   @description: Reproductor de canciones por instrumento.
;   @version: 1.1.0
;   @requires: AutoHotkey v2.0
;   @use:
;       - Numpad1..Numpad9: primer digito = instrumento, resto = cancion.
;       - Espera 700 ms para confirmar el ID introducido.
;       - Numpad0: detiene la reproduccion actual.
;       - F10: cierra el script.
; ==============================================

SendMode("Input")
SetKeyDelay(-1, -1)
CoordMode("Mouse", "Screen")

global Config := Map(
    "InputTimeoutMs", 700,
    "TicksPerQuarter", 384,
    "NoteTapMs", 42,
    "OctaveTapMs", 35,
    "ModeGapMs", 18,
    "RangeClickMs", 55,
    "StartDelayMs", 180,
    "EndPaddingMs", 250,
    "DryRun", false,
    "KeyboardistRangeButtons", Map(
        "left", { x: 455, y: 605 },
        "right", { x: 1835, y: 605 }
    ),
    "LogPath", A_ScriptDir . "\script.log"
)

global InstrumentProfiles := Map(
    "1", Map("name", "Bassist", "engine", ""),
    "2", Map("name", "Drummer", "engine", ""),
    "3", Map("name", "Guitarist", "engine", ""),
    "4", Map("name", "Keyboardist", "engine", "keyboardist")
)

global Songs := CreateSongCatalog()
global State := Map(
    "inputBuffer", "",
    "isPlaying", false,
    "stopRequested", false,
    "pressedKeys", Map(),
    "keyboardistMode", "normal",
    "keyboardistRange", "center"
)

global KeyboardistMap := BuildKeyboardistMap()

#Include "songs\index.ahk"

Init()
OnExit(OnExitHandler)

; ----------------------------
;  Hotkeys
; ----------------------------
Numpad1:: AppendSongDigit("1")
Numpad2:: AppendSongDigit("2")
Numpad3:: AppendSongDigit("3")
Numpad4:: AppendSongDigit("4")
Numpad5:: AppendSongDigit("5")
Numpad6:: AppendSongDigit("6")
Numpad7:: AppendSongDigit("7")
Numpad8:: AppendSongDigit("8")
Numpad9:: AppendSongDigit("9")
Numpad0:: StopPlayback()
F10:: ExitScript()

Init() {
    ValidateSongs()
    Log("INFO", "Inicializado | Canciones registradas: " . CountRegisteredSongs())
    ShowStatus("BPSR-AutoMusic listo")
}

CreateSongCatalog() {
    global InstrumentProfiles

    catalog := Map()
    for instrumentId, _profile in InstrumentProfiles {
        catalog[instrumentId] := Map()
    }
    return catalog
}

CountRegisteredSongs() {
    global Songs

    count := 0
    for _instrumentId, instrumentSongs in Songs {
        count += instrumentSongs.Count
    }
    return count
}

RegisterSong(instrumentId, songId, song) {
    global InstrumentProfiles, Songs

    instrumentId := String(instrumentId)
    songId := String(songId)

    if (!InstrumentProfiles.Has(instrumentId)) {
        throw Error("Instrumento no registrado: " . instrumentId)
    }
    if (!Songs.Has(instrumentId)) {
        Songs[instrumentId] := Map()
    }
    if (Songs[instrumentId].Has(songId)) {
        throw Error("ID de cancion duplicado: " . instrumentId . songId)
    }

    song["id"] := songId
    song["fullId"] := instrumentId . songId
    song["instrumentId"] := instrumentId
    song["instrumentName"] := InstrumentProfiles[instrumentId]["name"]
    Songs[instrumentId][songId] := song
}

AppendSongDigit(digit) {
    global Config, State

    if (State["isPlaying"]) {
        StopPlayback()
    }

    State["inputBuffer"] .= digit
    ShowStatus("Seleccion " . State["inputBuffer"])
    SetTimer(ResolveSongInput, -Config["InputTimeoutMs"])
}

ResolveSongInput() {
    global InstrumentProfiles, Songs, State

    input := State["inputBuffer"]
    State["inputBuffer"] := ""

    if (input = "") {
        return
    }

    if (StrLen(input) < 2) {
        Log("WARN", "Entrada incompleta: " . input)
        ShowStatus("Entrada incompleta: " . input)
        return
    }

    instrumentId := SubStr(input, 1, 1)
    songId := SubStr(input, 2)

    if (!InstrumentProfiles.Has(instrumentId)) {
        Log("WARN", "Instrumento no registrado: " . instrumentId)
        ShowStatus("Instrumento " . instrumentId . " no registrado")
        return
    }

    profile := InstrumentProfiles[instrumentId]
    if (!Songs.Has(instrumentId) || !Songs[instrumentId].Has(songId)) {
        Log("WARN", "No hay cancion registrada con ID " . input . " | instrumento=" . profile["name"] . " cancion=" .
            songId)
        ShowStatus(profile["name"] . " " . songId . " no registrada")
        return
    }

    PlaySong(Songs[instrumentId][songId])
}

PlaySong(song) {
    global InstrumentProfiles

    profile := InstrumentProfiles[song["instrumentId"]]
    engine := profile["engine"]

    if (engine = "") {
        Log("WARN", "Instrumento sin motor implementado: " . profile["name"])
        ShowStatus(profile["name"] . " aun no soportado")
        return
    }

    switch engine {
        case "keyboardist":
            KeyboardistPlaySong(song)
        default:
            Log("ERROR", "Motor de instrumento invalido: " . engine)
            ShowStatus("Motor no soportado: " . engine)
    }
}

KeyboardistPlaySong(song) {
    global Config, State

    events := DecodeSongEvents(song)
    State["isPlaying"] := true
    State["stopRequested"] := false
    State["tempoBpm"] := song["tempoBpm"]
    State["ticksPerQuarter"] := song.Has("ticksPerQuarter") ? song["ticksPerQuarter"] : Config["TicksPerQuarter"]

    Log("INFO", "Reproduciendo ID " . song["fullId"] . " | " . song["title"] . " | " . song["instrumentName"])
    ShowStatus("Reproduciendo " . song["fullId"] . ": " . song["title"])

    try {
        SleepInterruptible(Config["StartDelayMs"])

        for event in events {
            if (!SleepInterruptible(TicksToMs(event.delta))) {
                break
            }

            if (State["stopRequested"]) {
                break
            }

            KeyboardistTapNotes(event.notes)
            event.played := true
        }

        if (!State["stopRequested"] && events.Length > 0) {
            lastEvent := events[events.Length]
            SleepInterruptible(TicksToMs(lastEvent.maxDur) + Config["EndPaddingMs"])
        }
    } catch as e {
        Log("ERROR", "Fallo durante reproduccion: " . e.Message)
        ShowStatus("Error reproduciendo cancion")
    } finally {
        KeyboardistCleanup()
        State["isPlaying"] := false
        State["stopRequested"] := false
        State["keyboardistMode"] := "normal"
        State["keyboardistRange"] := "center"
        State.Delete("tempoBpm")
        State.Delete("ticksPerQuarter")
        Log("INFO", "Reproduccion finalizada: " . song["title"])
    }
}

StopPlayback() {
    global State

    State["inputBuffer"] := ""
    State["stopRequested"] := true
    KeyboardistCleanup()
    Log("INFO", "Reproduccion detenida")
    ShowStatus("Reproduccion detenida")
}

DecodeSongEvents(song) {
    if (song.Has("parsedEvents")) {
        return song["parsedEvents"]
    }

    events := []
    for line in song["events"] {
        line := Trim(line)
        if (line = "") {
            continue
        }

        parts := StrSplit(line, "|")
        if (parts.Length != 2) {
            throw Error("Evento invalido en " . song["title"] . ": " . line)
        }

        delta := Integer(parts[1])
        notes := []
        maxDur := 0

        for token in StrSplit(parts[2], ",") {
            noteParts := StrSplit(token, ":")
            if (noteParts.Length != 2) {
                throw Error("Nota invalida en " . song["title"] . ": " . token)
            }

            midi := Integer(noteParts[1])
            dur := Integer(noteParts[2])
            notes.Push({ midi: midi, dur: dur })
            maxDur := Max(maxDur, dur)
        }

        events.Push({ delta: delta, notes: notes, maxDur: maxDur })
    }

    song["parsedEvents"] := events
    return events
}

ValidateSongs() {
    global InstrumentProfiles, Songs

    if (CountRegisteredSongs() = 0) {
        throw Error("No hay canciones registradas.")
    }

    for instrumentId, instrumentSongs in Songs {
        if (!InstrumentProfiles.Has(instrumentId)) {
            throw Error("Catalogo con instrumento desconocido: " . instrumentId)
        }

        profile := InstrumentProfiles[instrumentId]
        for songId, song in instrumentSongs {
            ValidateSongMetadata(songId, song)

            switch profile["engine"] {
                case "keyboardist":
                    KeyboardistValidateSong(song)
            }
        }
    }
}

ValidateSongMetadata(songId, song) {
    for field in ["id", "fullId", "instrumentId", "instrumentName", "title", "composer", "catalog", "source",
        "tempoBpm", "arrangement", "events"] {
        if (!song.Has(field)) {
            throw Error("La cancion " . songId . " no tiene el campo requerido: " . field)
        }
    }

    if (song["tempoBpm"] <= 0) {
        throw Error("Tempo invalido en " . song["title"])
    }

    events := DecodeSongEvents(song)
    if (events.Length = 0) {
        throw Error("La cancion " . song["title"] . " no tiene eventos.")
    }

    for event in events {
        if (event.delta < 0) {
            throw Error("Delta negativo en " . song["title"])
        }
        if (event.maxDur <= 0) {
            throw Error("Duracion invalida en " . song["title"])
        }
        for note in event.notes {
            if (note.dur <= 0) {
                throw Error("Duracion de nota invalida en " . song["title"] . ": MIDI " . note.midi)
            }
        }
    }
}

KeyboardistValidateSong(song) {
    global KeyboardistMap

    events := DecodeSongEvents(song)
    for event in events {
        for note in event.notes {
            if (!KeyboardistMap.Has(note.midi)) {
                throw Error("Nota fuera de rango en " . song["title"] . ": MIDI " . note.midi)
            }
        }
    }
}

KeyboardistTapNotes(notes) {
    global Config

    groups := Map()

    for note in notes {
        mapping := KeyboardistMapNoteToKey(note.midi)
        groupId := mapping.range . "|" . mapping.mode

        if (!groups.Has(groupId)) {
            groups[groupId] := { range: mapping.range, mode: mapping.mode, keys: [] }
        }
        if (!ArrayHas(groups[groupId].keys, mapping.key)) {
            groups[groupId].keys.Push(mapping.key)
        }
    }

    for range in ["left", "center", "right"] {
        for mode in ["low", "normal", "high"] {
            groupId := range . "|" . mode
            if (!groups.Has(groupId)) {
                continue
            }

            group := groups[groupId]
            KeyboardistApplyRange(group.range)
            KeyboardistApplyOctaveMode(group.mode)
            if (!SleepInterruptible(Config["ModeGapMs"])) {
                return
            }

            for key in group.keys {
                SendKeyDown(key)
            }

            if (!SleepInterruptible(Config["NoteTapMs"])) {
                for key in group.keys {
                    SendKeyUp(key)
                }
                return
            }

            for key in group.keys {
                SendKeyUp(key)
            }
        }
    }

    KeyboardistApplyOctaveMode("normal")
}

KeyboardistMapNoteToKey(midi) {
    global KeyboardistMap
    return KeyboardistMap[midi]
}

BuildKeyboardistMap() {
    result := Map()
    loop 88 {
        midi := 20 + A_Index
        result[midi] := BuildKeyboardistMapping(midi)
    }
    return result
}

BuildKeyboardistMapping(midi) {
    octave := Floor(midi / 12) - 1
    semitone := Mod(midi, 12)

    if (midi >= 21 && midi <= 35) {
        return { key: KeyboardistKeyForSemitone(semitone, octave + 1), mode: "normal", range: "left" }
    }
    if (midi >= 36 && midi <= 47) {
        return { key: KeyboardistKeyForSemitone(semitone, 1), mode: "low", range: "center" }
    }
    if (midi >= 48 && midi <= 83) {
        return { key: KeyboardistKeyForSemitone(semitone, octave - 2), mode: "normal", range: "center" }
    }
    if (midi >= 84 && midi <= 95) {
        return { key: KeyboardistKeyForSemitone(semitone, 3), mode: "high", range: "center" }
    }
    if (midi >= 96 && midi <= 108) {
        return { key: KeyboardistKeyForSemitone(semitone, octave - 5), mode: "normal", range: "right" }
    }

    throw Error("MIDI fuera de rango Keyboardist: " . midi)
}

KeyboardistKeyForSemitone(semitone, row) {
    naturalKeys := Map(
        0, ["z", "a", "q"],
        2, ["x", "s", "w"],
        4, ["c", "d", "e"],
        5, ["v", "f", "r"],
        7, ["b", "g", "t"],
        9, ["n", "h", "y"],
        11, ["m", "j", "u"]
    )
    sharpKeys := Map(
        1, ["1", "6", "i"],
        3, ["2", "7", "o"],
        6, ["3", "8", "p"],
        8, ["4", "9", "vkDB"],
        10, ["5", "0", "vkDD"]
    )

    source := naturalKeys.Has(semitone) ? naturalKeys : sharpKeys
    if (!source.Has(semitone)) {
        throw Error("Semitono no mapeado: " . semitone)
    }
    if (row < 1 || row > 3) {
        throw Error("Fila de teclado invalida: " . row)
    }

    return source[semitone][row]
}

KeyboardistApplyRange(range) {
    global State

    current := State["keyboardistRange"]
    if (current = range) {
        return
    }

    switch current {
        case "center":
            switch range {
                case "left":
                    KeyboardistTapRangeButton("left")
                case "right":
                    KeyboardistTapRangeButton("right")
                default:
                    throw Error("Rango Keyboardist invalido: " . range)
            }
        case "left":
            switch range {
                case "center":
                    KeyboardistTapRangeButton("right")
                case "right":
                    KeyboardistTapRangeButton("right")
                    KeyboardistTapRangeButton("right")
                default:
                    throw Error("Rango Keyboardist invalido: " . range)
            }
        case "right":
            switch range {
                case "center":
                    KeyboardistTapRangeButton("left")
                case "left":
                    KeyboardistTapRangeButton("left")
                    KeyboardistTapRangeButton("left")
                default:
                    throw Error("Rango Keyboardist invalido: " . range)
            }
        default:
            throw Error("Estado de rango Keyboardist invalido: " . current)
    }

    State["keyboardistRange"] := range
}

KeyboardistTapRangeButton(button) {
    global Config

    point := Config["KeyboardistRangeButtons"][button]
    if (!Config["DryRun"]) {
        Click(point.x . " " . point.y)
    }
    Sleep(Config["RangeClickMs"])
}

KeyboardistApplyOctaveMode(mode) {
    global State

    if (State["keyboardistMode"] = mode) {
        return
    }

    switch mode {
        case "low":
            TapOctaveKey("LCtrl")
        case "high":
            TapOctaveKey("LShift")
        case "normal":
            switch State["keyboardistMode"] {
                case "low":
                    TapOctaveKey("LCtrl")
                case "high":
                    TapOctaveKey("LShift")
            }
        default:
            throw Error("Modo de octava invalido: " . mode)
    }

    State["keyboardistMode"] := mode
}

TapOctaveKey(key) {
    global Config

    if (!Config["DryRun"]) {
        Send("{" . key . " down}")
    }
    Sleep(Config["OctaveTapMs"])
    if (!Config["DryRun"]) {
        Send("{" . key . " up}")
    }
}

SendKeyDown(key) {
    global Config, State

    if (State["pressedKeys"].Has(key)) {
        return
    }

    if (!Config["DryRun"]) {
        Send("{" . key . " down}")
    }
    State["pressedKeys"][key] := true
}

SendKeyUp(key) {
    global Config, State

    if (!State["pressedKeys"].Has(key)) {
        return
    }

    if (!Config["DryRun"]) {
        Send("{" . key . " up}")
    }
    State["pressedKeys"].Delete(key)
}

KeyboardistCleanup() {
    global Config, State

    keysToRelease := ["z", "x", "c", "v", "b", "n", "m",
        "a", "s", "d", "f", "g", "h", "j", "q", "w", "e", "r", "t", "y", "u",
        "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "i", "o", "p", "vkDB", "vkDD"]

    for key in keysToRelease {
        if (!Config["DryRun"]) {
            Send("{" . key . " up}")
        }
    }

    State["pressedKeys"] := Map()
    KeyboardistApplyOctaveMode("normal")
    KeyboardistApplyRange("center")

    if (!Config["DryRun"]) {
        Send("{LCtrl up}")
        Send("{LShift up}")
    }
}

SleepInterruptible(durationMs) {
    global State

    remaining := Max(0, durationMs)
    while (remaining > 0) {
        if (State["stopRequested"]) {
            return false
        }

        chunk := Min(remaining, 25)
        Sleep(chunk)
        remaining -= chunk
    }
    return !State["stopRequested"]
}

TicksToMs(ticks) {
    global Config, State

    tempoBpm := State.Has("tempoBpm") ? State["tempoBpm"] : 72
    ticksPerQuarter := State.Has("ticksPerQuarter") ? State["ticksPerQuarter"] : Config["TicksPerQuarter"]

    return Round((ticks / ticksPerQuarter) * (60000 / tempoBpm))
}

ArrayHas(items, needle) {
    for item in items {
        if (item = needle) {
            return true
        }
    }
    return false
}

ShowStatus(text, durationMs := 1200) {
    ToolTip(text)
    SetTimer(ClearStatus, -durationMs)
}

ClearStatus() {
    ToolTip()
}

Log(type, msg) {
    global Config

    type := StrUpper(type)
    stamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
    line := "[" . stamp . "] [" . type . "] " . msg . "`r`n"

    try {
        FileAppend(line, Config["LogPath"], "UTF-8")
    } catch as e {
    }
}

ExitScript() {
    Log("EXIT", "F10 presionado -> saliendo")
    StopPlayback()
    ExitApp()
}

OnExitHandler(reason, exitCode) {
    KeyboardistCleanup()
    Log("EXIT", "OnExit -> razon=" . reason . " | code=" . exitCode)
}
