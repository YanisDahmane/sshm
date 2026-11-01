#!/usr/bin/env bash
# Builds the pack mockups: HTML (gen.py), CSS per pack (Tailwind CLI of the
# project), screenshots (headless Chrome) as light JPEGs in png/.
set -euo pipefail
cd "$(dirname "$0")"
python3 gen.py
TAILWIND="$(cd ../../.. && RBENV_VERSION=3.4.2 bundle exec ruby -e 'print Gem.bin_path("tailwindcss-ruby", "tailwindcss")')"
for pack in A B C D E; do
  RBENV_VERSION=3.4.2 "$TAILWIND" -i "$pack.input.css" -o "$pack.out.css" --minify 2>/dev/null
done
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
mkdir -p png
while read -r pack name kind; do
  html="file://$PWD/$pack/$name.html"
  if [ "$kind" = mobile ]; then size=600,900; else size=1440,1000; fi
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 --window-size=$size \
    --screenshot="png/$pack-$name.png" "$html" >/dev/null 2>&1
  [ "$kind" = mobile ] && magick "png/$pack-$name.png" -crop 390x900+0+0 +repage "png/$pack-$name.png"
  magick "png/$pack-$name.png" -quality 82 "png/$pack-$name.jpg" && rm "png/$pack-$name.png"
done < manifest.txt
echo "done: $(ls png | wc -l) images"
