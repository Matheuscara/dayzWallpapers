import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Modules.Plugins

PluginComponent {
    id: root
    property bool opened: false
    property var targetScreen: null
    property var images: []
    property var folders: []
    property string selectedCategory: ""
    property string errorText: ""
    property bool choosing: false
    property bool choiceScheduled: false
    property string choiceRoot: ""
    property string choiceCategory: ""
    property string choiceMode: "random"
    property string choiceScreen: ""
    property var queuedRequest: null
    property bool awaitingResult: false
    property bool streamDone: false
    property bool processDone: false
    property int processCode: 0
    property string resultText: ""
    property bool timedOut: false
    property string selectedPath: ""
    property bool ready: false
    readonly property string directory: String(pluginData.directory || (Quickshell.env("HOME") + "/Pictures/Wallpapers"))
    readonly property string excludedFolders: String(pluginData.excludedFolders || "")
    readonly property bool rotationEnabled: pluginData.rotationEnabled === true
    readonly property int rotationMinutes: Math.max(1, Math.min(1440, Number(pluginData.rotationMinutes) || 30))
    readonly property string rotationCategory: String(pluginData.rotationCategory || "")
    readonly property string rotationMode: pluginData.rotationMode === "sequential" ? "sequential" : "random"
    readonly property string rotationScreen: String(pluginData.rotationScreen || "")
    readonly property bool loading: scanner.running || awaitingResult
    readonly property var categories: [{id: "", name: "Todas", count: images.length}].concat(folders)
    readonly property var filteredImages: images.filter(image => !selectedCategory || image.category === selectedCategory)
    readonly property string helper: decodeURIComponent(Qt.resolvedUrl("wallpapers.py").toString().replace(/^file:\/\//, ""))

    function save(key, value) {
        if (pluginService && pluginId)
            pluginService.savePluginData(pluginId, key, value);
    }

    function currentWallpaper(screenName) {
        return SessionData.perMonitorWallpaper && screenName ? SessionData.getMonitorWallpaper(screenName) : SessionData.wallpaperPath;
    }

    function show() {
        targetScreen = CompositorService.getFocusedScreen() || Quickshell.screens[0];
        opened = true;
        scan(false, selectedCategory, "random", targetScreen?.name || "");
    }

    function close() { opened = false; }
    function toggle() { if (opened) close(); else show(); }

    function scan(pick, category, mode, screenName, path, scheduled) {
        if (loading) {
            queuedRequest = {pick: pick, category: category, mode: mode, screen: screenName, path: path || "", scheduled: scheduled === true};
            return;
        }
        awaitingResult = true;
        streamDone = false;
        processDone = false;
        processCode = 0;
        timedOut = false;
        resultText = "";
        selectedPath = path || "";
        choosing = pick;
        choiceScheduled = scheduled === true;
        choiceRoot = directory;
        choiceCategory = category || "";
        choiceMode = mode || "random";
        choiceScreen = screenName || "";
        errorText = "";
        const argv = ["python3", helper, "--root", directory, "--exclude", excludedFolders];
        if (selectedPath)
            argv.push("--select", selectedPath);
        else if (pick)
            argv.push("--pick", "--category", choiceCategory, "--mode", choiceMode, "--current", currentWallpaper(choiceScreen) || "");
        scanner.command = argv;
        scanner.running = true;
        Qt.callLater(() => {
            if (root.awaitingResult && !scanner.running && !root.processDone) {
                root.processCode = 1;
                root.processDone = true;
                root.streamDone = true;
                root.finishScan();
            }
        });
    }

    function select(path, screenName) {
        scan(true, "", "selected", screenName, path);
    }

    function drainQueue() {
        if (!loading && queuedRequest) {
            const request = queuedRequest;
            queuedRequest = null;
            scan(request.pick, request.category, request.mode, request.screen, request.path, request.scheduled);
        }
    }

    function finishScan() {
        if (!awaitingResult || !streamDone || !processDone)
            return;
        if (choiceRoot !== directory) {
            awaitingResult = false;
            Qt.callLater(drainQueue);
            return;
        }
        if (timedOut) {
            errorText = "A leitura demorou demais. Escolha uma pasta menor e tente novamente.";
        } else if (processCode !== 0) {
            errorText = "Falha ao carregar a coleção (Python 3).";
        } else {
            try {
                const result = JSON.parse(resultText);
                if (result.version !== 1 || !Array.isArray(result.images) || !Array.isArray(result.categories))
                    throw new Error("Formato inválido");
                images = result.images;
                folders = result.categories;
                errorText = result.error || (result.warnings || []).join(" · ");
                if (selectedCategory && !folders.some(folder => folder.id === selectedCategory))
                    selectedCategory = "";
                const validSchedule = !choiceScheduled || (rotationEnabled && choiceCategory === rotationCategory && choiceMode === rotationMode && choiceScreen === rotationScreen);
                if (choosing && !result.error && validSchedule) {
                    if (result.choice) {
                        if (apply(result.choice, choiceScreen) && choiceMode === "selected")
                            close();
                    } else {
                        errorText = "Nenhuma imagem disponível; atualize a categoria ou escolha outra imagem.";
                    }
                }
            } catch (_) {
                errorText = "Não foi possível ler a coleção. Verifique a pasta e o Python 3.";
            }
        }
        awaitingResult = false;
        Qt.callLater(drainQueue);
    }

    function apply(path, screenName) {
        if (!images.some(image => image.path === path)) {
            errorText = "A imagem não está mais na coleção. Atualize a lista.";
            return false;
        }
        if (SessionData.perMonitorWallpaper && screenName) {
            if (!Quickshell.screens.some(screen => screen.name === screenName)) {
                errorText = "O monitor escolhido não está conectado.";
                return false;
            }
            SessionData.setMonitorWallpaper(screenName, path);
        } else {
            SessionData.setWallpaper(path);
        }
        if (rotationEnabled)
            rotation.restart();
        return true;
    }

    function randomNow() {
        scan(true, selectedCategory, "random", targetScreen?.name || "");
    }

    function configureRotation(enabled, minutes, category, mode) {
        const value = Number(minutes);
        if (!Number.isInteger(value) || value < 1 || value > 1440 || ["random", "sequential"].indexOf(mode) === -1) {
            errorText = "Informe um intervalo inteiro de 1 a 1440 minutos.";
            return false;
        }
        if (!categories.some(item => item.id === category)) {
            errorText = "A categoria escolhida não está disponível.";
            return false;
        }
        save("rotationMinutes", value);
        save("rotationCategory", category);
        save("rotationMode", mode);
        save("rotationScreen", targetScreen?.name || "");
        if (enabled && SessionData.wallpaperCyclingEnabled)
            SessionData.setWallpaperCyclingEnabled(false);
        save("rotationEnabled", enabled);
        if (enabled)
            rotation.restart();
        return true;
    }

    function rotate() {
        if (rotationEnabled)
            scan(true, rotationCategory, rotationMode, rotationScreen, "", true);
    }

    onDirectoryChanged: if (ready) scan(false, "", "random", "")
    onExcludedFoldersChanged: if (ready) scan(false, "", "random", "")
    onLoadingChanged: {
        if (loading)
            scanTimeout.restart();
        else {
            scanTimeout.stop();
            Qt.callLater(drainQueue);
        }
    }
    Component.onCompleted: {
        ready = true;
        Qt.callLater(() => root.scan(false, "", "random", ""));
    }

    Process {
        id: scanner
        stdout: StdioCollector {
            onStreamFinished: {
                root.resultText = text;
                root.streamDone = true;
                root.finishScan();
            }
        }
        stderr: StdioCollector {}
        onExited: (exitCode, exitStatus) => {
            root.processCode = exitCode;
            root.processDone = true;
            root.finishScan();
        }
    }

    Timer {
        id: scanTimeout
        interval: 20000
        onTriggered: {
            root.timedOut = true;
            if (scanner.running)
                scanner.running = false;
            else {
                root.processDone = true;
                root.streamDone = true;
                root.finishScan();
            }
        }
    }
    Timer {
        id: rotation
        interval: root.rotationMinutes * 60000
        running: root.rotationEnabled
        repeat: true
        onTriggered: root.rotate()
    }
    WallpaperPicker { id: picker; controller: root }
    IpcHandler {
        target: "dayzWallpapers"
        function open(): string { root.show(); return "opened"; }
        function close(): string { root.close(); return "closed"; }
        function toggle(): string { root.toggle(); return root.opened ? "opened" : "closed"; }
        function collection(directory: string, excluded: string): string {
            if (!directory.startsWith("/"))
                return "ERROR: caminho absoluto necessário";
            root.save("directory", directory);
            root.save("excludedFolders", excluded);
            return "configured";
        }
        function select(path: string): string {
            root.targetScreen = CompositorService.getFocusedScreen() || Quickshell.screens[0];
            root.select(path, root.targetScreen?.name || "");
            return "selecting";
        }
        function schedule(minutes: string, category: string, mode: string): string {
            root.targetScreen = CompositorService.getFocusedScreen() || Quickshell.screens[0];
            return root.configureRotation(true, Number(minutes), category, mode) ? "scheduled" : "ERROR: configuração inválida";
        }
        function settings(): string { root.show(); Qt.callLater(picker.openSchedule); return "opened"; }
        function refresh(): string { root.scan(false, "", "random", ""); return "refreshing"; }
        function pause(): string { root.save("rotationEnabled", false); return "paused"; }
        function status(): string {
            return JSON.stringify({open: root.opened, images: root.images.length, categories: root.folders.length, loading: root.loading, rotationEnabled: root.rotationEnabled, intervalMinutes: root.rotationMinutes, category: root.rotationCategory, mode: root.rotationMode, previewState: picker.previewState, error: root.errorText});
        }
    }
}
