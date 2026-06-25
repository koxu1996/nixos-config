# pixma-scan — convenience wrapper around `scanimage` for the Canon PIXMA G3411.
#
# Provides the command:  pixma-scan <format> <resolution> <output>
#   e.g.  pixma-scan jpeg 600 /tmp/file1   or   pixma-scan png 300 /tmp/file2
#
# The scanner itself is configured as a static airscan (WSD) device in
# hardware-configuration.nix; this module only adds the front-end command.
{ pkgs, ... }:

let
  pixma-scan = pkgs.writeShellApplication {
    name = "pixma-scan";
    runtimeInputs = [ pkgs.sane-backends pkgs.coreutils ];
    text = ''
      DEVICE="''${PIXMA_SCAN_DEVICE:-airscan:w0:Canon G3010}"

      usage() {
        printf '%s\n' \
          "pixma-scan — scan a page from the Canon PIXMA G3411" \
          "" \
          "Usage: pixma-scan <format> <resolution> <output>" \
          "  format      jpeg | png | tiff | pdf" \
          "  resolution  150 | 300 | 600   (dpi)" \
          "  output      destination path (extension appended if missing)" \
          "" \
          "Examples:" \
          "  pixma-scan jpeg 600 /tmp/file1   ->  /tmp/file1.jpg" \
          "  pixma-scan png  300 ~/scan       ->  ~/scan.png" \
          "" \
          "Env: PIXMA_SCAN_DEVICE overrides the scanner (default: airscan:w0:Canon G3010)"
      }

      if [[ "''${1:-}" == "-h" || "''${1:-}" == "--help" ]]; then
        usage; exit 0
      fi
      if [[ "$#" -ne 3 ]]; then
        echo "error: expected 3 arguments, got $#" >&2
        echo >&2
        usage >&2
        exit 2
      fi

      fmt="$1"; res="$2"; out="$3"

      # Map the requested format to scanimage's --format value and a file extension.
      case "''${fmt,,}" in
        jpeg|jpg) sane_fmt="jpeg"; ext="jpg"  ;;
        png)      sane_fmt="png";  ext="png"  ;;
        tiff|tif) sane_fmt="tiff"; ext="tiff" ;;
        pdf)      sane_fmt="pdf";  ext="pdf"  ;;
        *) echo "error: unknown format '$fmt' (use: jpeg, png, tiff, pdf)" >&2; exit 2 ;;
      esac

      # The G3411 only exposes these resolutions.
      case "$res" in
        150|300|600) ;;
        *) echo "error: unsupported resolution '$res' (use: 150, 300, 600)" >&2; exit 2 ;;
      esac

      # Append the extension unless the caller already provided it.
      if [[ "''${out,,}" != *."$ext" ]]; then
        out="$out.$ext"
      fi

      dir="$(dirname "$out")"
      if [[ ! -d "$dir" ]]; then
        echo "error: output directory does not exist: $dir" >&2; exit 2
      fi

      echo "Scanning from $DEVICE at ''${res}dpi ($sane_fmt) -> $out" >&2
      if scanimage --device-name "$DEVICE" --format "$sane_fmt" \
           --resolution "$res" --output-file "$out"; then
        echo "Saved $out ($(du --apparent-size -h "$out" | cut -f1))" >&2
      else
        status=$?
        rm -f "$out"
        echo "error: scan failed (scanimage exit $status)." >&2
        echo "  - Is the printer powered on and on the network?" >&2
        echo "  - Verify it is visible:  scanimage -L" >&2
        echo "  - If its device name changed, set PIXMA_SCAN_DEVICE." >&2
        exit "$status"
      fi
    '';
  };
in
{
  home.packages = [ pixma-scan ];
}
