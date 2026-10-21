import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Common
import qs.Widgets

PanelWindow {
    id: overlay
    required property var controller
    property bool scheduleOpen: false
    property string draftCategory: ""
    property string draftMode: "random"
    readonly property int previewState: carousel.currentItem?.imageStatus ?? -1
    readonly property var selected: controller.filteredImages[carousel.currentIndex] || null
    readonly property real cardWidth: Math.max(220, Math.min(400, width * 0.26))
    readonly property real cardHeight: Math.min(280, Math.max(150, height * (scheduleOpen ? 0.25 : 0.32)))
    screen: controller.targetScreen || Quickshell.screens[0]
    visible: controller.opened
    color: "transparent"
    anchors { left: true; right: true; top: true; bottom: true }
    WlrLayershell.namespace: "dms:dayzWallpapers"
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    function openSchedule() {
        draftCategory = controller.rotationEnabled ? controller.rotationCategory : controller.selectedCategory;
        draftMode = controller.rotationMode;
        minutesField.text = String(controller.rotationMinutes);
        scheduleOpen = true;
    }

    function syncSelection() {
        const current = controller.currentWallpaper(screen?.name || "");
        const index = controller.filteredImages.findIndex(image => image.path === current);
        carousel.currentIndex = index >= 0 ? index : 0;
    }
    function move(step) {
        const count = controller.filteredImages.length;
        if (count)
            carousel.currentIndex = (carousel.currentIndex + step + count) % count;
    }
    function selectCurrent() {
        if (previewState === Image.Error) {
            controller.errorText = "Esta imagem não pôde ser aberta. Escolha outra ou atualize a lista.";
            return;
        }
        if (selected)
            controller.select(selected.path, screen?.name || "");
    }
    onVisibleChanged: {
        if (visible) {
            scheduleOpen = false;
            focusScope.forceActiveFocus();
            Qt.callLater(syncSelection);
        }
    }
    Connections {
        target: overlay.controller
        function onFilteredImagesChanged() { Qt.callLater(overlay.syncSelection); }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.withAlpha(Theme.surface, 0.90)
        MouseArea { anchors.fill: parent; onClicked: overlay.controller.close() }
    }
    FocusScope {
        id: focusScope
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_Escape: overlay.controller.close(); break;
            case Qt.Key_Right: overlay.move(1); break;
            case Qt.Key_Left: overlay.move(-1); break;
            case Qt.Key_Return:
            case Qt.Key_Enter: overlay.selectCurrent(); break;
            default: return;
            }
            event.accepted = true;
        }
        Column {
            id: panel
            anchors.centerIn: parent
            width: Math.min(1400, parent.width - Theme.spacingXL * 2)
            spacing: Theme.spacingM

            Row {
                width: parent.width
                spacing: Theme.spacingM
                Column {
                    width: parent.width - closeButton.width - Theme.spacingM
                    spacing: Theme.spacingXS
                    StyledText {
                        text: "Dayz Wallpapers"
                        font.pixelSize: Theme.fontSizeXLarge
                        font.weight: Font.Medium
                    }
                    StyledText {
                        text: overlay.controller.images.length + " imagens · " + overlay.controller.folders.length + " categorias · " + (overlay.screen?.name || "Monitor atual")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }
                }
                WallpaperButton {
                    id: closeButton
                    text: "Fechar"
                    iconName: "close"
                    onClicked: overlay.controller.close()
                }
            }

            Flickable {
                width: parent.width
                height: Math.min(categoryFlow.implicitHeight, overlay.height * 0.18)
                contentHeight: categoryFlow.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Flow {
                    id: categoryFlow
                    width: parent.width
                    spacing: Theme.spacingS
                    Repeater {
                        model: overlay.controller.categories
                        WallpaperButton {
                            required property var modelData
                            readonly property bool selected: overlay.controller.selectedCategory === modelData.id
                            text: modelData.name + " · " + modelData.count
                            buttonHeight: Theme.fontSizeSmall + Theme.spacingL * 1.5
                            backgroundColor: selected ? Theme.primary : Theme.surfaceContainerHigh
                            textColor: selected ? Theme.primaryText : Theme.surfaceText
                            onClicked: overlay.controller.selectedCategory = modelData.id
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: overlay.cardHeight + Theme.spacingXL
                PathView {
                    id: carousel
                    x: (parent.width - width) / 2
                    width: overlay.width
                    height: parent.height
                    model: overlay.visible ? overlay.controller.filteredImages : []
                    pathItemCount: Math.min(width < 1600 ? 5 : (width < 2600 ? 7 : 9), count)
                    preferredHighlightBegin: 0.5
                    preferredHighlightEnd: 0.5
                    highlightRangeMode: PathView.StrictlyEnforceRange
                    snapMode: PathView.SnapOneItem
                    highlightMoveDuration: Theme.shortDuration
                    path: Path {
                        startX: 0
                        startY: carousel.height / 2
                        PathLine { x: carousel.width; y: carousel.height / 2 }
                    }
                    delegate: Item {
                        id: card
                        required property var modelData
                        required property int index
                        readonly property int imageStatus: preview.status
                        readonly property bool selected: PathView.isCurrentItem
                        width: overlay.cardWidth
                        height: overlay.cardHeight
                        z: selected ? 2 : 1
                        scale: selected ? 1 : 0.87
                        opacity: selected ? 1 : 0.54
                        Behavior on scale { NumberAnimation { duration: Theme.shortDuration } }
                        Behavior on opacity { NumberAnimation { duration: Theme.shortDuration } }
                        transform: Matrix4x4 {
                            matrix: Qt.matrix4x4(1, -0.16, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                        }
                        ClippingRectangle {
                            anchors.fill: parent
                            radius: Theme.cornerRadius
                            color: Theme.surfaceContainerHigh
                            CachingImage {
                                id: preview
                                anchors.fill: parent
                                imagePath: card.modelData.path
                                maxCacheSize: 512
                                fillMode: Image.PreserveAspectCrop
                            }
                            StyledText {
                                anchors.centerIn: parent
                                visible: preview.status !== Image.Ready
                                text: preview.status === Image.Loading ? "Carregando…" : "Miniatura indisponível"
                                font.pixelSize: Theme.fontSizeSmall
                            }
                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                radius: Theme.cornerRadius
                                border.width: card.selected ? 2 : 1
                                border.color: card.selected ? Theme.primary : Theme.outlineMedium
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (card.selected)
                                        overlay.selectCurrent();
                                    else
                                        carousel.currentIndex = index;
                                }
                            }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        onWheel: wheel => {
                            overlay.move(wheel.angleDelta.y > 0 ? -1 : 1);
                            wheel.accepted = true;
                        }
                    }
                }
                Column {
                    anchors.centerIn: parent
                    spacing: Theme.spacingM
                    visible: overlay.controller.filteredImages.length === 0
                    DankIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: overlay.controller.loading ? "folder_open" : "image_not_supported"
                        size: Theme.iconSizeLarge
                        color: Theme.surfaceVariantText
                    }
                    StyledText {
                        text: overlay.controller.loading ? "Lendo suas pastas…" : "Nenhuma imagem nesta pasta"
                        font.pixelSize: Theme.fontSizeMedium
                    }
                }
            }
            StyledText {
                width: parent.width
                text: overlay.controller.errorText || (overlay.selected ? overlay.selected.name + " · " + (overlay.selected.category === "." ? "Arquivos soltos" : overlay.selected.category) : "Configure a pasta nas preferências do plugin e clique em Atualizar.")
                textFormat: Text.PlainText
                font.pixelSize: Theme.fontSizeSmall
                color: overlay.controller.errorText ? Theme.warning : Theme.surfaceVariantText
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideMiddle
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.spacingS
                WallpaperButton {
                    text: "Aplicar"
                    iconName: "check"
                    enabled: overlay.selected !== null && overlay.previewState !== Image.Error
                    backgroundColor: Theme.primary
                    textColor: Theme.primaryText
                    onClicked: overlay.selectCurrent()
                }
                WallpaperButton {
                    text: "Aleatório agora"
                    iconName: "shuffle"
                    enabled: !overlay.controller.loading && overlay.controller.filteredImages.length > 0
                    onClicked: overlay.controller.randomNow()
                }
                WallpaperButton {
                    text: overlay.controller.rotationEnabled ? "Agendamento ativo" : "Agendar troca"
                    iconName: "schedule"
                    onClicked: {
                        if (overlay.scheduleOpen)
                            overlay.scheduleOpen = false;
                        else
                            overlay.openSchedule();
                    }
                }
                WallpaperButton {
                    text: "Atualizar"
                    iconName: "refresh"
                    enabled: !overlay.controller.loading
                    onClicked: overlay.controller.scan(false, "", "random", "")
                }
                WallpaperButton {
                    text: "Abrir pasta"
                    iconName: "folder_open"
                    onClicked: Qt.openUrlExternally("file://" + overlay.controller.directory.split("/").map(encodeURIComponent).join("/"))
                }
            }
            Rectangle {
                width: parent.width
                height: scheduleContent.implicitHeight + Theme.spacingL * 2
                visible: overlay.scheduleOpen
                color: Theme.surfaceContainer
                radius: Theme.cornerRadius
                border.width: 1
                border.color: Theme.outlineMedium
                Column {
                    id: scheduleContent
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM
                    Row {
                        width: parent.width
                        spacing: Theme.spacingM
                        Column {
                            spacing: Theme.spacingXS
                            StyledText { text: "Categoria da troca"; font.pixelSize: Theme.fontSizeSmall }
                            DankDropdown {
                                width: Math.min(360, panel.width * 0.29)
                                dropdownWidth: width
                                options: overlay.controller.categories.map(item => item.name)
                                currentValue: overlay.controller.categories.find(item => item.id === overlay.draftCategory)?.name || "Todas"
                                onValueChanged: value => overlay.draftCategory = overlay.controller.categories.find(item => item.name === value)?.id || ""
                            }
                        }
                        Column {
                            spacing: Theme.spacingXS
                            StyledText { text: "Ordem"; font.pixelSize: Theme.fontSizeSmall }
                            DankDropdown {
                                width: 180
                                dropdownWidth: width
                                options: ["Aleatória", "Em sequência"]
                                currentValue: overlay.draftMode === "sequential" ? "Em sequência" : "Aleatória"
                                onValueChanged: value => overlay.draftMode = value === "Em sequência" ? "sequential" : "random"
                            }
                        }
                        Column {
                            spacing: Theme.spacingXS
                            StyledText { text: "Intervalo em minutos"; font.pixelSize: Theme.fontSizeSmall }
                            DankTextField {
                                id: minutesField
                                width: 160
                                height: 40
                                text: "30"
                                maximumLength: 4
                                validator: IntValidator { bottom: 1; top: 1440 }
                            }
                        }
                        WallpaperButton {
                            anchors.bottom: parent.bottom
                            text: overlay.controller.rotationEnabled ? "Salvar intervalo" : "Ativar troca"
                            iconName: "play_arrow"
                            backgroundColor: Theme.primary
                            textColor: Theme.primaryText
                            onClicked: overlay.controller.configureRotation(true, Number(minutesField.text), overlay.draftCategory, overlay.draftMode)
                        }
                        WallpaperButton {
                            anchors.bottom: parent.bottom
                            visible: overlay.controller.rotationEnabled
                            text: "Pausar"
                            iconName: "pause"
                            onClicked: overlay.controller.save("rotationEnabled", false)
                        }
                    }
                    StyledText {
                        width: parent.width
                        text: overlay.controller.rotationEnabled ? "Ativo: a cada " + overlay.controller.rotationMinutes + " min · " + (overlay.controller.categories.find(item => item.id === overlay.controller.rotationCategory)?.name || "Categoria indisponível") + " · " + (overlay.controller.rotationMode === "sequential" ? "em sequência" : "aleatório") + ". Continua com o seletor fechado." : "A troca começa depois do intervalo escolhido. Funciona enquanto o DMS estiver aberto."
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                    }
                }
            }
            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "← → navegar · Enter aplicar · Esc fechar · pastas viram categorias automaticamente"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }
        }
    }
}
