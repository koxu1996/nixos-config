# Hyprland window manager — split out of home.nix.
{ pkgs, lib, config, clutch, ... }:
let
  # Pick a command with fzf and start it detached from the (closing) launcher terminal.
  # NOTE: needs bashInteractive; writeShellScript's bash lacks the compgen builtin.
  appLauncher = pkgs.writeScript "app-launcher" ''
    #!${pkgs.bashInteractive}/bin/bash
    cmd=$(compgen -c | sort -u | ${pkgs.fzf}/bin/fzf) || exit 0
    setsid -f "$cmd" >/dev/null 2>&1 </dev/null
  '';
in
{
  # clutch HUD: start it from the app launcher (`clutch`); it is not autostarted.
  home.packages = [ clutch.packages.${pkgs.stdenv.hostPlatform.system}.clutch ];

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

      -- Trying to fix broken screen sharing...
      -- See https://wiki.hyprland.org/Configuring/Environment-variables/#xdg-specifications.
      -- hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
      -- hl.env("XDG_SESSION_TYPE", "wayland")
      -- hl.env("XDG_SESSION_DESKTOP", "Hyprland")

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

      -- Preferred terminal emulator
      local terminal = "${pkgs.alacritty}/bin/alacritty"

      -- Application launcher
      local launcher = [[alacritty --title="Application launcher - System" -e ${appLauncher}]]

      -----------------
      --- AUTOSTART ---
      -----------------

      hl.on("hyprland.start", function()
        -- NOTE: waybar is started as a systemd user service (programs.waybar.systemd.enable), not here.
        -- Launch night-light filter.
        hl.exec_cmd("wlsunset -l 55.7:12.6 -t 5600:3600 -g 0.8")
        -- Launch wallpaper.
        hl.exec_cmd("hyprpaper")
      end)

      ---------------------
      --- LOOK AND FEEL ---
      ---------------------

      hl.config({
        -- https://wiki.hyprland.org/Configuring/Variables/#general
        general = {
          -- gaps_in = 5,
          -- gaps_out = 20,

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
        },

        -- https://wiki.hyprland.org/Configuring/Variables/#decoration
        decoration = {
          -- Minor rounding around windows.
          rounding = 4,
          -- Light blur behind translucent surfaces (the clutch HUD card).
          blur = {
            size = 3,
          },
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

      local mainMod = "ALT" -- Sets "ALT" key as main modifier
      local sup = "SUPER"

      -- https://wiki.hyprland.org/Configuring/Binds/

      -- Exit compositor on mainMod + SHIFT + e.
      hl.bind(key(mainMod .. " + SHIFT", "e"), hl.dsp.exit())

      -- Open launcher with mainMod + d.
      hl.bind(key(mainMod, "d"), hl.dsp.exec_cmd(launcher))

      -- Toggle floating terminal with $ (guake/tilde like; replaces hdrop, which still uses
      -- the legacy `hyprctl dispatch` syntax that Lua mode rejects).
      local function toggle_floating_terminal()
        local class = "floating_terminal_1"
        local current = hl.get_active_workspace()
        for _, w in ipairs(hl.get_windows()) do
          if w.class == class then
            if w.workspace and current and w.workspace.id == current.id then
              -- Visible here: hide it.
              hl.dispatch(hl.dsp.window.move({ workspace = "special:floating_terminal", follow = false, window = w }))
            elseif current then
              -- Hidden or on another workspace: bring it here and focus it.
              hl.dispatch(hl.dsp.window.move({ workspace = current.id, follow = false, window = w }))
              hl.dispatch(hl.dsp.focus({ window = w }))
            end
            return
          end
        end
        -- Not running yet.
        hl.exec_cmd("alacritty --class " .. class)
      end
      hl.bind(key("", "grave"), toggle_floating_terminal)

      -- Launch lockscreen with sup + L.
      hl.bind(key(sup, "l"), hl.dsp.exec_cmd("hyprlock"))

      -- Make the current focus fullscreen with mainMod + f.
      hl.bind(key(mainMod, "f"), hl.dsp.window.fullscreen())

      -- Toggle floating mode of focused window with mainMod + SHIFT + Space.
      hl.bind(key(mainMod .. " + SHIFT", "Space"), hl.dsp.window.float({ action = "toggle" }))

      -- Kill focused window with mainMod + SHIFT + q.
      hl.bind(key(mainMod .. " + SHIFT", "q"), hl.dsp.window.close())

      -- Move focus with mainMod + h/j/k/l, move window with mainMod + SHIFT + h/j/k/l.
      -- NOTE: plugins load after the first config pass, which then reloads; hy3 is nil until then.
      if hy3 then
        for name, dir in pairs({ h = "l", j = "d", k = "u", l = "r" }) do
          hl.bind(key(mainMod, name), hy3.move_focus(dir))
          hl.bind(key(mainMod .. " + SHIFT", name), hy3.move_window(dir))
        end
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

      -- Partial screenshot to clipboard with Alt + Print Screen.
      hl.bind(key("ALT", "Print"), hl.dsp.exec_cmd([[grim -g "$(slurp)" - | wl-copy]]))

      -- Full screenshot to files with Print Screen.
      hl.bind(key("", "Print"), hl.dsp.exec_cmd([[grim -c ~/screenshot_$(date +'%Y-%m-%d_%H-%M-%S').png]]))

      -- Volume bindings, allowed to work when screen is locked.
      local volume = { locked = true, repeating = true }
      hl.bind(key("SHIFT", "Next"), hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), volume)
      hl.bind(key("SHIFT", "Prior"), hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), volume)
      hl.bind(key("SHIFT", "Home"), hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), volume)
      hl.bind(key("SHIFT", "End"), hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), volume)

      -- Mouse bindings.
      -- Move window with mainMod + LBM.
      hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true }) -- NOTE: hy3 move_window is broken for floating windows.
      -- Resize window with mainMod + RBM.
      hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

      ------------------------------
      --- WINDOWS AND WORKSPACES ---
      ------------------------------

      -- See https://wiki.hyprland.org/Configuring/Window-Rules/ for more
      -- See https://wiki.hyprland.org/Configuring/Workspace-Rules/ for workspace rules

      -- Floating launcher.
      hl.window_rule({
        name = "floating-launcher",
        match = { title = "(Application launcher - System)" },
        float = true,
      })

      -- Floating terminal.
      hl.window_rule({
        name = "floating-terminal",
        match = { class = "floating_terminal_1" },
        float = true,
        size = "monitor_w*0.7 monitor_h*0.35",
        move = "monitor_w*0.15 monitor_h*0.6",
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
}
