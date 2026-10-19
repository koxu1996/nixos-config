#!/usr/bin/env python3
"""noscreenshare-demo: a HUD that is on screen but not in screen shares.

Opens a click-through HUD (layer-shell namespace "noscreenshare-demo", which
the Hyprland config marks no_screen_share) with a ticking clock on the focused
monitor. Share the screen (e.g. on webrtc-experiment.com) and compare: with the
patched Hyprland the HUD is on screen and absent from the share, which shows
the content behind it; stock Hyprland shows a black box instead.

Run it from a terminal. Keys there: arrows move the HUD, q or Ctrl+C quits.
"""

import os
import signal
import sys
import termios
import time
import tty

import cairo
import gi

gi.require_version("Gtk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import GLib, Gtk, GtkLayerShell  # noqa: E402

NAMESPACE = "noscreenshare-demo"
STEP = 40
margins = {"top": 120, "right": 120}

hud = Gtk.Window()
GtkLayerShell.init_for_window(hud)
GtkLayerShell.set_namespace(hud, NAMESPACE)
GtkLayerShell.set_layer(hud, GtkLayerShell.Layer.OVERLAY)
GtkLayerShell.set_exclusive_zone(hud, -1)
GtkLayerShell.set_anchor(hud, GtkLayerShell.Edge.TOP, True)
GtkLayerShell.set_anchor(hud, GtkLayerShell.Edge.RIGHT, True)


def place_hud():
    GtkLayerShell.set_margin(hud, GtkLayerShell.Edge.TOP, margins["top"])
    GtkLayerShell.set_margin(hud, GtkLayerShell.Edge.RIGHT, margins["right"])


place_hud()
visual = hud.get_screen().get_rgba_visual()
if visual:
    hud.set_visual(visual)
hud.set_app_paintable(True)


def draw_hud(widget, cr):
    alloc = widget.get_allocation()
    cr.set_operator(cairo.OPERATOR_CLEAR)
    cr.paint()
    cr.set_operator(cairo.OPERATOR_OVER)
    cr.set_source_rgba(0.05, 0.05, 0.08, 0.72)
    cr.rectangle(0, 0, alloc.width, alloc.height)
    cr.fill()
    cr.set_source_rgba(0.0, 1.0, 0.53, 1.0)
    cr.set_line_width(3)
    cr.rectangle(1.5, 1.5, alloc.width - 3, alloc.height - 3)
    cr.stroke()
    return False


label = Gtk.Label()
label.set_margin_start(24)
label.set_margin_end(24)
label.set_margin_top(14)
label.set_margin_bottom(14)


def tick():
    label.set_markup(
        '<span font="22" foreground="#00ff88" weight="bold">HIDDEN FROM SCREEN SHARE</span>\n'
        f'<span font="15" foreground="#e6e6e6">You see this. Your share does not.  {time.strftime("%H:%M:%S")}</span>'
    )
    return True


tick()
hud.add(label)
hud.connect("draw", draw_hud)
hud.show_all()
hud.input_shape_combine_region(cairo.Region())  # click-through
GLib.timeout_add(1000, tick)

# Arrow keys arrive as ESC [ A/B/C/D.
MOVES = {"A": ("top", -STEP), "B": ("top", STEP), "C": ("right", -STEP), "D": ("right", STEP)}
pending = ""


def on_stdin(_fd, _condition):
    global pending
    data = os.read(sys.stdin.fileno(), 64).decode(errors="ignore")
    if not data:
        Gtk.main_quit()
        return False
    pending += data
    while pending:
        if pending[0] == "q":
            Gtk.main_quit()
            return False
        if pending.startswith("\x1b["):
            if len(pending) < 3:
                break
            move = MOVES.get(pending[2])
            if move:
                edge, delta = move
                margins[edge] = max(0, margins[edge] + delta)
                place_hud()
            pending = pending[3:]
        elif pending[0] == "\x1b" and len(pending) < 2:
            break
        else:
            pending = pending[1:]
    return True


try:
    gi.require_version("GLibUnix", "2.0")
    from gi.repository import GLibUnix

    GLibUnix.signal_add(GLib.PRIORITY_DEFAULT, signal.SIGINT, Gtk.main_quit)
except (ImportError, ValueError):  # older GLib
    GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGINT, Gtk.main_quit)
GLib.io_add_watch(sys.stdin.fileno(), GLib.IOCondition.IN | GLib.IOCondition.HUP, on_stdin)
interactive = sys.stdin.isatty()
if interactive:
    saved = termios.tcgetattr(sys.stdin)
    tty.setcbreak(sys.stdin.fileno())
print("HUD shown. Arrows move it, q or Ctrl+C quits.")

try:
    Gtk.main()
finally:
    if interactive:
        termios.tcsetattr(sys.stdin, termios.TCSADRAIN, saved)
