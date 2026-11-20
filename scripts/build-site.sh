#!/bin/sh
# Assemble the static site into OUT_DIR (default: ./dist).
#
# - Extracts each content/archives/<user>.tar.gz to OUT_DIR/~<user>/
# - Removes server-side code and server config from the archives (no PHP is
#   ever served; nginx would otherwise hand out PHP source as plain text)
# - Copies content/ann to OUT_DIR/~ann/ and generates its index pages
# - Copies site/ (the hand-written root pages) to OUT_DIR/
#
# POSIX sh so it runs unchanged in the alpine build stage and on macOS.
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT_DIR=${OUT_DIR:-$ROOT/dist}

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

# --- root pages ---------------------------------------------------------
cp -R "$ROOT/site/." "$OUT_DIR/"

# --- archived family home directories -----------------------------------
for tarball in "$ROOT"/content/archives/*.tar.gz; do
  user=$(basename "$tarball" .tar.gz)
  dest="$OUT_DIR/~$user"
  mkdir -p "$dest"
  tar -xzf "$tarball" -C "$dest" --strip-components=1
done

# Strip anything that is server-side code, server config, or VCS metadata.
find "$OUT_DIR" -depth \( \
  -iname '*.php' -o -iname '*.php[0-9]' -o -iname '*.phtml' -o -iname '*.phps' \
  -o -iname '*.inc' -o -iname '*.tpl' -o -iname '*.sql' \
  -o -iname '*.cgi' -o -iname '*.pl' -o -iname '*.py' -o -iname '*.sh' \
  -o -name '.htaccess' -o -name '.htpasswd' -o -name 'php.ini' \
  -o -name '.git' -o -name '.gitignore' -o -name '.svn' -o -name '.DS_Store' \
  \) -exec rm -rf {} +

# --- Ann's poems --------------------------------------------------------
cp -R "$ROOT/content/ann" "$OUT_DIR/~ann"

html_escape() {
  printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g'
}

# Minimal percent-encoding for the few characters that appear in poem
# filenames and are not safe in an href.
url_escape() {
  printf '%s' "$1" | sed -e 's/%/%25/g' -e 's/ /%20/g' -e 's/"/%22/g' -e 's/#/%23/g' -e 's/?/%3F/g'
}

poem_list() {
  find "$OUT_DIR/~ann/poems" -maxdepth 1 -type f -size +0 ! -name 'index.html' \
    | LC_ALL=C sort \
    | while IFS= read -r file; do
        base=$(basename "$file")
        name=${base%.html}
        name=$(printf '%s' "$name" | tr '_' ' ')
        printf '  <li><a href="/~ann/poems/%s">%s</a></li>\n' \
          "$(url_escape "$base")" "$(html_escape "$name")"
      done
}

POEMS=$(poem_list)
for index in "$OUT_DIR/~ann/index.html" "$OUT_DIR/~ann/poems/index.html"; do
  {
    sed -n '1,/@@POEMS@@/p' "$ROOT/templates/ann-index.html" | sed '$d'
    printf '%s\n' "$POEMS"
    sed -n '/@@POEMS@@/,$p' "$ROOT/templates/ann-index.html" | sed '1d'
  } > "$index"
done

# Everything must be world-readable for the unprivileged nginx user.
chmod -R a+rX "$OUT_DIR"

echo "Built site in $OUT_DIR ($(find "$OUT_DIR" -type f | wc -l | tr -d ' ') files)"
