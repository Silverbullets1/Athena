# athena.icns (placeholder)

The actual `athena.icns` is a binary file that cannot be stored in this repo.
Generate it locally before building the .dmg:

```bash
# 1. Start with a 1024x1024 PNG named athena-1024.png
#    (yellow Athena helmet on charcoal background, alpha channel)

# 2. Create the .iconset directory
mkdir athena.iconset
sips -z 16 16    athena-1024.png --out athena.iconset/icon_16x16.png
sips -z 32 32    athena-1024.png --out athena.iconset/icon_16x16@2x.png
sips -z 32 32    athena-1024.png --out athena.iconset/icon_32x32.png
sips -z 64 64    athena-1024.png --out athena.iconset/icon_32x32@2x.png
sips -z 128 128  athena-1024.png --out athena.iconset/icon_128x128.png
sips -z 256 256  athena-1024.png --out athena.iconset/icon_128x128@2x.png
sips -z 256 256  athena-1024.png --out athena.iconset/icon_256x256.png
sips -z 512 512  athena-1024.png --out athena.iconset/icon_256x256@2x.png
sips -z 512 512  athena-1024.png --out athena.iconset/icon_512x512.png
sips -z 1024 1024 athena-1024.png --out athena.iconset/icon_512x512@2x.png

# 3. Convert to .icns
iconutil -c icns athena.iconset -o athena.icns

# 4. Place in this directory
mv athena.icns gui/assets/athena.icns
```

The .icns is consumed by:
- `gui/athena_gui.spec` (PyInstaller spec) — sets the bundle icon
- `dist/Athena.app/Contents/Resources/Athena.icns` (the bundled app icon)

If `athena.icns` is missing, pyinstaller will warn but the build will succeed
with a generic icon. The .dmg pipeline (`scripts/build_dmg.sh`) does not
fail on missing icon.
