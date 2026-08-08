# -*- mode: python ; coding: utf-8 -*-
# athena_gui.spec — PyInstaller spec for Athena.app
#
# Build with: pyinstaller gui/athena_gui.spec --clean --noconfirm
# Output:     dist/Athena.app
#

block_cipher = None

a = Analysis(
    ['gui/athena_gui.py'],
    pathex=[],
    binaries=[],
    datas=[
        ('gui/themes/yellow.qss', 'gui/themes'),
        ('gui/assets/athena.icns', 'gui/assets'),
    ],
    hiddenimports=['PyQt6.QtCore', 'PyQt6.QtWidgets', 'PyQt6.QtGui'],
    hookspath=[],
    runtime_hooks=[],
    excludes=['tkinter', 'unittest', 'pytest'],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)
pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='Athena',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    console=False,
    disable_windowed_traceback=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon='gui/assets/athena.icns',
)

coll = COLLECT(
    exe,
    a.binaries,
    a.zipfiles,
    a.datas,
    strip=False,
    upx=False,
    upx_exclude=[],
    name='Athena',
)

app = BUNDLE(
    coll,
    name='Athena.app',
    icon='gui/assets/athena.icns',
    bundle_identifier='com.xscope0.athena',
    info_plist={
        'CFBundleName': 'Athena',
        'CFBundleDisplayName': 'Athena',
        'CFBundleShortVersionString': '1.0.0',
        'CFBundleVersion': '1',
        'NSHighResolutionCapable': 'True',
        'LSMinimumSystemVersion': '12.0',
        'NSHumanReadableCopyright': 'Copyright © 2026 xscope0. MIT License.',
    },
)
