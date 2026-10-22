pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "Plural.js" as Plural

// LOCAL REPLACEMENT (not an upstream copy): English-only stand-in for
// Omarchy's I18n singleton. Same API the vendored QML calls —
// t(key, fallback), tn(key, count, fallback), formatNumber(value, decimals),
// formatLocale, plus the language/strings/rightToLeft properties KeyboardPanel,
// Util and the agents panel read — backed only by the English shell.json
// catalog. No language file, no locale registry, no Translations.
// Use as I18n.t("common.search").arg(...), and
// I18n.tn(key, count).arg(I18n.formatNumber(count)) for {one, other} entries.
QtObject {
  id: root

  readonly property string omarchyPath: Quickshell.env("OMARCHY_PATH")

  readonly property string language: "en"
  readonly property string formatLocale: "en-US"
  readonly property string decimal: "."
  readonly property string zeroDigit: "0"
  readonly property bool rightToLeft: false

  // Rebuilt when the watched catalog changes, so listeners of stringsChanged
  // (the agents panel's held hero phrase) still re-render.
  readonly property var strings: parseCatalog(catalogFile.text())

  function t(key, fallback) {
    var value = root.strings[key]
    if (value && typeof value === "object") value = value.other
    if (typeof value === "string" && value.length > 0) return value
    return fallback !== undefined ? fallback : key
  }

  // {one, other} plural entries, picked by English rules.
  function tn(key, count, fallback) {
    var value = Plural.pick(root.strings[key], "en", count)
    if (typeof value === "string" && value.length > 0) return value
    return fallback !== undefined ? fallback : key
  }

  // A number in en-US form. Pass decimals to round; without them the value
  // keeps the decimals it has (13.14 stays "13.14", 1234 becomes "1,234").
  function formatNumber(value, decimals) {
    var number = Number(value)
    if (!isFinite(number)) return String(value)
    var places = decimals !== undefined ? decimals : (String(number).split(".")[1] || "").length
    return number.toLocaleString(Qt.locale("en_US"), "f", places)
  }

  function parseCatalog(raw) {
    try {
      var parsed = JSON.parse(raw || "{}")
      return (parsed && typeof parsed === "object" && !Array.isArray(parsed)) ? parsed : ({})
    } catch (e) {
      return ({})
    }
  }

  // Read synchronously so the first binding to call t() gets the string
  // rather than the raw key.
  property FileView catalogFile: FileView {
    path: root.omarchyPath + "/default/i18n/en/shell.json"
    watchChanges: true
    printErrors: false
    blockLoading: true
    onFileChanged: reload()
  }
}
