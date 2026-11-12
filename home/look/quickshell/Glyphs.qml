// Glyphs.qml: icon paths (app glyphs + UI icons like `sun`) and the window-class map,
// shared by Workspaces.qml, WindowTitle.qml and GlowButton.qml.
pragma Singleton
import Quickshell

Singleton {
    // Stroked SVG paths in a 24x24 viewBox.
    readonly property var paths: ({
        globe: "M22 12A10 10 0 1 1 2 12A10 10 0 1 1 22 12Z M2 12H22 "
             + "M12 2A15.3 15.3 0 0 1 16 12A15.3 15.3 0 0 1 12 22A15.3 15.3 0 0 1 8 12A15.3 15.3 0 0 1 12 2Z",
        code: "M16 18L22 12L16 6 M8 6L2 12L8 18",
        chip: "M7 4H17A3 3 0 0 1 20 7V17A3 3 0 0 1 17 20H7A3 3 0 0 1 4 17V7A3 3 0 0 1 7 4Z M9 9H15V15H9Z "
            + "M9 1V4 M15 1V4 M9 20V23 M15 20V23 M20 9H23 M20 15H23 M1 9H4 M1 15H4",
        bell: "M6 8A6 6 0 0 1 18 8C18 15 21 17 21 17H3C3 17 6 15 6 8Z M10.3 21A1.94 1.94 0 0 0 13.7 21",
        leaf: "M11 20A7 7 0 0 1 9.8 6.1C15.5 5 17 4.48 19 2C20 4 21 6.18 21 10C21 15.5 16.22 20 11 20Z "
            + "M2 21C2 18 3.85 15.64 7.08 15C9.5 14.52 12 13 13 12",
        scales: "M16 16L19 8L22 16C21.13 16.65 20.08 17 19 17C17.92 17 16.87 16.65 16 16Z "
              + "M2 16L5 8L8 16C7.13 16.65 6.08 17 5 17C3.92 17 2.87 16.65 2 16Z "
              + "M7 21H17 M12 3V21 M3 7H5C7 7 10 6 12 5C14 6 17 7 19 7H21",
        bolt: "M13 2L3 14H12L11 22L21 10H12L13 2Z",
        bellOff: "M8.7 3A6 6 0 0 1 18 8A21.3 21.3 0 0 0 18.6 13 M17 17H3C3 17 6 15 6 8A4.67 4.67 0 0 1 6.3 6.3 "
               + "M10.3 21A1.94 1.94 0 0 0 13.7 21 M2 2L22 22",
        close: "M18 6L6 18 M6 6L18 18",
        // Six spokes from the centre, each with a small V near its tip.
        snowflake: "M12 12L12 2 M12 5.5L10.07 3.2 M12 5.5L13.93 3.2 M12 12L20.66 7 M17.63 8.75L18.66 5.93 "
                 + "M17.63 8.75L20.58 9.27 M12 12L20.66 17 M17.63 15.25L20.58 14.73 M17.63 15.25L18.66 18.07 "
                 + "M12 12L12 22 M12 18.5L13.93 20.8 M12 18.5L10.07 20.8 M12 12L3.34 17 M6.37 15.25L5.34 18.07 "
                 + "M6.37 15.25L3.42 14.73 M12 12L3.34 7 M6.37 8.75L3.42 9.27 M6.37 8.75L5.34 5.93",
        grid: "M3 3H10V10H3Z M14 3H21V10H14Z M14 14H21V21H14Z M3 14H10V21H3Z",
        wrench: "M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94"
              + "l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z",
        camera: "M14.5 4h-5L7 7H4a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V9a2 2 0 0 0-2-2h-3l-2.5-3z "
              + "M15 13a3 3 0 1 1-6 0a3 3 0 0 1 6 0z",
        // Corner brackets of a selection.
        region: "M3 7V5a2 2 0 0 1 2-2h2 M17 3h2a2 2 0 0 1 2 2v2 M21 17v2a2 2 0 0 1-2 2h-2 M7 21H5a2 2 0 0 1-2-2v-2",
        window: "M4 4h16a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2z M2 9h20 M6 6.5h.01 M9 6.5h.01",
        reboot: "M21 12A9 9 0 1 1 12 3C14.52 3 16.93 4 18.74 5.74L21 8 M21 3V8H16",
        power: "M12 2V12 M18.4 6.6A9 9 0 1 1 5.63 6.64",
        search: "M19 11A8 8 0 1 1 3 11A8 8 0 1 1 19 11Z M21 21L16.65 16.65",
        terminal: "M4 17L10 11L4 5 M12 19H20",
        music: "M9 18V5L21 3V16 M9 18A3 3 0 1 1 3 18A3 3 0 1 1 9 18Z M21 16A3 3 0 1 1 15 16A3 3 0 1 1 21 16Z",
        chevronLeft: "M15 18L9 12L15 6",
        chevronRight: "M9 18L15 12L9 6",
        sun: "M16 12A4 4 0 1 1 8 12A4 4 0 1 1 16 12Z M12 2V4 M12 20V22 M4.93 4.93L6.34 6.34 "
           + "M17.66 17.66L19.07 19.07 M2 12H4 M20 12H22 M6.34 17.66L4.93 19.07 M19.07 4.93L17.66 6.34",
        lock: "M7 11H17A2 2 0 0 1 19 13V19A2 2 0 0 1 17 21H7A2 2 0 0 1 5 19V13A2 2 0 0 1 7 11Z "
            + "M8 11V7A4 4 0 0 1 16 7V11",
        // Show / hide a password.
        eye: "M1 12S5 4 12 4S23 12 23 12S19 20 12 20S1 12 1 12Z M15 12A3 3 0 1 1 9 12A3 3 0 1 1 15 12Z",
        eyeOff: "M17.94 17.94A10.07 10.07 0 0 1 12 20C5 20 1 12 1 12A18.45 18.45 0 0 1 6.06 6.06 "
              + "M9.9 4.24A9.12 9.12 0 0 1 12 4C19 4 23 12 23 12A18.5 18.5 0 0 1 20.84 15.19 "
              + "M14.12 14.12A3 3 0 1 1 9.88 9.88 M1 1L23 23",
        // Two arrows chasing each other round a circle (Syncthing).
        sync: "M3 12a9 9 0 0 1 9-9a9.75 9.75 0 0 1 6.74 2.74L21 8 M21 3v5h-5 "
            + "M21 12a9 9 0 0 1-9 9a9.75 9.75 0 0 1-6.74-2.74L3 16 M8 16H3v5",
        folder: "M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4"
              + "a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z",
        share: "M21 5A3 3 0 1 1 15 5A3 3 0 1 1 21 5Z M9 12A3 3 0 1 1 3 12A3 3 0 1 1 9 12Z "
             + "M21 19A3 3 0 1 1 15 19A3 3 0 1 1 21 19Z M8.59 13.51L15.42 17.49 M15.41 6.51L8.59 10.49",
        clipboard: "M9 2H15A1 1 0 0 1 16 3V5A1 1 0 0 1 15 6H9A1 1 0 0 1 8 5V3A1 1 0 0 1 9 2Z "
                 + "M16 4H18A2 2 0 0 1 20 6V20A2 2 0 0 1 18 22H6A2 2 0 0 1 4 20V6A2 2 0 0 1 6 4H8",
        file: "M14 2H6A2 2 0 0 0 4 4V20A2 2 0 0 0 6 22H18A2 2 0 0 0 20 20V8Z M14 2V8H20",
        download: "M21 15V19A2 2 0 0 1 19 21H5A2 2 0 0 1 3 19V15 M7 10L12 15L17 10 M12 15V3",
        fingerprint: "M12 10a2 2 0 0 0-2 2c0 1.02-.1 2.51-.26 4 M14 13.12c0 2.38 0 6.38-1 8.88 "
                   + "M17.29 21.02c.12-.6.43-2.3.5-3.02 M2 12a10 10 0 0 1 18-6 M2 16h.01 M21.8 16c.2-2 .131-5.354 0-6 "
                   + "M5 19.5C5.5 18 6 15 6 12a6 6 0 0 1 .34-2 M8.65 22c.21-.66.45-1.32.57-2 M9 6.8a6 6 0 0 1 9 5.2v2",
        // A key (linux-passkey approvals).
        key: "M2.586 17.414A2 2 0 0 0 2 18.828V21a1 1 0 0 0 1 1h3a1 1 0 0 0 1-1v-1a1 1 0 0 1 1-1h1a1 1 0 0 0 1-1v-1a1 1 0 0 1 1-1h.172a2 2 0 0 0 1.414-.586l.814-.814a6.5 6.5 0 1 0-4-4Z "
           + "M16.5 7.5a.5.5 0 1 1-1 0a.5.5 0 1 1 1 0Z",
        check: "M20 6L9 17L4 12",
        pause: "M6 4H10V20H6Z M14 4H18V20H14Z",
        play: "M6 3L20 12L6 21Z",
        external: "M15 3H21V9 M10 14L21 3 M18 13V19A2 2 0 0 1 16 21H5A2 2 0 0 1 3 19V8A2 2 0 0 1 5 6H11"
    })

    // Glyph kind for a window class / app id, or "" if none is assigned.
    function kindFor(cls) {
        const c = (cls ?? "").toLowerCase();
        if (c === "google-chrome" || c.startsWith("google-chrome-")) return "globe";
        if (c === "code" || c === "code-url-handler") return "code";
        return "";
    }
}
