// Theme.qml: design tokens for every bar component. Use them as `Theme.<name>`.
//
// Dark, low-contrast slate base with a single acid-lime accent, amber for
// warnings and coral for errors. Pick tokens by role, not by look:
// a new component should never need a hex literal.
//
// Colours with alpha use Qt's #AARRGGBB order (CSS #ffffff0a is "#0affffff"),
// or Theme.alpha(colour, opacity).
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    // ---- Surfaces -----------------------------------------------------------
    readonly property color base: "#12151b"    // bar background
    readonly property color raised: "#161a21"  // widgets on the bar, popups, OSD
    readonly property color raisedHigh: "#1b2028" // chips on top of a raised surface
    readonly property color inset: "#0c0e12"   // nested cards / buttons inside a raised panel
    readonly property color border: "#2a2f38"  // 1px borders and dividers
    readonly property color borderSubtle: "#22262e" // borders of inset cards inside a popup
    readonly property color track: "#252a32"   // progress tracks, inactive bars
    readonly property color hover: "#0affffff" // hover wash over any surface (white 4%)
    readonly property color chipHover: "#29ffffff" // bar chips on hover / with their popup open (white 16%)
    readonly property color shadow: "#73000000" // drop shadows (black 45%)
    readonly property color notchFill: "#000000" // the bar row while a window is fullscreen (blends with the notch)

    // ---- Text -----------------------------------------------------------------
    readonly property color textPrimary: "#eef0f3"   // titles, values
    readonly property color textSecondary: "#8a919b" // metadata, occupied-but-inactive
    readonly property color textDisabled: "#5f6670"  // empty, muted, pending
    readonly property color textFaint: "#3a404a"     // out-of-range items, e.g. other months' days

    // ---- Accents --------------------------------------------------------------
    readonly property color accent: "#c5f36a"   // active, focused, success, progress
    readonly property color accentBg: "#262d1d" // subtle chips / selected items (lime text on it)
    readonly property color accentEnd: "#8fd14f" // deeper lime, end of AccentGradient
    readonly property color textOnAccent: "#12151b" // text and icons on accent / AccentGradient
    // Strong highlight (active workspace pill, level fills): `gradient: AccentGradient {}`,
    // a horizontal accent -> accentEnd gradient defined in AccentGradient.qml.
    readonly property color warning: "#f5a524"  // urgent, timers, battery low
    readonly property color error: "#f2706a"    // errors, destructive or "off" states (mute)

    // ---- Shape ----------------------------------------------------------------
    readonly property int borderWidth: 1
    readonly property int radiusLarge: 14 // popups, cards
    readonly property int radius: 10      // widgets on the bar
    readonly property int radiusSmall: 7  // chips, buttons, inner pills
    readonly property int barItemHeight: 26
    readonly property int popupPadding: 14 // inner padding of popup cards
    readonly property int popupSpacing: 14 // vertical gap between popup sections
    readonly property int popupGap: 8      // space between a bar chip and the popup it opens

    // ---- Type -----------------------------------------------------------------
    readonly property string monoFont: "JetBrains Mono" // every number, time and value
    readonly property string sansFont: "Inter"          // labels and titles
    // Titles use Inter's regular weight. Avoid `font.bold: true`: Inter is a variable
    // font and Qt renders its bold double-bold (too heavy and narrow).
    readonly property int fontSize: 12
    readonly property int fontSizeSmall: 10
    readonly property int fontSizeTitle: 13
    readonly property int fontSizeLarge: 14    // prominent lines inside popups
    readonly property int fontSizeXL: 28       // big readings in popup headers (battery %)
    readonly property int fontSizeDisplay: 48  // hero numbers (clock popup)
    readonly property int iconSize: 14
    readonly property int barIconSize: 16     // icons in the bar chips
    readonly property int barChipPadding: 8   // left/right padding inside a bar chip
    readonly property int barChipHeight: 32   // bar chips: the full bar height (the workspaces strip uses barItemHeight)

    // ---- Motion ---------------------------------------------------------------
    readonly property int durationFast: 140   // cross-fades
    readonly property int durationNormal: 160 // popups, OSD
    readonly property int durationSlow: 200   // layout changes (collapse/expand)
    readonly property real springStrength: 4  // SpringAnimation.spring for moving highlights
    readonly property real springDamping: 0.32

    // Same colour at another opacity, e.g. Theme.alpha(Theme.error, 0.18).
    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }
}
