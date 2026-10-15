pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Alexander Kiellands plass
    property real lat: 59.93
    property real lon: 10.75

    property real temperature: NaN
    property string symbol: ""
    readonly property bool ready: !isNaN(temperature)

    // For the weather sheet
    property var hours: []      // next 12 hours: { time, temp, symbol, rain }
    property var days: []       // next 5 days:   { date, min, max, symbol }
    property real wind: NaN
    property real humidity: NaN
    property real feelsLike: NaN
    property string updated: ""

    function refresh() { proc.running = true }

    Process {
        id: proc
        command: ["curl", "-s", "-A", "blink github.com/turbogoomba/blink",
            `https://api.met.no/weatherapi/locationforecast/2.0/compact?lat=${root.lat}&lon=${root.lon}`]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const ts = JSON.parse(text).properties.timeseries
                    const now = ts[0].data
                    const d = now.instant.details
                    root.temperature = d.air_temperature
                    root.symbol = now.next_1_hours?.summary?.symbol_code ?? ""
                    root.wind = d.wind_speed ?? NaN
                    root.humidity = d.relative_humidity ?? NaN
                    root.feelsLike = root.feels(d.air_temperature, d.wind_speed ?? 0)
                    root.updated = Qt.formatTime(new Date(), "HH:mm")

                    root.hours = ts.slice(0, 12).map(e => ({
                        time: new Date(e.time),
                        temp: e.data.instant.details.air_temperature,
                        symbol: e.data.next_1_hours?.summary?.symbol_code
                            ?? e.data.next_6_hours?.summary?.symbol_code ?? "",
                        rain: e.data.next_1_hours?.details?.precipitation_amount ?? 0
                    }))

                    // Group by day: min/max, and the symbol closest to midday
                    const byDay = {}
                    for (const e of ts) {
                        const t = new Date(e.time)
                        const key = t.getFullYear() + "-" + t.getMonth() + "-" + t.getDate()
                        const temp = e.data.instant.details.air_temperature
                        const sym = e.data.next_6_hours?.summary?.symbol_code
                            ?? e.data.next_1_hours?.summary?.symbol_code ?? ""
                        if (!byDay[key]) byDay[key] = { date: t, min: temp, max: temp, symbol: sym, dist: 99 }
                        const day = byDay[key]
                        day.min = Math.min(day.min, temp)
                        day.max = Math.max(day.max, temp)
                        const dist = Math.abs(t.getHours() - 12)
                        if (sym !== "" && dist < day.dist) { day.symbol = sym; day.dist = dist }
                    }
                    root.days = Object.values(byDay).slice(0, 5)
                } catch (e) {
                    console.log("Weather: could not read response")
                }
            }
        }
    }

    // Oppdater hver halvtime
    Timer {
        interval: 30 * 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: proc.running = true
    }

    // Simple wind-chill style "feels like"
    function feels(t, wind) {
        if (t > 10 || wind < 1.3) return t
        const v = Math.pow(wind * 3.6, 0.16)
        return 13.12 + 0.6215 * t - 11.37 * v + 0.3965 * t * v
    }

    // Yr symbol to a short description
    function describe(s) {
        if (!s) return ""
        if (s.includes("thunder")) return "Thunder"
        if (s.startsWith("clearsky")) return "Clear"
        if (s.startsWith("fair")) return "Fair"
        if (s.startsWith("partlycloudy")) return "Partly cloudy"
        if (s.startsWith("cloudy")) return "Cloudy"
        if (s.startsWith("fog")) return "Fog"
        if (s.includes("sleet")) return "Sleet"
        if (s.includes("snow")) return s.startsWith("heavy") ? "Heavy snow" : s.startsWith("light") ? "Light snow" : "Snow"
        if (s.includes("rain")) return s.startsWith("heavy") ? "Heavy rain" : s.startsWith("light") ? "Light rain" : "Rain"
        return ""
    }

    readonly property string description: describe(symbol)

    // Yr-symbol (f.eks. "partlycloudy_day") til et ikonnavn
    readonly property string icon: iconFor(symbol)

    // The same, as a line icon (SVG path) for LineIcon, so it follows the theme's colors
    readonly property string glyph: glyphFor(symbol)
    readonly property var glyphs: ({
        sun:     "M12 8a4 4 0 1 0 0 8a4 4 0 1 0 0-8M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4",
        moon:    "M20 14A8 8 0 1 1 10 4a7 7 0 0 0 10 10z",
        partly:  "M8 6V4M3.5 7.5L5 9M2 12h2M15.5 7a4.5 4.5 0 0 0-8.4 2.2M7 19h10a4 4 0 0 0 0-8 5 5 0 0 0-9.6 1.5A3.3 3.3 0 0 0 7 19z",
        partlyN: "M10.5 3.5A4 4 0 0 0 15 9a4 4 0 0 1-4.5-5.5zM7 19h10a4 4 0 0 0 0-8 5 5 0 0 0-9.6 1.5A3.3 3.3 0 0 0 7 19z",
        cloud:   "M7 18h10a4 4 0 0 0 0-8 6 6 0 0 0-11.5 1.5A3.5 3.5 0 0 0 7 18z",
        rain:    "M7 15h10a4 4 0 0 0 0-8 6 6 0 0 0-11.5 1.5A3.5 3.5 0 0 0 7 15zM8 18l-1 3M12 18l-1 3M16 18l-1 3",
        snow:    "M7 15h10a4 4 0 0 0 0-8 6 6 0 0 0-11.5 1.5A3.5 3.5 0 0 0 7 15zM8 19h.01M12 21h.01M16 19h.01",
        thunder: "M7 15h10a4 4 0 0 0 0-8 6 6 0 0 0-11.5 1.5A3.5 3.5 0 0 0 7 15zM13 15l-3 4h4l-3 4",
        fog:     "M4 9h16M6 13h12M5 17h14"
    })
    function glyphFor(s) {
        s = s || ""
        const night = s.endsWith("_night")
        if (s.startsWith("clearsky") || s.startsWith("fair")) return night ? glyphs.moon : glyphs.sun
        if (s.startsWith("partlycloudy")) return night ? glyphs.partlyN : glyphs.partly
        if (s.startsWith("fog")) return glyphs.fog
        if (s.includes("thunder")) return glyphs.thunder
        if (s.includes("snow") || s.includes("sleet")) return glyphs.snow
        if (s.includes("rain")) return glyphs.rain
        return glyphs.cloud
    }

    function iconFor(s) {
        s = s || ""
        const night = s.endsWith("_night")
        if (s.startsWith("clearsky") || s.startsWith("fair"))
            return night ? "weather-clear-night-symbolic" : "weather-clear-symbolic"
        if (s.startsWith("partlycloudy"))
            return night ? "weather-few-clouds-night-symbolic" : "weather-few-clouds-symbolic"
        if (s.startsWith("cloudy")) return "weather-overcast-symbolic"
        if (s.startsWith("fog")) return "weather-fog-symbolic"
        if (s.includes("thunder")) return "weather-storm-symbolic"
        if (s.includes("snow") || s.includes("sleet")) return "weather-snow-symbolic"
        if (s.includes("rain")) return "weather-showers-symbolic"
        return "weather-overcast-symbolic"
    }
}
