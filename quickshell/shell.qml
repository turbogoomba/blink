import QtQuick
import QtQml
import "./settings" as SettingsUI
import "./services" as Services
import "./theme" as Theme

Item {
	Component.onCompleted: {
		console.log("Shell started")
		console.log("accent color:", Theme.Tokens.accent)
	}
	SettingsUI.Settings {
		visible: true
	}
}
