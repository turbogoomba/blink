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

    Process {
        id: proc
        command: ["curl", "-s", "-A", "mac-hypr-rice github.com/turbogoomba",
            `https://api.met.no/weatherapi/locationforecast/2.0/compact?lat=${root.lat}&lon=${root.lon}`]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const now = JSON.parse(text).properties.timeseries[0].data
                    root.temperature = now.instant.details.air_temperature
                    root.symbol = now.next_1_hours?.summary?.symbol_code ?? ""
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

    // Yr-symbol (f.eks. "partlycloudy_day") til et ikonnavn
    readonly property string icon: {
        const s = symbol
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
