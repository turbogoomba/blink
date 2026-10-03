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
        command: ["curl", "-s", "-A", "mac-hypr-rice github.com/turbogoomba",
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
