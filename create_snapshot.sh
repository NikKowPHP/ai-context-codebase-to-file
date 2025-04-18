#!/bin/bash
# -----------------------------------------------------------------------------
# Script Name: create_snapshot.sh
# Description: Scans a Git repository, extracts content from text files and
#              paths of image/other files, ignores specified directories/files,
#              and consolidates the information into a single snapshot file
#              in the project root, prepended with an AI context instruction.
#              Finally, attempts to reveal the snapshot file in the default
#              file manager (opens folder, selects file where possible).
# Usage:       Place this script anywhere. Run it from within a Git repository
#              or any subdirectory. It will automatically find the root.
#              ./create_snapshot.sh
# Output:      Creates/overwrites 'project_snapshot.txt' in the Git repo root.
#              Opens the project root folder in the default file manager,
#              attempting to select 'project_snapshot.txt'.
# Requirements: bash, git, find, file (core utilities), and potentially
#               xdg-utils (Linux), wslpath (WSL), specific file managers
#               (nautilus, dolphin, thunar) on Linux, or appropriate commands
#               for your OS.
# -----------------------------------------------------------------------------

# --- 1. Argument Parsing & Usage ---------------------------------------------
usage() {
    cat <<EOF
Usage: $(basename "$0") [ -f|--folder <path_to_project_root> ] \
[ -w|--write-to <output_file_path> ] [ -h|--help ]

Options:
  -f, --folder   Path to the folder you want to scan (optional).
                 If omitted, the script will auto‑detect the Git repo root.
  -w, --write-to Full path (or relative path) to write the snapshot file.
                 If omitted, defaults to \$PROJECT_ROOT/project_snapshot.txt
  -h, --help     Show this help message and exit.
EOF
    exit 1
}

# Collect CLI args
FORCE_ROOT=""
WRITE_TO=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--folder)
      if [[ -n "$2" && ! "$2" =~ ^- ]]; then
        FORCE_ROOT="$2"; shift 2
      else
        echo "ERROR: '$1' requires a non-empty argument." >&2; usage
      fi
      ;;
    -w|--write-to)
      if [[ -n "$2" && ! "$2" =~ ^- ]]; then
        WRITE_TO="$2"; shift 2
      else
        echo "ERROR: '$1' requires a non-empty argument." >&2; usage
      fi
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "ERROR: Unknown option: $1" >&2; usage
      ;;
  esac
done

set -e
set -o pipefail

# --- 2. Determine PROJECT_ROOT -----------------------------------------------
if [[ -n "$FORCE_ROOT" ]]; then
    echo "INFO: Using provided project root: $FORCE_ROOT"
    [[ -d "$FORCE_ROOT" ]] || { echo "ERROR: '$FORCE_ROOT' is not a directory." >&2; exit 1; }
    PROJECT_ROOT="$(cd "$FORCE_ROOT" && pwd)"
else
    echo "INFO: Identifying Git repository root..."
    PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
      echo "ERROR: Not inside a Git repository (or git not installed)." >&2
      exit 1
    }
fi
cd "$PROJECT_ROOT"
echo "INFO: Changed directory to project root: $PROJECT_ROOT"

# --- 3. Compute OUTPUT_FILE / ABSOLUTE_OUTPUT_FILE ---------------------------
if [[ -n "$WRITE_TO" ]]; then
  # User‐supplied path (may be relative or absolute)
  ABSOLUTE_OUTPUT_FILE="$(cd "$(dirname "$WRITE_TO")" && pwd)/$(basename "$WRITE_TO")"
  OUTPUT_FILE="$ABSOLUTE_OUTPUT_FILE"
else
  OUTPUT_FILENAME="project_snapshot.txt"
  ABSOLUTE_OUTPUT_FILE="$PROJECT_ROOT/$OUTPUT_FILENAME"
  OUTPUT_FILE="$OUTPUT_FILENAME"    # relative to $PROJECT_ROOT
fi
echo "INFO: Will write snapshot to: $ABSOLUTE_OUTPUT_FILE"

# --- 4. Define Ignored Items -------------------------------------------------
IGNORED_ITEMS=(
    ".git" node_modules vendor bower_components
    dist build out target public/build www
    .next .nuxt .svelte-kit .cache
    .venv venv env __pycache__ .pytest_cache .mypy_cache htmlcov
    coverage logs tmp temp
    .idea .vscode .project .settings
    .DS_Store Thumbs.db
)
# If output file lives under $PROJECT_ROOT, also ignore it by name:
if [[ "$ABSOLUTE_OUTPUT_FILE" == "$PROJECT_ROOT/"* ]]; then
  IGNORED_ITEMS+=( "$(basename "$ABSOLUTE_OUTPUT_FILE")" )
fi

echo "INFO: Ignoring: ${IGNORED_ITEMS[*]}"

# --- 5. Prepare Output & Header ---------------------------------------------
echo "INFO: Writing AI header to '$OUTPUT_FILE'..."
echo "# AI Context Reference: Project snapshot generated on $(date)" > "$ABSOLUTE_OUTPUT_FILE"

# --- 6. Build prune_args & Scan Files ---------------------------------------
prune_args=()
if [ ${#IGNORED_ITEMS[@]} -gt 0 ]; then
  prune_args+=( "(" )
  first=true
  for item in "${IGNORED_ITEMS[@]}"; do
    if [ "$first" = false ]; then prune_args+=( -o ); fi
    prune_args+=( -name "$item" )
    first=false
  done
  prune_args+=( ")" -prune )
fi

echo "INFO: Scanning files..."
find . "${prune_args[@]}" -o -type f -print0 |
  while IFS= read -r -d '' file; do
    REL="${file#./}"
    [[ "$REL" == "$(basename "$ABSOLUTE_OUTPUT_FILE")" ]] && continue

    MIME=$(file --mime-type -b "$file" || echo "unknown/error")
    case "$MIME" in
      text/*)
        echo "--- START FILE: $REL ---"
        cat "$file" || echo "[Error reading $REL]"
        echo "--- END FILE: $REL ---"; echo ;;
      image/*)
        echo "--- IMAGE FILE: $REL ---"; echo ;;
      *)
        echo "--- OTHER FILE ($MIME): $REL ---"; echo ;;
    esac
  done >> "$ABSOLUTE_OUTPUT_FILE"

echo "INFO: Snapshot complete: $ABSOLUTE_OUTPUT_FILE"

# --- 7. Reveal Snapshot File in File Manager ---
echo "INFO: Attempting to reveal '$OUTPUT_FILE' in the default file manager..."
# Goal: Open the containing folder ($PROJECT_ROOT) and select the file.
# This works reliably via specific commands on macOS and Windows.
# On Linux, we attempt specific file manager commands known to support selection,
# falling back to opening the folder if none are found or if the file is missing.

# We are in PROJECT_ROOT. Use ABSOLUTE_OUTPUT_FILE for commands needing it.

case "$(uname -s)" in
    Darwin)
        # macOS: Use 'open -R' which reveals (opens folder and selects) the file in Finder.
        if [ -f "$OUTPUT_FILE" ]; then
            open -R "$OUTPUT_FILE" && echo "INFO: Revealed '$OUTPUT_FILE' in Finder (opened folder and selected file)." || echo "WARN: Failed to reveal file using 'open -R'."
        else
            echo "WARN: Output file '$OUTPUT_FILE' not found. Cannot select it. Opening folder instead."
            open . && echo "INFO: Opened folder using 'open .'" || echo "WARN: Failed to open folder using 'open .'."
        fi
        ;;
    Linux)
        # Linux: Check for WSL first
        if [[ -f /proc/version ]] && grep -qiE "(Microsoft|WSL)" /proc/version &> /dev/null ; then
            # WSL: Use explorer.exe /select which reveals the file in Windows Explorer.
            if command -v wslpath &> /dev/null; then
                if [ -f "$OUTPUT_FILE" ]; then
                    WIN_PATH=$(wslpath -w "$ABSOLUTE_OUTPUT_FILE") # Use absolute path for wslpath
                    explorer.exe /select,"$WIN_PATH" && echo "INFO: Revealed '$OUTPUT_FILE' in Windows Explorer (opened folder and selected file)." || echo "WARN: Failed to reveal file using 'explorer.exe /select'. Ensure explorer.exe is accessible."
                else
                    echo "WARN: Output file '$OUTPUT_FILE' not found. Cannot select it. Opening folder instead."
                    explorer.exe . && echo "INFO: Opened folder in Windows Explorer using 'explorer.exe .'" || echo "WARN: Failed to open folder using 'explorer.exe .'."
                fi
            else
                echo "WARN: 'wslpath' command not found. Cannot determine Windows path to select file. Opening folder instead."
                explorer.exe . && echo "INFO: Opened folder in Windows Explorer using 'explorer.exe .'" || echo "WARN: Failed to open folder using 'explorer.exe .'."
            fi
        else
            # Standard Linux: Try specific file managers known to support selection.
            revealed=false
            if [ ! -f "$OUTPUT_FILE" ]; then
                 echo "WARN: Output file '$OUTPUT_FILE' not found. Cannot select it."
                 # Proceed to fallback (xdg-open .) below
            else
                # Try Nautilus (GNOME, Ubuntu default)
                if command -v nautilus &> /dev/null; then
                    echo "INFO: Found Nautilus. Attempting reveal using 'nautilus --select'..."
                    # Run in background, suppress output
                    nautilus --select "$ABSOLUTE_OUTPUT_FILE" &> /dev/null &
                    revealed=true
                    echo "INFO: Requested reveal via Nautilus."
                fi

                # Try Dolphin (KDE) if not already revealed
                if [ "$revealed" = false ] && command -v dolphin &> /dev/null; then
                    echo "INFO: Found Dolphin. Attempting reveal using 'dolphin --select'..."
                    dolphin --select "$ABSOLUTE_OUTPUT_FILE" &> /dev/null &
                    revealed=true
                    echo "INFO: Requested reveal via Dolphin."
                fi

                # Try Thunar (XFCE) if not already revealed
                # Thunar often selects when given the direct path, but less guaranteed.
                if [ "$revealed" = false ] && command -v thunar &> /dev/null; then
                    echo "INFO: Found Thunar. Attempting reveal by opening file path (may select file)..."
                    thunar "$ABSOLUTE_OUTPUT_FILE" &> /dev/null &
                    revealed=true
                    echo "INFO: Requested reveal via Thunar (behavior might vary)."
                fi
            fi

            # Fallback: If no specific manager was found/used or file was missing, use xdg-open to open the folder.
            if [ "$revealed" = false ]; then
                if command -v xdg-open &> /dev/null; then
                    echo "INFO: No specific file manager found or file missing. Falling back to opening the containing folder using 'xdg-open .'."
                    xdg-open . &> /dev/null
                    if [ $? -eq 0 ]; then
                        echo "INFO: Successfully requested opening current folder via 'xdg-open .'."
                    else
                        echo "WARN: Fallback 'xdg-open .' failed."
                    fi
                else
                    echo "WARN: No specific file manager found, and fallback 'xdg-open' command not found. Cannot automatically open folder. Please install xdg-utils or a supported file manager (Nautilus, Dolphin, Thunar)."
                fi
            fi
        fi
        ;;
    CYGWIN*|MINGW*|MSYS*)
        # Windows environments (Git Bash, etc.): Use explorer.exe /select which reveals the file.
         if [ -f "$OUTPUT_FILE" ]; then
            # Using the relative filename works because we are in the correct CWD ($PROJECT_ROOT).
            explorer.exe /select,"$OUTPUT_FILE" && echo "INFO: Revealed '$OUTPUT_FILE' in Windows Explorer (opened folder and selected file)." || echo "WARN: Failed to reveal file using 'explorer.exe /select'."
         else
            echo "WARN: Output file '$OUTPUT_FILE' not found. Cannot select it. Opening folder instead."
            explorer.exe . && echo "INFO: Opened folder in Windows Explorer using 'explorer.exe .'" || echo "WARN: Failed to open folder using 'explorer.exe .'."
         fi
        ;;
    *)
        # Unsupported OS
        echo "WARN: Unsupported OS '$(uname -s)'. Cannot automatically reveal the file."
        ;;
esac

echo "INFO: Script finished."