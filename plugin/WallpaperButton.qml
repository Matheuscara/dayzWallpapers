import QtQuick
import qs.Common
import qs.Widgets

DankButton {
    backgroundColor: Theme.surfaceContainerHigh
    textColor: Theme.surfaceText
    activeFocusOnTab: enabled && visible
    border.width: activeFocus ? 2 : 0
    border.color: Theme.primary
    Accessible.role: Accessible.Button
    Accessible.name: text
    Keys.onReturnPressed: clicked()
    Keys.onSpacePressed: clicked()
}
