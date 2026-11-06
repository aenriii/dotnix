{ inputs, pkgs, lib, ... }:

let
  prefs = import ./prefs.nix;

    allowedPrefixes = [
    "accessibility." "alerts." "app.update." "browser." "datareporting.policy."
    "devtools." "dom." "extensions." "general.autoScroll" "general.smoothScroll"
    "geo." "gfx." "identity.fxaccounts.toolbar." "intl." "keyword.enabled"
    "layers." "layout." "mathml.disabled" "media." "network." "pdfjs." "places."
    "pref." "print." "privacy.baselineFingerprintingProtection"
    "privacy.fingerprintingProtection" "privacy.globalprivacycontrol.enabled"
    "privacy.userContext.enabled" "privacy.userContext.ui.enabled" "sidebar."
    "signon." "spellchecker." "svg.context-properties.content.enabled"
    "svg.disabled" "toolkit.legacyUserProfileCustomizations.stylesheets" "ui."
    "webgl.disabled" "webgl.force-enabled" "widget." "xpinstall.enabled"
    "xpinstall.whitelist.required"
  ];
  # security.* is matched exactly, never by prefix.
  allowedSecurityPrefs = [
    "security.block_fileuri_script_with_wrong_mime"
    "security.csp.reporting.enabled"
    "security.default_personal_cert"
    "security.disable_button.openCertManager"
    "security.disable_button.openDeviceManager"
    "security.insecure_connection_text.enabled"
    "security.insecure_connection_text.pbmode.enabled"
    "security.mixed_content.block_active_content"
    "security.mixed_content.block_display_content"
    "security.mixed_content.upgrade_display_content"
    "security.osclientcerts.autoload"
    "security.OCSP.enabled"
    "security.OCSP.require"
    "security.pki.certificate_transparency.disable_for_hosts"
    "security.pki.certificate_transparency.disable_for_spki_hashes"
    "security.pki.certificate_transparency.mode"
    "security.ssl.enable_ocsp_stapling"
    "security.ssl.errorReporting.enabled"
    "security.ssl.require_safe_negotiation"
    "security.storage.encryption.sqlite.enabled"
    "security.tls.enable_0rtt_data"
    "security.tls.hello_downgrade_check"
    "security.tls.version.enable-deprecated"
    "security.warn_submit_secure_to_insecure"
    "security.webauthn.always_allow_direct_attestation"
  ];
  blockedPrefs = [
    "app.update.channel" "app.update.lastUpdateTime" "app.update.migrated"
    "browser.vpn_promo.disallowed_regions"
  ];

  lockable =
    name:
    !(lib.elem name blockedPrefs)
    && (
      if lib.hasPrefix "security." name then
        lib.elem name allowedSecurityPrefs
      else
        lib.any (p: lib.hasPrefix p name) allowedPrefixes
    );
in
{
  imports = [ inputs.zen-browser-darwin.homeModules.beta ];

  config = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    programs.zen-browser = {
      enable = true;
      darwin.packageMode = "signed";

      policies = import ./policies.nix // {
        ExtensionSettings = import ./extensions.nix;
        Preferences = lib.mapAttrs (_: Value: {
          inherit Value;
          Status = "locked";
        }) (lib.filterAttrs (name: _: lockable name) prefs);
      };

      profiles.default = {
        id = 0;
        isDefault = true;
        settings = prefs;
      };
    };
  };
}
