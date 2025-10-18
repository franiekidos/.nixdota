{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Bootloader.
  # Add GRUB configuration
   boot.loader = {
    # For UEFI systems, it's often better to use systemd-boot as it's simpler.
    # But if you want GRUB, this is the way:
    grub = {
      enable = true;
      efiSupport = true;
      device = "nodev"; # This is critical for UEFI
      useOSProber = true; # Scan for other OSes
    };
    efi = {
      canTouchEfiVariables = true; # Allow NixOS to manage EFI boot entries
      efiSysMountPoint = "/boot";  # Mountpoint of your EFI partition (common)
    };
  };

  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_zen;
  services.flatpak.enable = true;
  networking.hostName = "antnix"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  hardware.opengl.driSupport32Bit = true;
  hardware.pulseaudio.support32Bit = true;
  hardware.xpadneo.enable = true;
  programs.zsh.enable = true;
  users.users.antis.shell = pkgs.zsh;  
  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
       # Shows battery charge of connected devices on supported
        # Bluetooth adapters. Defaults to 'false'.
        Experimental = true;
        # When enabled other devices can connect faster to us, however
        # the tradeoff is increased power consumption. Defaults to
        # 'lse'
         Privacy = "device";
        JustWorksRepairing = "always";
        Class = "0x000100";
        FastConnectable = true;
      };
      Policy = {
        # Enable all controllers when they are found. This includes
        # adapters present on start as well as adapters that are plugged
        # in later on. Defaults to 'true'.
        AutoEnable = true;
      };
      Controller = {
        DisableExternalPlugins = true;
      };
    };
  };
  services.blueman.enable = true;
  # Enable networking
  networking.networkmanager.enable = true;
  programs.dconf.enable = true;
  # enable flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  # Enable power-profiles-daemon
  services.power-profiles-daemon.enable = true;
  # Hypr
  services.xserver.displayManager.sddm.enable = true;
  services.xserver.displayManager.sddm.wayland.enable = true;
  programs.appimage.enable = true;
  programs.appimage.binfmt = true;
  programs.appimage.package = pkgs.appimage-run.override {
    extraPkgs = pkgs: [ pkgs.libepoxy ];
  };
  programs.hyprland = {
    enable = true;
    withUWSM = false; # recommended for most users
    xwayland.enable = true; # Xwayland can be disabled.
  };
  # Set your time zone.
  time.timeZone = "Europe/Warsaw";

  # Select internationalisation properties.
  i18n.defaultLocale = "pl_PL.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "pl_PL.UTF-8";
    LC_IDENTIFICATION = "pl_PL.UTF-8";
    LC_MEASUREMENT = "pl_PL.UTF-8";
    LC_MONETARY = "pl_PL.UTF-8";
    LC_NAME = "pl_PL.UTF-8";
    LC_NUMERIC = "pl_PL.UTF-8";
    LC_PAPER = "pl_PL.UTF-8";
    LC_TELEPHONE = "pl_PL.UTF-8";
    LC_TIME = "pl_PL.UTF-8";
  };

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "pl";
    variant = "";
  };

  # Configure console keymap
  console.keyMap = "pl2";

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.antis = {
    isNormalUser = true;
    description = "antis";
    extraGroups = [ "networkmanager" "wheel" "input" ];
    packages = with pkgs; [];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
  #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
  #  wget
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  #Enable OpenGL
  hardware.graphics = {
    enable = true;
  };

  #Nvidia Drivers
  services.xserver.videoDrivers = ["nvidia"];

  # Drivers settings
  hardware.nvidia = {
    modesetting.enable = true;
    #turn on when app crashes after suspend
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.beta;
  };
  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?

  # Additional GRUB configurations
  boot.zfs.forceImportRoot = false;  # Force import of ZFS root filesystem
  system.nixos.label = "NixOS";  # Label for the NixOS system
}
