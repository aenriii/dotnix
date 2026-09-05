{
  config,
  inputs,
  ...
}:
let
  home = config.home.homeDirectory;
in
{
  imports = [ inputs.noctalia-shell.homeModules.default ];

  programs.noctalia = {
    enable = true;
    systemd.enable = true;

    settings = {
      shell = {
        avatar_path = "${home}/.face";
        time_format = "{:%I\n%M}";

        launcher = {
          compact = true;
          pinned = [
            "cider"
            "zen"
            "equibop"
            "signal"
          ];
        };
      };

      wallpaper = {
        enabled = true;
        directory = "${home}/Pictures/wallpapers";
        fill_color = "#000000";
        automation.recursive = true; 
      };

      dock = {
        enabled = false;
        auto_hide = false;
        show_dots = true; 
      };

      system.monitor.enabled = true;

      # ── bar ────────────────────────────────────────────────────────────

      
      bar.main = {
        position = "top";
        start = [
          "launcher"
          "clock"
          "cpu"
          "ram"
          "media"
          "active_window"
        ];
        center = [ "workspaces" ];
        end = [
          "tray"
          "notifications"
          "volume"
          "control-center"
        ];
      };

      widget = {
        # Qt format tokens became strftime.
        clock = {
          format = "{:%Y/%m/%d @ %H:%M:%S}"; # was "yyyy/MM/dd @ HH:mm:ss"
          vertical_format = "{:%H %M - %d %m}"; # was "HH mm - dd MM"
          tooltip_format = "{:%H:%M %a, %b %d}"; # was "HH:mm ddd, MMM dd"
        };

        cpu = {
          type = "sysmon";
          stat = "cpu_usage";
        };
        ram = {
          type = "sysmon";
          stat = "ram_pct";
        };

        media = {
          artist_first = true;
          hide_when_no_media = false;
        };

        active_window = {
          max_length = 145; 
          display = "icon_and_text"; 
          title_scroll = "on_hover";
        };

        tray = {
          hide_passive = false;
          drawer = true;
          hidden = [ ];
          pinned = [ ];
        };

        notifications.hide_when_no_unread = false;

        volume = {
          device = "output";
          actions.middle = "exec pwvucontrol || pavucontrol";
        };

        workspaces = {
          label_source = "id"; 
          max_label_chars = 2; 
          labels_only_when_occupied = true;
          hide_when_empty = false; 
          focused_output_only = false; 
          focused_color = "primary";
          occupied_color = "secondary";
          empty_color = "secondary";
        };
      };
    };
  };
}
