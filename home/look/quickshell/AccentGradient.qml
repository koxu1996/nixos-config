// AccentGradient.qml: the theme's strong highlight, lime -> deeper lime, left to right.
// Use as `gradient: AccentGradient {}`; put Theme.textOnAccent text on top of it.
import QtQuick

Gradient {
    orientation: Gradient.Horizontal
    GradientStop { position: 0.0; color: Theme.accent }
    GradientStop { position: 1.0; color: Theme.accentEnd }
}
