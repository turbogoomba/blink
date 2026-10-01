pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    // Alexander Kiellands plass. Bytt ID for å bruke et annet stopp.
    property string stopId: "NSR:StopPlace:6288"

    property string stopName: ""
    property var departures: []
    property bool loading: false
    property string error: ""
    property date now: new Date()

    function refresh() {
        root.loading = true
        const xhr = new XMLHttpRequest()
        xhr.open("POST", "https://api.entur.io/journey-planner/v3/graphql")
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.setRequestHeader("ET-Client-Name", "herman-mac-hypr-rice")
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            root.loading = false
            if (xhr.status !== 200) {
                root.error = "No connection"
                return
            }
            try {
                const sp = JSON.parse(xhr.responseText).data.stopPlace
                root.stopName = sp.name
                root.departures = sp.estimatedCalls.map(c => ({
                    line: c.serviceJourney.line.publicCode,
                    mode: c.serviceJourney.line.transportMode,
                    dest: c.destinationDisplay.frontText,
                    time: new Date(c.expectedDepartureTime),
                    realtime: c.realtime
                }))
                root.error = ""
            } catch (e) {
                root.error = "Bad response"
            }
        }
        const q = `{ stopPlace(id: "${root.stopId}") { name estimatedCalls(numberOfDepartures: 6) {
            expectedDepartureTime realtime destinationDisplay { frontText }
            serviceJourney { line { publicCode transportMode } } } } }`
        xhr.send(JSON.stringify({ query: q }))
    }

    // Hent nye avganger hvert minutt
    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // Oppdater "om X min" oftere
    Timer {
        interval: 15000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    function minutesUntil(t) {
        return Math.max(0, Math.round((t - now) / 60000))
    }

    // Ruter-farger
    function lineColor(mode) {
        if (mode === "tram") return "#0b91ef"
        if (mode === "metro") return "#ec700c"
        if (mode === "water") return "#682c88"
        return "#e60000"
    }
}
