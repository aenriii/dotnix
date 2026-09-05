{ ... }:
{
  programs.noctalia.settings = {
    theme = {
      mode = "dark";
      source = "builtin";
      builtin = "Catppuccin";
    };
    desktop_widgets = {
      enabled = true;
      widget_order = [
        "clock_main"
        "media_main"
        "sysmon_main"
      ];

      widget = {
        clock_main = {
          type = "clock";
          output = "HDMI-A-1";
          cx = 35.0; # was x = 35
          cy = 70.0; # was y = 70
          placement_width = 1920.0;
          placement_height = 1080.0;
        };

        media_main = {
          type = "media_player";
          output = "HDMI-A-1";
          cx = 35.0;
          cy = 240.0;
          placement_width = 1920.0;
          placement_height = 1080.0;
        };

        sysmon_main = {
          type = "sysmon";
          output = "HDMI-A-1";
          cx = 215.0;
          cy = 70.0;
          placement_width = 1920.0;
          placement_height = 1080.0;
        };
      };
    };
  };
  programs.niri.settings = {
    outputs = {
      "HDMI-A-1" = {
        enable = true;
        mode.height = 1080;
        mode.width = 1920;
        mode.refresh = 60.000;
        position = {
          x = 0;
          y = 0;
        };
      };
      "DP-3" = {
        enable = true;
        mode.height = 1080;
        mode.width = 1920;
        mode.refresh = 60.000;
        position = {
          x = 1920;
          y = 0;
        };
      };
    };
  };
}
