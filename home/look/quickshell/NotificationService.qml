// NotificationService.qml: the session's notification daemon (org.freedesktop.Notifications)
// plus toast queue, history and Do Not Disturb. See quickshell/notifications/BRIEF.md.
//
// - Active = server.trackedNotifications (still open; actions/replies work).
// - Toasts = two ListModels (critical on the overlay layer, normal on the top layer),
//   at most `maxToasts` in total. A toast leaving the screen does not close its
//   notification: it stays under Active until dismissed.
// - History = snapshots taken inside `closed` (transient and superseded ones skipped),
//   newest first, capped, persisted with DND in Quickshell.statePath("notifications.json"):
//   read once at startup, written with a debounce.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Singleton {
    id: service

    readonly property int historyLimit: 200
    readonly property int defaultTimeout: 5000 // ms, for expireTimeout = -1
    readonly property int maxToasts: 4

    NotificationServer {
        id: server
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: false
        actionsSupported: true
        actionIconsSupported: false
        imageSupported: true
        inlineReplySupported: true
        persistenceSupported: true
        keepOnReload: true

        onNotification: n => service.receive(n)
    }

    // ---- Active --------------------------------------------------------------------
    readonly property var active: server.trackedNotifications.values
    readonly property var activeNewestFirst: active.slice().reverse()
    readonly property int count: active.length
    readonly property bool hasCritical: active.some(n => n.urgency === NotificationUrgency.Critical)

    property var arrivals: ({})   // notification id -> arrival time (ms)
    property var superseded: ({}) // ids replaced by a newer same-tag notification

    function arrivalOf(n) { return n ? (arrivals[n.id] ?? Date.now()) : Date.now(); }
    function isCritical(n) { return !!n && n.urgency === NotificationUrgency.Critical; }

    function tagOf(n) {
        const h = n?.hints ?? {};
        return String(h["x-canonical-private-synchronous"] ?? h["x-dunst-stack-tag"] ?? "");
    }

    // ms until the toast hides; 0 = never (expireTimeout 0, or Critical).
    function timeoutFor(n) {
        if (isCritical(n) || n.expireTimeout === 0) return 0;
        return n.expireTimeout > 0 ? n.expireTimeout : defaultTimeout;
    }

    // ---- Toasts --------------------------------------------------------------------
    ListModel { id: criticalModel }
    ListModel { id: normalModel }
    readonly property ListModel criticalToasts: criticalModel
    readonly property ListModel normalToasts: normalModel

    property var toastNotifications: ({}) // toast key -> notification
    // Toast key -> plain copy of a notification that closed while its toast was showing,
    // so the toast fades out with its content instead of going blank (the object is
    // destroyed right after `closed`). Dropped a second later.
    property var closingCopies: ({})
    property int nextKey: 1

    function notificationFor(key) { return toastNotifications[key] ?? closingCopies[key] ?? null; }

    function copyOf(n) {
        return {
            appName: n.appName, appIcon: n.appIcon, summary: n.summary, body: n.body,
            image: n.image, hints: Object.assign({}, n.hints ?? {}), urgency: n.urgency,
            desktopEntry: n.desktopEntry, actions: [], hasInlineReply: false,
            inlineReplyPlaceholder: "",
        };
    }

    Timer {
        id: dropCopies
        interval: 1000
        onTriggered: service.closingCopies = ({})
    }

    function findToast(predicate) {
        for (const model of [criticalModel, normalModel])
            for (let i = 0; i < model.count; i++)
                if (predicate(model.get(i))) return { model: model, index: i };
        return null;
    }

    function receive(n) {
        n.tracked = true;
        const a = Object.assign({}, arrivals);
        a[n.id] = Date.now();
        arrivals = a;

        const notification = n;
        n.closed.connect(reason => service.handleClosed(notification, reason));

        // Same stacking tag: the older notification is superseded (expired, kept out of
        // history) and its toast slot is reused.
        const tag = tagOf(n);
        let reuse = null;
        if (tag) {
            reuse = findToast(t => t.tag === tag);
            for (const old of active.slice()) {
                if (old !== n && tagOf(old) === tag) {
                    const s = Object.assign({}, superseded);
                    s[old.id] = true;
                    superseded = s;
                    old.expire();
                }
            }
        }

        const critical = isCritical(n);
        if (dnd && !critical) return; // recorded (it is tracked and goes to history on close)

        const key = nextKey++;
        const map = Object.assign({}, toastNotifications);
        map[key] = n;
        toastNotifications = map;

        const entry = { key: key, tag: tag, timeout: timeoutFor(n), critical: critical };
        const target = critical ? criticalModel : normalModel;
        if (reuse && reuse.model === target) {
            target.set(reuse.index, entry); // update in place
        } else {
            if (reuse) reuse.model.remove(reuse.index);
            target.insert(0, entry); // newest on top
        }
        trimToasts();
    }

    function trimToasts() {
        while (criticalModel.count + normalModel.count > maxToasts) {
            const model = normalModel.count > 0 ? normalModel : criticalModel;
            removeToastAt(model, model.count - 1); // oldest first, normal before critical
        }
    }

    function removeToastAt(model, index) {
        const key = model.get(index).key;
        model.remove(index);
        const map = Object.assign({}, toastNotifications);
        delete map[key];
        toastNotifications = map;
    }

    // Timer ran out: hide the toast, keep the notification tracked.
    function hideToast(key) {
        const found = findToast(t => t.key === key);
        if (found) removeToastAt(found.model, found.index);
    }

    function handleClosed(n, reason) {
        // Runs inside `closed`: the object is destroyed right after, so copy now.
        if (!n.transient && !superseded[n.id]) {
            // Keep an icon name or path (apps often send it as the image); image-provider
            // URLs die with the notification.
            const icon = [n.appIcon, n.image].find(i => i && !i.startsWith("image:")) ?? "";
            const entry = {
                key: `${Date.now()}-${n.id}`,
                appName: n.appName,
                appIcon: icon,
                summary: n.summary,
                body: n.body,
                desktopEntry: n.desktopEntry,
                critical: isCritical(n),
                time: arrivalOf(n),
                reason: reason,
            };
            history = [entry].concat(history).slice(0, historyLimit);
            changed();
        }
        for (const model of [criticalModel, normalModel])
            for (let i = model.count - 1; i >= 0; i--) {
                const key = model.get(i).key;
                if (toastNotifications[key] !== n) continue;
                closingCopies = Object.assign({}, closingCopies, { [key]: copyOf(n) });
                dropCopies.restart();
                removeToastAt(model, i);
            }
        const a = Object.assign({}, arrivals); delete a[n.id]; arrivals = a;
        const s = Object.assign({}, superseded); delete s[n.id]; superseded = s;
    }

    function dismiss(n) { if (n) n.dismiss(); }

    function clearAll() {
        for (const n of active.slice()) n.dismiss();
        history = [];
        changed();
    }

    function invokeDefault(n) {
        const action = (n?.actions ?? []).find(a => a.identifier === "default");
        if (action) action.invoke();
        return !!action;
    }

    // Open or focus the app behind a history entry.
    function openApp(entry) {
        if (DesktopEntries.applications.values.length === 0) return;
        const desktop = (entry.desktopEntry ? DesktopEntries.heuristicLookup(entry.desktopEntry) : null)
            ?? DesktopEntries.heuristicLookup(entry.appName);
        if (desktop) LauncherService.launchEntry(desktop); // own scope, survives bar restarts
    }

    // ---- History + DND state ----------------------------------------------------------
    property var history: []
    property bool dnd: false
    property bool stateRestored: false

    function setDnd(on) { dnd = on; changed(); }

    FileView {
        id: stateFile
        path: Quickshell.statePath("notifications.json")
        onLoaded: service.restoreState()
        onLoadFailed: error => service.restoreState()

        JsonAdapter {
            id: persisted
            property var history: []
            property bool dnd: false
        }
    }

    function restoreState() {
        if (stateRestored) return;
        stateRestored = true;
        // The adapter hands back a Qt list (Array.isArray is false): copy element-wise.
        const saved = persisted.history;
        const list = [];
        for (let i = 0; i < (saved?.length ?? 0) && list.length < historyLimit; i++)
            if (saved[i] && typeof saved[i] === "object") list.push(saved[i]);
        history = list;
        dnd = persisted.dnd;
    }

    Timer {
        id: saveDebounce
        interval: 400
        onTriggered: {
            persisted.history = service.history;
            persisted.dnd = service.dnd;
            stateFile.writeAdapter();
        }
    }

    function changed() { if (stateRestored) saveDebounce.restart(); }

    // ---- Helpers --------------------------------------------------------------------------
    // Icon URL for an app icon name / path, or "" (callers fall back to a glyph).
    function iconSource(name) {
        if (!name) return "";
        if (name.startsWith("/")) return "file://" + name;
        if (name.startsWith("file:") || name.startsWith("image:")) return name;
        return Quickshell.iconPath(name, true);
    }

    // "now", "4m", "2h", "3d", relative to ClockService.now (minute ticks).
    function relativeTime(ms) {
        const minutes = Math.floor((ClockService.now.getTime() - ms) / 60000);
        if (minutes < 1) return "now";
        if (minutes < 60) return `${minutes}m`;
        if (minutes < 1440) return `${Math.floor(minutes / 60)}h`;
        return `${Math.floor(minutes / 1440)}d`;
    }

    function clockTime(ms) {
        const d = new Date(ms);
        return `${ClockService.pad2(d.getHours())}:${ClockService.pad2(d.getMinutes())}`;
    }

    // "Today", "Yesterday" or "Mon 12 Oct" for a history entry's day.
    function dayLabel(ms) {
        const d = new Date(ms), now = ClockService.now;
        const days = Math.round((Date.UTC(now.getFullYear(), now.getMonth(), now.getDate())
                               - Date.UTC(d.getFullYear(), d.getMonth(), d.getDate())) / 86400000);
        if (days === 0) return "Today";
        if (days === 1) return "Yesterday";
        return `${ClockService.dayShort[ClockService.weekdayIndex(d)]} ${d.getDate()} ${ClockService.monthShort[d.getMonth()]}`;
    }
}
