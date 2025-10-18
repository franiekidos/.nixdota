# My NixOS dotfile

my catppuccin hyprland rice with extra bonuses

# Features

This repository contains my personal NixOS configuration focused on the Hyprland Wayland compositor and the beautiful Catppuccin Mocha color scheme.

## Key Features include:

Zsh as the default shell (configured via NixOS/Home Manager).

Waybar for the status bar.

Wofi as the application launcher.

Mako for notifications.

Gaming Optimized Environment with specific Vulkan/Proton/Wine environment variables for Lutris and Steam.

Robust Hyprpaper Startup with an integrated retry loop to guarantee wallpaper loading on session start.

# Utility Scripts:

Random wallpaper loader ($mod+W).

Archive extractor ($mod+O).

MPV media selector ($mod+K).

Pomodoro timer ($mod+T).

# Credits

 Massive props to:
 
 BryceWalkerDev - the GTK Theme
 
 [Check Him out](https://github.com/brycewalkerdev/catppuccin-gtk)
 
 The Catppuccin Community - the entire color scheme
 
 [Check them out](https://github.com/catppuccin)
 
 and yall


# Installation
## 🚀 Installation

This configuration uses a **Nix Flake** structure. Here's how to deploy it on your system:

### 1. Prerequisites

Make sure you are running **NixOS** and have **flakes enabled**.

Edit `/etc/nix/nix.conf` to include:

```nix
experimental-features = nix-command flakes
```

## 2. Clone the Repository

We recommend cloning the config into /etc/nixos/my-config:
```bash
git clone https://github.com/franiekidos/.nixdota /etc/nixos/my-config
cd /etc/nixos/my-config
```
## 3. Customize the Flake

You must adjust the primary configuration (likely in your flake.nix) to reference your specific hostname and username.

The nixosConfigurations block in your flake.nix should import the modules and assign them to your system's hostname.
```nix
nixosConfigurations = {
  # 1. REPLACE "antnix" with your actual machine's hostname
  "my-hostname" = nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      ./configuration.nix
      home-manager.nixosModules.home-manager
      {
        # 2. REPLACE "antis" with your actual username
        home-manager.users."my-username" = import ./home.nix;
      }
    ];
  };
};
```

## 4. Configure Private Paths

This setup uses a non-public file to define local paths for things like wallpapers, which you shouldn't commit to GitHub.

Create the secrets/paths.nix file:
```bash
mkdir -p secrets
nano secrets/paths.nix
```

Paste the following content, making sure to adjust the path to your local wallpaper directory:

```nix
{
  wallpaperDir = "/home/your-username/Pictures/Wallpapers"; # ADJUST THIS PATH
}
```

Crucial Security Note: Ensure the secrets directory is listed in your .gitignore to prevent committing sensitive local paths.

## 5. Build and Apply

Run the nixos-rebuild switch command to build the new system and apply the Home Manager configuration:

# Example command - replace 'my-config' and 'my-hostname' as needed
```bash
sudo nixos-rebuild switch --flake /etc/nixos/my-config#my-hostname
```

After the build finishes successfully, log out and log back in to fully activate the new Hyprland session, Waybar, and the robust Hyprpaper startup.
