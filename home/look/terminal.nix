# Terminal setup in the bar's palette (palette.nix): Alacritty, tmux and the zsh prompt.
# The drop-down terminal (class "dropterm") is in home/hyprland.nix.
{ pkgs, ... }:
let
  p = import ./palette.nix;
in
{
  # ---- Alacritty (0.17) -------------------------------------------------------------------
  programs.alacritty = {
    enable = true;
    settings = {
      env.TERM = "alacritty";

      window = {
        padding = { x = 14; y = 12; };
        dynamic_padding = true;
        decorations = "None";
        opacity = 0.96;
      };

      font = {
        size = 12.0;
        normal = { family = "JetBrains Mono"; style = "Regular"; };
        bold = { family = "JetBrains Mono"; style = "Bold"; };
        italic = { family = "JetBrains Mono"; style = "Italic"; };
        bold_italic = { family = "JetBrains Mono"; style = "Bold Italic"; };
      };

      cursor.style = { shape = "Block"; blinking = "On"; };

      scrolling.history = 10000; # as before

      colors = {
        primary = { background = p.base; foreground = p.textPrimary; };
        cursor = { cursor = p.accent; text = p.base; };
        selection = { background = p.accentBg; text = p.accent; };
        search = {
          matches = { background = p.accentBg; foreground = p.accent; };
          focused_match = { background = p.accent; foreground = p.base; };
        };
        hints = {
          start = { background = p.raisedHigh; foreground = p.textSecondary; };
          end = { background = p.raisedHigh; foreground = p.textSecondary; };
        };
        footer_bar = { background = p.raisedHigh; foreground = p.textSecondary; };

        normal = {
          black = "#1b2028"; red = "#f2706a"; green = "#c5f36a"; yellow = "#f5a524";
          blue = "#82aaff"; magenta = "#c4a7ff"; cyan = "#7dd3c8"; white = "#8a919b";
        };
        bright = {
          black = "#5f6670"; red = "#ff8f8a"; green = "#d8fa94"; yellow = "#ffc15c";
          blue = "#a5c2ff"; magenta = "#d9c6ff"; cyan = "#a3e6dd"; white = "#eef0f3";
        };
      };
    };
  };

  # ---- tmux ---------------------------------------------------------------------------------
  # Personal binds carried over from the old ~/.tmux.conf; pane traversal is h/t/n/s
  # (Programmer Dvorak's right-hand home row).
  programs.tmux = {
    enable = true;
    terminal = "tmux-256color";
    escapeTime = 0;
    baseIndex = 1;
    mouse = true;
    focusEvents = true;
    prefix = "C-a";
    aggressiveResize = true;
    shell = "${pkgs.zsh}/bin/zsh";

    extraConfig = ''
      # ---- True colour from Alacritty ----
      set -as terminal-features ",alacritty*:RGB"
      set -as terminal-overrides ",alacritty*:Tc"
      set -g renumber-windows on

      # ---- Status line ----
      set -g status on
      set -g status-position bottom
      set -g status-style "bg=${p.base},fg=${p.textSecondary}"
      set -g status-left ""
      set -g status-right ""
      setw -g window-status-format " #I #W "
      setw -g window-status-style "fg=${p.textSecondary},bg=${p.base}"
      setw -g window-status-current-format " #I #W "
      setw -g window-status-current-style "fg=${p.accent},bg=${p.accentBg}"
      setw -g window-status-separator ""
      setw -g window-status-activity-style "fg=${p.warning},bg=default"
      setw -g window-status-bell-style "fg=${p.warning},bg=default"

      # ---- Panes ----
      set -g pane-border-style "fg=${p.borderSubtle}"
      set -g pane-active-border-style "fg=${p.accent}"
      set -g pane-border-lines single
      set -g pane-border-status off

      # ---- Messages, modes, copy-mode search (as Alacritty's search) ----
      set -g message-style "bg=${p.accentBg},fg=${p.accent}"
      set -g message-command-style "bg=${p.accentBg},fg=${p.accent}"
      setw -g mode-style "bg=${p.accentBg},fg=${p.accent}"
      setw -g copy-mode-match-style "bg=${p.accentBg},fg=${p.accent}"
      setw -g copy-mode-current-match-style "bg=${p.accent},fg=${p.base}"
      setw -g clock-mode-colour "${p.accent}"
      set -g display-panes-colour "${p.textDisabled}"
      set -g display-panes-active-colour "${p.accent}"
      set -g popup-style "bg=${p.raised}"
      set -g popup-border-style "fg=${p.border}"
      set -g popup-border-lines rounded

      # ---- Personal binds (from the old ~/.tmux.conf) ----
      # C-a prefix (above); C-s / a send the prefix to a nested session.
      bind-key C-s send-prefix
      bind-key a send-prefix

      # Splits and windows open in the current pane's directory.
      bind v split-window -h -c "#{pane_current_path}"
      bind b split-window -v -c "#{pane_current_path}"
      bind 1 split-window -h -c "#{pane_current_path}"
      bind _ split-window -v -c "#{pane_current_path}"
      bind '"' split-window -v -c "#{pane_current_path}"
      bind % split-window -h -c "#{pane_current_path}"
      bind c new-window -c "#{pane_current_path}"
      bind j new-window
      bind-key J command-prompt -p "Name of new window: " "new-window -n '%%'"

      # Pane traversal (h/t/n/s) and a 60 % main-horizontal layout.
      bind h select-pane -L
      bind t select-pane -D
      bind n select-pane -U
      bind s select-pane -R
      bind m set-window-option main-pane-height 60\; select-layout main-horizontal

      # Vi copy mode (only copy mode: the command prompt keeps emacs keys, as before):
      # v starts a selection, y copies it.
      setw -g mode-keys vi
      bind-key -T copy-mode-vi v send -X begin-selection
      bind-key -T copy-mode-vi y send -X copy-selection-and-cancel

      # Quiet activity / bells, automatic window names, shorter repeat.
      set -g visual-activity off
      set -g visual-bell off
      set -g visual-silence off
      setw -g monitor-activity off
      set -g bell-action none
      setw -g automatic-rename on
      set -g repeat-time 250

      bind r source-file ~/.config/tmux/tmux.conf \; display-message "Config reloaded..."
    '';
  };

  # ---- zsh prompt -------------------------------------------------------------------------
  # Sourced after oh-my-zsh (which provides git_prompt_info and git_prompt_ahead and enables
  # prompt_subst; its own theme is off). One line: dir · branch · markers · ❯.
  xdg.configFile."zsh/prompt.zsh".text = ''
    # Generated by Home Manager (terminal.nix) from theme/palette.nix.
    ZSH_THEME_GIT_PROMPT_PREFIX=" %F{${p.magenta}}"
    ZSH_THEME_GIT_PROMPT_SUFFIX="%f"
    ZSH_THEME_GIT_PROMPT_DIRTY="%F{${p.warning}}*"
    ZSH_THEME_GIT_PROMPT_CLEAN=""
    ZSH_THEME_GIT_PROMPT_AHEAD="%F{${p.warning}}↑%f"
    PROMPT='%F{${p.blue}}%~%f$(git_prompt_info)$(git_prompt_ahead) %(?.%F{${p.accent}}.%F{${p.error}})❯%f '
    RPROMPT=""
  '';

  programs.zsh.oh-my-zsh.theme = "";
  programs.zsh.initContent = ''
    source ''${XDG_CONFIG_HOME:-$HOME/.config}/zsh/prompt.zsh
  '';
}
