pragma Singleton
import QtQuick
import Quickshell

Singleton {
    // Filer på hylla, som file://-adresser
    property var files: []

    function add(urls) {
        const next = [...files]
        for (const u of urls) {
            const s = u.toString()
            if (!next.includes(s)) next.push(s)
        }
        files = next
    }
    function remove(url) { files = files.filter(f => f !== url) }
    function clear() { files = [] }

    function nameOf(url) { return decodeURIComponent(url.split("/").pop()) }
    function isImage(url) { return /\.(png|jpe?g|webp|gif|bmp|svg)$/i.test(url) }
}
