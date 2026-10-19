// ToastCard.qml: one toast (delegate of the toast ListViews in Toasts.qml).
// NotificationCard content + drop shadow + countdown line; hover pauses the countdown.
// When it runs out the toast hides, but the notification stays tracked (Active).
import QtQuick
import QtQuick.Effects

Item {
    id: toast

    // ListModel roles (NotificationService.criticalToasts / normalToasts).
    required property int key
    required property int timeout   // ms; 0 = never hides on its own
    required property bool critical

    readonly property var n: NotificationService.notificationFor(key)
    property real remaining: 1

    width: 360
    height: card.implicitHeight

    // Enter: fade, scale and a small downward slide.
    opacity: 0
    scale: 0.94
    transform: Translate { id: slide; y: -6 }
    ParallelAnimation {
        id: enter
        NumberAnimation { target: toast; property: "opacity"; to: 1; duration: Theme.durationNormal; easing.type: Easing.OutCubic }
        NumberAnimation { target: toast; property: "scale"; to: 1; duration: Theme.durationNormal; easing.type: Easing.OutCubic }
        NumberAnimation { target: slide; property: "y"; to: 0; duration: Theme.durationNormal; easing.type: Easing.OutCubic }
    }

    Component.onCompleted: {
        enter.start();
        if (timeout > 0) countdown.start();
    }

    NumberAnimation {
        id: countdown
        target: toast
        property: "remaining"
        from: 1
        to: 0
        duration: Math.max(1, toast.timeout)
        paused: running && hover.hovered
        onFinished: NotificationService.hideToast(toast.key)
    }

    // An update in place (same id, or same stacking tag) restarts the countdown.
    Connections {
        target: toast.n
        ignoreUnknownSignals: true
        function onSummaryChanged() { if (toast.timeout > 0) countdown.restart(); }
        function onBodyChanged() { if (toast.timeout > 0) countdown.restart(); }
        function onHintsChanged() { if (toast.timeout > 0) countdown.restart(); }
    }

    HoverHandler { id: hover }

    NotificationCard {
        id: card
        width: parent.width
        notification: toast.n
        toast: true

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Theme.shadow
            shadowBlur: 0.8
            shadowVerticalOffset: 4
        }

        // Countdown line along the bottom edge.
        Rectangle {
            visible: toast.timeout > 0
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 1
            x: Theme.radiusLarge
            width: parent.width - Theme.radiusLarge * 2
            height: 2
            radius: 1
            color: Theme.borderSubtle

            Rectangle {
                width: parent.width * toast.remaining
                height: parent.height
                radius: 1
                color: Theme.textDisabled
            }
        }
    }
}
