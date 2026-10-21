import QtQuick
import qs.Modules.Plugins

PluginSettings {
    pluginId: "dayzWallpapers"
    StringSetting {
        settingKey: "directory"
        label: "Pasta das coleções"
        description: "Caminho absoluto. Cada pasta vira uma categoria; padrão: ~/Pictures/Wallpapers."
        defaultValue: ""
    }
    StringSetting {
        settingKey: "excludedFolders"
        label: "Pastas ignoradas"
        description: "Nomes separados por vírgula. Útil para pastas com links de uma galeria agregada."
        defaultValue: ""
    }
}
