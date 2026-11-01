#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"

echo "============================================================"
echo "        AQUASTASIS - COP31 ANTALYA ECOSYSTEM DEFENSE        "
echo "============================================================"
echo ""

# 1. Check if godot is in PATH
if command -v godot &> /dev/null; then
    echo "[OK] Godot bulundu. Aquastasis başlatılıyor..."
    godot --path .
    exit 0
fi

# 2. Check local binary
if [ -x "./godot" ]; then
    echo "[OK] Yerel Godot bulundu. Aquastasis başlatılıyor..."
    ./godot --path .
    exit 0
fi

# 3. Check user local bin
if [ -x "$HOME/.local/bin/godot" ]; then
    echo "[OK] ~/.local/bin/godot bulundu. Aquastasis başlatılıyor..."
    "$HOME/.local/bin/godot" --path .
    exit 0
fi

echo "[BİLGİ] Godot bulunamadı. Lütfen 'godot' motorunu yükleyin veya çalıştırılabilir dosyayı bu klasöre koyun."
exit 1
