# Hyprland window manager, shared by every host: hy3 tiling, the Quickshell bar's launcher,
# tools and media keys, the drop-down terminal on ` and, on the MacBook (notch), fullscreen that
# keeps the black bar row; elsewhere real fullscreen. Monitors and host specifics: hosts/<name>/home.nix.
# Also the clutch HUD's layer rules and shortcuts.
{ pkgs, lib, config, clutch, ... }:
let
  # Fullscreen: on a notched panel (my.look.notchGap > 0) keep the bar row beside the notch;
  # elsewhere (the workstation: games, gamescope) real fullscreen.
  fullscreen =
    if config.my.look.notchGap > 0 then ''
      -- Fullscreen that keeps the top bar (it sits beside the MacBook notch): a window that
      -- goes fullscreen (mainMod + f, or the app itself, e.g. video) is laid out maximized,
      -- below the bar's reserved 32 px, while the app is still told it is fullscreen.
      -- (fullscreen_state: internal 1 = maximized, client 2 = fullscreen.)
      hl.on("window.fullscreen", function(w)
        if w and w.fullscreen == 2 then
          hl.dispatch(hl.dsp.window.fullscreen_state({ internal = 1, client = 2, action = "set", window = w }))
        end
      end)

      -- On a workspace with such a window (f[1]: a maximized window) there are no gaps and the
      -- window drops its border and rounding: it fills everything below the bar row, which
      -- turns black (see shell.qml) and keeps it clear of the notch.
      hl.workspace_rule({ workspace = "f[1]", gaps_out = 0 })
      hl.window_rule({
        name = "fullscreen-edges",
        match = { float = false, workspace = "f[1]" },
        border_size = 0,
        rounding = 0,
      })

      -- mainMod + f toggles it; a window in that state (internal 1) goes back to normal.
      hl.bind(key(mainMod, "f"), function()
        local w = hl.get_active_window()
        if not w then return end
        if w.fullscreen ~= 0 then
          hl.dispatch(hl.dsp.window.fullscreen_state({ internal = 0, client = 0, action = "set", window = w }))
        else
          hl.dispatch(hl.dsp.window.fullscreen_state({ internal = 1, client = 2, action = "set", window = w }))
        end
      end)
    '' else ''
      -- Make the current focus fullscreen with mainMod + f.
      hl.bind(key(mainMod, "f"), hl.dsp.window.fullscreen())
    '';
in
{
  wayland.windowManager.hyprland = {
    enable = true;
    # Lua config (hyprlang is deprecated). Home Manager generates ~/.config/hypr/hyprland.lua:
    # plugin loads first, then this extraConfig, then the systemd start/shutdown hooks.
    # API reference: ${pkgs.hyprland}/share/hypr/stubs/hl.meta.lua and https://wiki.hypr.land/Configuring/Start/
    configType = "lua";
    plugins = [
      # Proper i3-like tilling.
      pkgs.hyprlandPlugins.hy3
    ];
    extraConfig = ''
      local hy3 = hl.plugin.hy3 -- nil until the plugin is loaded (see keybindings).

      -------------------
      --- ENVIRONMENT ---
      -------------------

      hl.env("XCURSOR_THEME", "phinger-cursors-light")
      hl.env("XCURSOR_SIZE", "24")

      -----------------
      --- VARIABLES ---
      -----------------

      -- Keycodes (unviresal for all layouts)
      -- Note: they were obtained with *xmodmap*, you might add
      -- more if something is not listed here.
      local kc = {
        Escape = 9,
        ["1"] = 10, ["2"] = 11, ["3"] = 12, ["4"] = 13, ["5"] = 14,
        ["6"] = 15, ["7"] = 16, ["8"] = 17, ["9"] = 18, ["0"] = 19,
        minus = 20, plus = 21, BackSpace = 22,
        q = 24, w = 25, e = 26, r = 27, t = 28, y = 29, u = 30, i = 31, o = 32, p = 33,
        Return = 36, Control_L = 37,
        a = 38, s = 39, d = 40, f = 41, g = 42, h = 43, j = 44, k = 45, l = 46,
        grave = 49,
        z = 52, x = 53, c = 54, v = 55, b = 56, n = 57, m = 58,
        Space = 65, Print = 107,
        Home = 110, Up = 111, Prior = 112, Left = 113, Right = 114, End = 115, Down = 116, Next = 117,
      }

      -- Build a bind key string, e.g. key("ALT + SHIFT", "q") -> "ALT + SHIFT + code:24".
      local function key(mods, name)
        local code = "code:" .. kc[name]
        if mods == "" then
          return code
        end
        return mods .. " + " .. code
      end

      -------------------
      --- MY PROGRAMS ---
      -------------------

      -- Preferred terminal emulator (configured in home/look/terminal.nix).
      local terminal = "alacritty"

      -- Application launcher: the Quickshell bar's Launcher.qml.
      local launcher = "quickshell ipc -c bar call launcher toggle"

      -----------------
      --- AUTOSTART ---
      -----------------

      hl.on("hyprland.start", function()
        -- NOTE: the bar is Quickshell, started as a systemd user service (programs.quickshell), not here.
        -- Night light: hyprsunset (user service, home/look/quickshell.nix), scheduled by
        -- the bar's Glow (gamma-ramp night-light tools don't work on the Asahi display).
        -- Launch wallpaper.
        hl.exec_cmd("hyprpaper")
        -- Notifications: Quickshell is the daemon (NotificationService), not mako.
        -- Run XDG autostart entries.
        hl.exec_cmd("dex -a -e Hyprland")
      end)

      -- Monitors: per host (hosts/<name>/home.nix).

      ---------------------
      --- LOOK AND FEEL ---
      ---------------------

      hl.config({
        -- https://wiki.hyprland.org/Configuring/Variables/#general
        general = {
          -- Make window border bolder.
          border_size = 2,

          col = {
            -- Green-orange border for active window.
            active_border = { colors = { "rgba(33fe9cee)", "rgba(fe8d33ee)" }, angle = 45 },
          },

          -- Use hy3 plugin layout.
          layout = "hy3",
        },

        -- https://wiki.hyprland.org/Configuring/Variables/#misc
        misc = {
          -- Disable fucking anime mascot.
          force_default_wallpaper = 0,

          -- No weird slogans on desktop.
          disable_splash_rendering = true,

          -- A window opening behind a fullscreen one stays behind instead of taking focus and
          -- dropping the fullscreen (default 2). E.g. an agent in the drop-down terminal runs
          -- `code file`: VS Code opens on the drop-down's special workspace and used to knock
          -- the terminal out of fullscreen before evict_from_dropterm moved it away.
          on_focus_under_fullscreen = 0,
        },

        -- https://wiki.hyprland.org/Configuring/Variables/#decoration
        decoration = {
          -- Minor rounding around windows.
          rounding = 4,
          -- Light blur behind translucent surfaces (the clutch HUD card).
          blur = {
            size = 3,
          },

          -- Don't dim the screen behind a shown special workspace (the drop-down terminal).
          dim_special = 0,
        },

        -- https://wiki.hyprland.org/Configuring/Variables/#animations
        animations = {
          enabled = false, -- All animations are just an unnecessary slowdown.
        },

        cursor = {
          enable_hyprcursor = false,
          no_warps = true, -- Prevent jumping to the focused window e.g. floating terminal.
          no_hardware_cursors = true, -- Fixes locked/stuck cursor in CS2 and other XWayland games.
        },

        -------------
        --- INPUT ---
        -------------

        -- https://wiki.hyprland.org/Configuring/Variables/#input
        input = {
          -- Layout:
          -- - PL, Dvorak programmer (dvp)
          -- NOTE: For traditional PL qwerty, use 'legacy' variant.
          kb_layout = "pl",
          kb_variant = "dvp",
          kb_options = "caps:shiflock", -- I want CapsLock to affect numbers row.

          -- Cursor focus detatched from keyboard focus.
          follow_mouse = 2,

          -- Prevent automatic focus switch when hovering a window under the floating one.
          float_switch_override_focus = false,

          -- Windows behind a shown special workspace (the drop-down terminal) stay clickable.
          special_fallthrough = true,

          -- Touchpad (laptops; ignored without one):
          -- - no inverted scrolling
          -- - 1 finger is left, 2 fingers are right, 3 fingers are middle button
          -- - tap to click
          touchpad = {
            natural_scroll = false,
            tap_button_map = "lrm",
            tap_to_click = true,
            -- Physical click: 1 finger left, 2 right, 3 middle (libinput's Apple default;
            -- Hyprland otherwise forces bottom-corner button areas).
            clickfinger_behavior = true,
          },
        },

        -------------------------
        --- HYPRLAND SPECIFIC ---
        -------------------------
        ecosystem = {
          no_update_news = true, -- Prevent popup on Hyprland update.
          no_donation_nag = true, -- Prevent the twice-a-year donation popup.
        },
      })

      -- Disable all workspaces animations.
      hl.animation({ leaf = "workspaces", enabled = false })

      -------------------
      --- KEYBINDINGS ---
      -------------------

      local mainMod = "ALT" -- Sets "ALT" key as main modifier (on nixAir Cmd sends Alt: hid_apple swap_opt_cmd=1).
      local sup = "SUPER"

      -- https://wiki.hyprland.org/Configuring/Binds/

      -- Exit compositor on mainMod + SHIFT + e.
      hl.bind(key(mainMod .. " + SHIFT", "e"), hl.dsp.exit())

      -- Open launcher with mainMod + d.
      hl.bind(key(mainMod, "d"), hl.dsp.exec_cmd(launcher))

      -- Drop-down terminal on ` (backtick): Alacritty running tmux session "drop" (so it
      -- survives toggles), on the special workspace "dropterm". Started on first use; the
      -- window rule "dropterm" below puts it there and styles it.
      local function toggle_dropterm()
        for _, w in ipairs(hl.get_windows()) do
          if w.class == "dropterm" then
            hl.dispatch(hl.dsp.workspace.toggle_special("dropterm"))
            return
          end
        end
        -- Not running yet: start it (the rule puts it on the special workspace) and show
        -- that workspace, which a new window landing there doesn't do by itself.
        hl.exec_cmd("alacritty --class dropterm -o window.opacity=1.0 -e tmux new-session -A -s drop") -- opaque, unlike normal windows (0.96)
        hl.dispatch(hl.dsp.workspace.toggle_special("dropterm"))
      end
      hl.bind(key("", "grave"), toggle_dropterm)

      -- While the drop-down is shown its special workspace has focus, so anything started then
      -- (launcher, a link from the terminal, ...) would open there and hide/show with it. Move such
      -- windows to the monitor's regular workspace, focus them and hide the drop-down.
      -- Except pinentry (linux-passkey confirm for sudo, gpg signing): a short-lived dialog
      -- asked for from the terminal itself, so it stays on top of it.
      local function evict_from_dropterm(w)
        if not w or w.class == "dropterm" then return end
        if w.class and w.class:find("pinentry") then return end
        local ws = w.workspace
        if not (ws and ws.special and ws.name == "special:dropterm") then return end
        local regular = w.monitor and w.monitor.active_workspace or hl.get_active_workspace()
        if not regular then return end
        hl.dispatch(hl.dsp.window.move({ workspace = regular.id, follow = false, window = w }))
        hl.dispatch(hl.dsp.workspace.toggle_special("dropterm"))
        hl.dispatch(hl.dsp.focus({ window = w }))
      end
      hl.on("window.open", evict_from_dropterm)

      -- Lock screen on sup + l, by key name (the letter l on Dvorak), not keycode: code:46
      -- is QWERTY's L, which types n here. One instance only.
      hl.bind(sup .. " + l", hl.dsp.exec_cmd("pidof hyprlock || hyprlock"))

      -- Open file browser with mainMod + n.
      hl.bind(key(mainMod, "n"), hl.dsp.exec_cmd("alacritty -e nnn"))

      ${fullscreen}

      -- Toggle floating mode of focused window with mainMod + SHIFT + Space.
      hl.bind(key(mainMod .. " + SHIFT", "Space"), hl.dsp.window.float({ action = "toggle" }))

      -- Kill focused window with mainMod + SHIFT + q.
      hl.bind(key(mainMod .. " + SHIFT", "q"), hl.dsp.window.close())

      -- NOTE: plugins load after the first config pass, which then reloads; hy3 is nil until then.
      if hy3 then
        -- Move focus with mainMod + h/j/k/l, move window with mainMod + SHIFT + h/j/k/l.
        for name, dir in pairs({ h = "l", j = "d", k = "u", l = "r" }) do
          hl.bind(key(mainMod, name), hy3.move_focus(dir))
          hl.bind(key(mainMod .. " + SHIFT", name), hy3.move_window(dir))
        end

        -- Sway layout bindings, mapped onto hy3 groups.
        hl.bind(key(mainMod, "v"), hy3.make_group("h")) -- split horizontally
        hl.bind(key(mainMod, "b"), hy3.make_group("v")) -- split vertically
        hl.bind(key(mainMod, "w"), hy3.change_group("toggletab")) -- tabbed
        hl.bind(key(mainMod, "e"), hy3.change_group("opposite")) -- toggle split direction
        hl.bind(key(mainMod, "a"), hy3.change_focus("raise")) -- focus parent
        hl.bind(key(mainMod, "Space"), hy3.toggle_focus_layer()) -- tiling <-> floating focus
      end

      -- Switch workspaces with mainMod + [0-9].
      -- Move active window to a workspace (silently) with mainMod + SHIFT + [0-9].
      for i = 1, 10 do
        local digit = tostring(i % 10) -- 10 maps to key 0
        hl.bind(key(mainMod, digit), hl.dsp.focus({ workspace = i }))
        hl.bind(key(mainMod .. " + SHIFT", digit), hl.dsp.window.move({ workspace = i, follow = false }))
      end

      -- Start terminal with mainMod + Enter.
      hl.bind(key(mainMod, "Return"), hl.dsp.exec_cmd(terminal))


      -- Screenshots through the bar's Tools (home/look/quickshell/tools/screenshot.sh):
      -- Print = region (or click a window) -> clipboard, Shift + Print = active window -> /tmp.
      local tools = "quickshell ipc -c bar call tools "
      hl.bind(key("", "Print"), hl.dsp.exec_cmd(tools .. "screenshot region"))
      hl.bind(key("SHIFT", "Print"), hl.dsp.exec_cmd(tools .. "screenshot window"))

      -- Volume bindings, allowed to work when screen is locked.
      local volume = { locked = true, repeating = true }
      hl.bind(key("SHIFT", "Next"), hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), volume)
      hl.bind(key("SHIFT", "Prior"), hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), volume)
      hl.bind(key("SHIFT", "Home"), hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), volume)
      hl.bind(key("SHIFT", "End"), hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), volume)

      -- Media keys: on the MacBook always the J413 DSP speaker sink (never the raw speakers).
      -- wpctl only takes numeric ids, which change across restarts, so look it up by node name.
      -- Hosts without that sink (nixPC) use the default sink.
      local j413 = [[id=$(wpctl status -n | sed -n 's/^[^0-9]*\([0-9][0-9]*\)\. audio_effect\.j413-convolver .*/\1/p' | head -1); [ -n "$id" ] || id=@DEFAULT_AUDIO_SINK@; ]]
      local media = { locked = true, repeating = true }
      hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(j413 .. [[wpctl set-volume -l 1.0 "$id" 5%+]]), media)
      hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(j413 .. [[wpctl set-volume "$id" 5%-]]), media)
      hl.bind("XF86AudioMute", hl.dsp.exec_cmd(j413 .. [[wpctl set-mute "$id" toggle]]), { locked = true })

      -- Play/pause, next, previous: through the Quickshell bar (MediaService), so the keys
      -- drive the same player as the media widget (playerctl picks its own).
      local mpris = "quickshell ipc -c bar call media "
      hl.bind("XF86AudioPlay", hl.dsp.exec_cmd(mpris .. "playPause"), { locked = true })
      hl.bind("XF86AudioNext", hl.dsp.exec_cmd(mpris .. "next"), { locked = true })
      hl.bind("XF86AudioPrev", hl.dsp.exec_cmd(mpris .. "previous"), { locked = true })

      -- Screen brightness (laptops; no backlight device elsewhere, so a no-op).
      local brightness = { locked = true, repeating = true }
      hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -q set 10%+"), brightness)
      hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -q set 10%-"), brightness)

      -- Mouse bindings.
      -- Move window with mainMod + LBM.
      hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true }) -- NOTE: hy3 move_window is broken for floating windows.
      -- Resize window with mainMod + RBM.
      hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

      ------------------------------
      --- WINDOWS AND WORKSPACES ---
      ------------------------------

      -- Drop-down terminal (see toggle_dropterm): floating, 70 % × 35 % near the bottom (where the
      -- old drop-down sat), on its special workspace; 1 px border in the bar's lime (focused) / border grey, rounding 14,
      -- shadow (on by default), no blur (it is started fully opaque, see toggle_dropterm).
      hl.window_rule({
        name = "dropterm",
        match = { class = "dropterm" },
        workspace = "special:dropterm",
        float = true,
        size = "monitor_w*0.7 monitor_h*0.35",
        move = "monitor_w*0.15 monitor_h*0.6",
        rounding = 14,
        border_size = 1,
        border_color = "rgb(c5f36a) rgb(2a2f38)",
        no_blur = true,
      })

      -- Keep the demo HUD out of screen shares (needs the patched Hyprland,
      -- see hyprland-noscreenshare/; stock Hyprland draws a black box instead).
      hl.layer_rule({
        name = "noscreenshare-demo",
        match = { namespace = "^noscreenshare-demo$" },
        no_screen_share = true,
      })

      -- clutch HUD (run `clutch` from the launcher): hidden from screen shares and from its
      -- own captures (needs the patched Hyprland), blurred behind the card.
      hl.layer_rule({
        name = "clutch-hud",
        match = { namespace = "^clutch-hud$" },
        no_screen_share = true,
        blur = true,
        ignore_alpha = 0.3,
        no_anim = true,
      })

      -- clutch HUD shortcuts (Hyprland global shortcuts, appid "hud"). Bound by key name, not
      -- keycode, so they follow the Dvorak layout; the description's "hud:<action>" prefix
      -- is how the HUD finds them for its key hints.
      for _, b in ipairs({
        { "h", "capture", "Capture screen" },
        { "d", "ask", "Process screenshots" },
        { "g", "dismiss", "Reset HUD" },
        { "a", "toggle", "Show or hide HUD" },
        { "semicolon", "quit", "Quit HUD" },
        { "c", "copy", "Copy answer" },
        { "e", "scrollUp", "Scroll answer up" },
        { "u", "scrollDown", "Scroll answer down" },
        { "Left", "moveLeft", "Move HUD left" },
        { "Right", "moveRight", "Move HUD right" },
        { "Up", "moveUp", "Move HUD up" },
        { "Down", "moveDown", "Move HUD down" },
      }) do
        hl.bind("SUPER + " .. b[1], hl.dsp.global("hud:" .. b[2]), { description = "hud:" .. b[2] .. " " .. b[3] })
      end
    '';
    systemd = {
      enable = true;
    };
  };

  home.packages = [
    # clutch HUD: start it from the app launcher (`clutch`); it is not autostarted.
    clutch.packages.${pkgs.stdenv.hostPlatform.system}.clutch
    pkgs.nnn # mainMod + n
    pkgs.dex # XDG autostart
    pkgs.brightnessctl # brightness keys (+ Glow on laptops)
  ];

  # Polkit authentication agent (password dialog for polkit prompts, e.g. fprintd-enroll,
  # apps asking for admin rights). Without one, polkit actions that need auth just fail.
  services.hyprpolkitagent.enable = true;

  # clutch has no desktop entry of its own: add one, with its icon in the hicolor theme,
  # so the launcher (pinned in launcher.json) shows it with the icon.
  xdg.dataFile."icons/hicolor/scalable/apps/clutch.svg".source = ./clutch.svg;
  xdg.desktopEntries.clutch = {
    name = "Clutch";
    comment = "Overlay HUD";
    exec = "clutch";
    icon = "clutch";
    terminal = false;
    categories = [ "Utility" ];
  };
}
