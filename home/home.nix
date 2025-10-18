{ config, lib, pkgs, ... }:

let
  # Define necessary executables for keybindings
  terminal = "kitty"; # Now relies on PATH
  # UPDATED: Launch nnn inside kitty
  fileManager = "kitty -e nnn"; 
  menu = "wofi --show drun"; # Now relies on PATH

  # Define the Vulkan ICD paths (assuming Intel/AMD Mesa drivers)
  mesaIcdJson = "${pkgs.mesa}/share/vulkan/icd.d/intel_icd.x86_64.json:${pkgs.mesa}/share/vulkan/icd.d/amd_icd.x86_64.json";

  # --- 1. Consolidated Script for core services (Waybar, Applets, Portals, and Hyprpaper) ---
  hyprlandCoreServices = pkgs.writeShellScriptBin "hyprland-core-services" ''
    #!/usr/bin/env bash
    
    # Environment setup
    dbus-update-activation-environment --systemd --all
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
    
    # Start XDG Portals (rely on PATH)
    killall -e xdg-desktop-portal-hyprland
    killall -e xdg-desktop-portal-gtk
    killall -e xdg-desktop-portal-wlr
    killall xdg-desktop-portal
    sleep 0.5
    xdg-desktop-portal &
    xdg-desktop-portal-hyprland &
    xdg-desktop-portal-gtk & # CRUCIAL for Lutris setup wizards
    
    # Start agents and applets (rely on PATH)
    lxqt-policykit-agent &
    nm-applet --indicator &
    blueman-applet & 
    
    # Start Waybar (Runs after portals) (rely on PATH)
    waybar &

    # --- HYPRPAPER GUARANTEED FIX (Robust Wait/Retry) ---
    # 1. Launch the hyprpaper daemon first.
    hyprpaper &
    
    # 2. Wait for the daemon to start by pinging it with a small, synchronous loop.
    MAX_TRIES=10 # Max 10 attempts (5 seconds total)
    TRIES=0
    
    echo "Waiting for hyprpaper socket..."

    # Use a dummy hyprctl command (preload "") to check if the socket is alive. Discard errors.
    while ! hyprctl hyprpaper preload "" 2>/dev/null; do
        if [ $TRIES -ge $MAX_TRIES ]; then
            echo "Hyprpaper daemon failed to connect after $MAX_TRIES attempts. Skipping wallpaper set." >&2
            # Use notify-send as a fallback if things go wrong
            notify-send "Hyprpaper Error" "Could not connect to wallpaper service at startup."
            break
        fi
        sleep 0.5
        TRIES=$((TRIES + 1))
    done

    # 3. If the daemon is running (TRIES < MAX_TRIES), set the wallpaper.
    if [ $TRIES -lt $MAX_TRIES ]; then
        echo "Hyprpaper socket connected. Setting initial wallpaper."
        # Do NOT background this. Let it run synchronously.
        ${randomWallpaperLoader}/bin/random-wallpaper-loader
    fi
  '';

  # --- Script to select and apply a random wallpaper (using coreutils for shuf) (rely on PATH) ---
  randomWallpaperLoader = pkgs.writeShellScriptBin "random-wallpaper-loader" ''
    #!/usr/bin/env bash
    WALLPAPER_DIR="/home/antis/wallpapers"
    
    # Use standard commands from PATH
    RANDOM_FILE=$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" \) | shuf -n 1)

    if [ -n "$RANDOM_FILE" ]; then
        # This part ensures the wallpaper is preloaded and set via hyprctl
        hyprctl hyprpaper preload "$RANDOM_FILE"
        hyprctl hyprpaper wallpaper ",$RANDOM_FILE"
        echo "Set wallpaper to: $RANDOM_FILE"
    else
        echo "Error: Wallpaper directory $WALLPAPER_DIR is empty or contains no valid images." >&2
    fi
  '';
  
  # --- Archive Extraction Script (Updated to use kitty + nnn) ---
  extractGameArchive = pkgs.writeShellScriptBin "extract-game-archive" ''
    #!/usr/bin/env bash
    
    ARCHIVE_DIR="$HOME/Downloads" # Default search directory
    
    # Use fzf to select the archive file (.rar, .zip, .7z)
    ARCHIVE_FILE=$(find "$ARCHIVE_DIR" -type f \( -iname "*.rar" -o -iname "*.zip" -o -iname "*.7z" \) | fzf --prompt="Select Archive to Extract: " --height 40% --border)

    if [ -n "$ARCHIVE_FILE" ]; then
        ARCHIVE_PATH=$(dirname "$ARCHIVE_FILE")
        FILENAME=$(basename "$ARCHIVE_FILE")
        FOLDER_NAME=$(echo "$FILENAME" | gawk 'match($0, /^(.*)\.((rar|zip|7z|tar|gz|bz2))(\.part[0-9]+)?$/, a) { print a[1] }')
        
        if [ -z "$FOLDER_NAME" ]; then
          FOLDER_NAME="extracted_$(date +%Y%m%d%H%M%S)"
        fi

        EXTRACT_DIR="$ARCHIVE_PATH/$FOLDER_NAME"
        
        mkdir -p "$EXTRACT_DIR"
        
        notify-send "Extraction Started" "Extracting $FILENAME to $FOLDER_NAME. Please wait..."
        
        # Use 7z from PATH
        if 7z x "$ARCHIVE_FILE" -o"$EXTRACT_DIR"; then
          notify-send "Extraction Complete" "Extracted $FILENAME to $FOLDER_NAME. Opening file manager."
          # Open extracted directory in the new CLI file manager (nnn) inside kitty
          kitty -e nnn "$EXTRACT_DIR" &
        else
          notify-send "Extraction Failed" "7z encountered an error extracting $FILENAME."
        fi
    else
        notify-send "Extraction Cancelled" "No archive selected."
    fi
  '';
  
  # --- MPV Media Selector Script (NEW FIX) ---
  mediaSelector = pkgs.writeShellScriptBin "mpv-media-selector" ''
    #!/usr/bin/env bash
    
    MEDIA_DIR="$HOME/Videos" # Start searching in the Videos folder
    
    # Use fzf to select the media file (searching common video/audio extensions)
    # The command runs inside kitty to keep the environment consistent
    MEDIA_FILE=$(kitty -e find "$MEDIA_DIR" -type f \( -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.webm" -o -iname "*.avi" -o -iname "*.mp3" -o -iname "*.flac" \) | fzf --prompt="Select Media File to Play (in $MEDIA_DIR): " --height 40% --border)

    if [ -n "$MEDIA_FILE" ]; then
        # Play selected file using mpv
        mpv "$MEDIA_FILE" &
    else
        notify-send "MPV Cancelled" "No media file selected."
    fi
  '';
  
  # --- Glamorous Pomodoro Timer Script (REMAINS) ---
  pomodoroTimer = pkgs.writeShellScriptBin "pomodoro-timer" ''
    #!/usr/bin/env bash

    STATUS_FILE="/tmp/pomodoro_status"
    WORK_MINUTES=25
    BREAK_MINUTES=5

    # Function to send a notification
    send_notification() {
        TITLE=$1
        MESSAGE=$2
        # Use libnotify (via notify-send)
        notify-send -a "Pomodoro" -t 5000 -i appointment "$TITLE" "$MESSAGE"
    }

    if [ -f "$STATUS_FILE" ]; then
        # If running, notify the status (glamorous error handling!)
        STATUS=$(cat "$STATUS_FILE")
        if [ "$STATUS" == "work" ]; then
          send_notification "Pomodoro Status" "Work session is active! Stay focused for 25 minutes."
        else
          send_notification "Pomodoro Status" "Break session is active! Relax for 5 minutes."
        fi
        exit 0
    fi

    # Start Pomodoro cycle in the background
    (
        # WORK SESSION
        echo "work" > "$STATUS_FILE"
        send_notification "🍅 Pomodoro Started" "Focus for the next $WORK_MINUTES minutes."
        sleep $((WORK_MINUTES * 60))
        
        # BREAK SESSION
        echo "break" > "$STATUS_FILE"
        send_notification "☕ Break Time!" "Take a $BREAK_MINUTES minute break. You earned it!"
        sleep $((BREAK_MINUTES * 60))

        # CYCLE END
        send_notification "✅ Pomodoro Cycle Complete" "Time to start a new work session!"
        rm -f "$STATUS_FILE"
    ) &
  '';

in
{
  # --- User and State Configuration ---
  home.username = "antis";
  home.homeDirectory = "/home/antis";
  home.stateVersion = "25.05";
  programs.home-manager.enable = true;
  # The conflicting home.shell line was previously removed from this file.

  # --- Environment Variables ---
  home.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    GDK_BACKEND = "wayland,x11";
    
    # Gaming Environment Variables for Wayland/Proton stability
    WINE_FULLSCREEN_FSR = "1"; # Enables FSR for Wine/Proton games
    DXVK_ASYNC = "1";          # Often provides smoother frame pacing
    MESA_LOADER_DRIVER_OVERRIDE = "zink"; # Optional: forces use of Zink/Vulkan if needed
    WINE_ALLOW_RUNASROOT = "1"; 
    
    # --- CRITICAL VULKAN FIX FOR LUTRIS GUI LAUNCHES ---
    LD_LIBRARY_PATH = "${pkgs.vulkan-loader}/lib:$LD_LIBRARY_PATH";
    VK_ICD_FILENAMES = mesaIcdJson;
    # ---------------------------------------------------
  };

  # --- Package Installation (mpv added) ---
  home.packages = with pkgs; [
    kitty zsh neovim vscodium git brave
    steam lutris gamemode wineWowPackages.staging winetricks 
    grim slurp wl-clipboard brightnessctl playerctl wireplumber
    xdg-desktop-portal-hyprland xdg-desktop-portal-gtk 
    lxqt.lxqt-policykit networkmanagerapplet
    findutils coreutils fzf lutris gawk blueman 
    
    # Media Player Added
    mpv
    
    # CLI File Manager
    nnn
    
    nerd-fonts.fira-code nerd-fonts.fira-mono nerd-fonts.hack
    nerd-fonts.iosevka-term nerd-fonts.iosevka nerd-fonts.jetbrains-mono
    # Archive Support
    p7zip unrar zip unzip libnotify 
    # Messaging Client
    goofcord 
    # Using protonplus 
    protonplus 
    gearlever
    appimage-run
    # FIX for PollyMC/AppImage: provide helper scripts for extraction
        
    # --- CRITICAL FIX FOR RPG MAKER MZ (Rendering dependencies kept) ---
    pkgsi686Linux.gdk-pixbuf # Corrected package name
    pkgsi686Linux.gtk3 
    # -----------------------------------------------------------------
    
    # --- Dependencies for the vulkan fix ---
    vulkan-loader
    vulkan-tools
    mesa
  ];

  # --- Services and Programs (unchanged) ---
  services.mako.enable = true;
  services.cliphist.enable = true;
  programs.zsh.enable = true; # Zsh configuration is still active here
  programs.starship.enable = true;
  programs.waybar.enable = true;
  programs.wofi.enable = true;

  # --- GTK Theme Configuration (unchanged) ---
  gtk = {
    enable = true;
    theme = {
      name = "Catppuccin-Mocha-Mauve-Compact";
      package = pkgs.catppuccin-gtk.override {
        accents = [ "mauve" ];
        size = "compact";
        tweaks = [ "rimless" "black" ];
        variant = "mocha";
      };
    };
  };

  # --- XDG Config Files (unchanged) ---
  xdg.configFile = {
    "mako/config".source = ./mako/config; # Mako config file
    "gtk-4.0/assets".source = "${config.gtk.theme.package}/share/themes/${config.gtk.theme.name}/gtk-4.0/assets";
    "gtk-4.0/gtk.css".source = "${config.gtk.theme.package}/share/themes/${config.gtk.theme.name}/gtk-4.0/gtk.css";
    "gtk-4.0/gtk-dark.css".source = ./gtk-4.0/gtk-dark.css;
    "waybar/config.jsonc".source = ./waybar/config.jsonc;
    "waybar/style.css".source = ./waybar/style.css;
    "wofi/config".source = ./wofi/config;
    "wofi/style.css".source = ./wofi/style.css;
    "hypr/hyprpaper.conf".source = ./hypr/hyprpaper.conf;
  };

  # --- Hyprland Configuration ---
  wayland.windowManager.hyprland = {
    enable = true; 

    settings = {
      # ONLY run the consolidated core services script now.
      "exec-once" = [
        "${hyprlandCoreServices}/bin/hyprland-core-services"
      ];
      
      "$mod" = "SUPER";

      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizeactive" 
        "$mod ALT, mouse:272, resizeactive"
      ];

      decoration = {
        rounding = 10;
        rounding_power = 2;
        active_opacity = 1.0;
        inactive_opacity = 1.0;
        shadow = {
          enabled = true;
          range = 4;
          render_power = 3;
        };
        blur = {
          enabled = true;
          size = 3;
          passes = 1;
          vibrancy = 0.1696;
        };
      };

      general = {
        gaps_in = 5;
        gaps_out = 5;
        border_size = 1;

        "col.active_border" = "rgba(cba6f7ff)";
        "col.inactive_border" = "rgba(f9e2afff)"; 

        resize_on_border = true;
        allow_tearing = true;
        
        layout = "dwindle";
      };

      animations = {
        enabled = true;
        animation = [
          "border, 1, 2, default"
          "fade, 1, 4, default"
          "windows, 1, 3, default, popin 80%"
          "workspaces, 1, 2, default, slide"
        ];
      };

      dwindle = {
        pseudotile = true;
        preserve_split = true;
      };

      master = {
        new_status = "master";
      };

      misc = {
        force_default_wallpaper = -1;
        disable_hyprland_logo = false;
      };

      input = {
        kb_layout = "pl";
        kb_variant = "";
        kb_model = "";
        kb_options = "";
        kb_rules = "";
        follow_mouse = 1;
        sensitivity = 0;
        touchpad = {
          natural_scroll = false;
        };
      };

      gesture = "3, horizontal, workspace";

      device = {
        name = "epic-mouse-v1";
        sensitivity = -0.5;
      };

      # Keybindings 
      bind = [
        "$mod, O, exec, ${extractGameArchive}/bin/extract-game-archive" # Archive Extractor Utility
        "$mod, W, exec, ${randomWallpaperLoader}/bin/random-wallpaper-loader" # Wallpaper randomizer
        "$mod, T, exec, ${pomodoroTimer}/bin/pomodoro-timer" # Pomodoro Timer (NEW)
        "$mod, RETURN, exec, kitty"
        "$mod, C, killactive,"
        "$mod, M, exit,"
        "$mod, E, exec, ${fileManager}" # Launch kitty -e nnn
        "$mod, K, exec, ${mediaSelector}/bin/mpv-media-selector" # Launch mpv media selector script
        "$mod, V, togglefloating,"
        "$mod, R, exec, wofi --show drun"
        "$mod, L, exec, lutris"
        "$mod, P, pseudo, # dwindle"
        "$mod, J, togglesplit, # dwindle"
        "$mod, left, movefocus, l"
        "$mod, right, movefocus, r"
        "$mod, up, movefocus, u"
        "$mod, down, movefocus, d"
        "$mod, 1, workspace, 1"
        "$mod, 2, workspace, 2"
        "$mod, 3, workspace, 3"
        "$mod, 4, workspace, 4"
        "$mod, 5, workspace, 5"
        "$mod, 6, workspace, 6"
        "$mod, 7, workspace, 7"
        "$mod, 8, workspace, 8"
        "$mod, 9, workspace, 9"
        "$mod, 0, workspace, 10"
        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"
        "$mod SHIFT, 4, movetoworkspace, 4"
        "$mod SHIFT, 5, movetoworkspace, 5"
        "$mod SHIFT, 6, movetoworkspace, 6"
        "$mod SHIFT, 7, movetoworkspace, 7"
        "$mod SHIFT, 8, movetoworkspace, 8"
        "$mod SHIFT, 9, movetoworkspace, 9"
        "$mod SHIFT, 0, movetoworkspace, 10"
        "$mod, S, togglespecialworkspace, magic"
        "$mod SHIFT, S, movetoworkspace, special:magic"
        "$mod, mouse_down, workspace, e+1"
        "$mod, mouse_up, workspace, e-1"
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizeactive" 
        ",XF86AudioRaiseVolume, exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"
        ",XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ",XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ",XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
        ",XF86MonBrightnessUp, exec, brightnessctl -e4 -n2 set 5%+"
        ",XF86MonBrightnessDown, exec, brightnessctl -e4 -n2 set 5%-"
        ",XF86AudioNext, exec, playerctl next"
        ",XF86AudioPause, exec, playerctl play-pause"
        ",XF86AudioPlay, exec, playerctl play-pause"
        ",XF86AudioPrev, exec, playerctl previous"
        ", Print, exec, grim - | wl-copy"
        "$mod, Print, exec, grim -g \"$(slurp)\" - | wl-copy"
      ];

      windowrule = [
        "suppressevent maximize, class:.*"
        "nofocus,class:^$,title:^$,xwayland:1,floating:1,fullscreen:0,pinned:0"

        # Game Rules for Lutris/Steam/Proton
        "float, class:^(lutris)$"             
        "noborder, class:^(lutris)$"              
        "noborder, class:^(.exe|.Exe)$"           
        "float, class:^(steam)$"              
        "fullscreen, class:^(steam)$"             
        "noborder, class:^(steam)$"               
      ];
    };
  };
}
