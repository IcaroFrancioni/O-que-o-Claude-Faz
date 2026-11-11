#!/usr/bin/env bash
# Exporta o Returing para todos os alvos possíveis NESTE sistema e pula (com aviso claro) os que não podem ser
# gerados aqui. Saídas em build/<plataforma>/.
#
#   ./exportar.sh                 # modo debug (padrão), todos os alvos possíveis
#   ./exportar.sh release         # modo release (Android release exige keystore, veja EXPORTAR.md)
#   ./exportar.sh debug windows linux android   # só os alvos pedidos
#
# Alvos: windows linux linux-arm64 macos android aab ios web
# Variável GODOT = caminho do executável do Godot 4.7.x (senão procura godot, godot4 e o app do macOS).
set -u
cd "$(dirname "$0")"

MODO="debug"
case "${1:-}" in debug|release) MODO="$1"; shift;; esac
ALVOS=("$@")
[ ${#ALVOS[@]} -eq 0 ] && ALVOS=(windows linux linux-arm64 macos android aab ios web)

SISTEMA="$(uname -s)"
OK=(); PULADOS=(); FALHAS=()

# --- Godot ---
achar_godot() {
  if [ -n "${GODOT:-}" ] && [ -x "$GODOT" ]; then echo "$GODOT"; return; fi
  for c in godot godot4 Godot; do command -v "$c" >/dev/null 2>&1 && { command -v "$c"; return; }; done
  [ -x "/Applications/Godot.app/Contents/MacOS/Godot" ] && { echo "/Applications/Godot.app/Contents/MacOS/Godot"; return; }
  return 1
}
GODOT_BIN="$(achar_godot)" || { echo "ERRO: Godot não encontrado. Instale o Godot 4.7.x ou defina GODOT=/caminho/do/godot"; exit 2; }
VERSAO="$("$GODOT_BIN" --version | cut -d. -f1-4 | sed 's/\.official.*//')"   # ex.: 4.7.2.stable
echo "Godot: $GODOT_BIN ($VERSAO) | sistema: $SISTEMA | modo: $MODO"

# --- Templates de exportação ---
if [ "$SISTEMA" = "Darwin" ]; then DIR_TPL="$HOME/Library/Application Support/Godot/export_templates"
else DIR_TPL="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates"; fi
case "$SISTEMA" in MINGW*|MSYS*|CYGWIN*) DIR_TPL="$APPDATA/Godot/export_templates";; esac
TEM_TEMPLATES=1
if [ ! -d "$DIR_TPL/$VERSAO" ]; then
  TEM_TEMPLATES=0
  echo "AVISO: templates de exportação $VERSAO não instalados em '$DIR_TPL/$VERSAO'."
  echo "       Instale em Editor > Gerenciar templates de exportação (ou veja EXPORTAR.md)."
fi

# Reimporta o projeto (gera o cache .godot/ que a exportação precisa).
"$GODOT_BIN" --headless --path . --import >/dev/null 2>&1

exportar() {  # $1 alvo, $2 nome do preset, $3 arquivo de saída
  local alvo="$1" preset="$2" saida="$3"
  mkdir -p "$(dirname "$saida")"
  local flag="--export-debug"; [ "$MODO" = "release" ] && flag="--export-release"
  echo ">>> exportando $alvo: $preset -> $saida"
  if "$GODOT_BIN" --headless --path . "$flag" "$preset" "$saida" 2>&1 | tee "build/log_$alvo.txt" | grep -q "ERROR"; then
    # Godot imprime ERROR em avisos de saída também: o arquivo gerado é o que decide.
    if [ -s "$saida" ] || [ -d "$saida" ]; then OK+=("$alvo ($saida) [com avisos: build/log_$alvo.txt]"); else FALHAS+=("$alvo (veja build/log_$alvo.txt)"); fi
  elif [ -s "$saida" ] || [ -d "$saida" ]; then OK+=("$alvo ($saida)"); else FALHAS+=("$alvo (veja build/log_$alvo.txt)"); fi
}

mkdir -p build
for alvo in "${ALVOS[@]}"; do
  if [ "$TEM_TEMPLATES" -eq 0 ] && [ "$alvo" != "ios" ]; then
    PULADOS+=("$alvo: sem templates de exportação instalados"); continue
  fi
  case "$alvo" in
    windows)    exportar windows "Windows (PC)" "build/windows/Returing.exe" ;;
    linux)      exportar linux "Linux (PC, x86_64)" "build/linux/Returing.x86_64" ;;
    linux-arm64) exportar linux-arm64 "Linux (PC, arm64)" "build/linux-arm64/Returing.arm64" ;;
    macos)
      exportar macos "macOS (PC, universal)" "build/macos/Returing.zip"
      if [ "$SISTEMA" != "Darwin" ]; then
        PULADOS+=("macos (assinatura/notarização): só em um Mac — o .zip gerado NÃO está assinado (veja EXPORTAR.md)")
      fi ;;
    web)        exportar web "Web (iPhone, Android e navegador)" "build/web/index.html" ;;
    android|aab)
      # Precisa de JDK 17 e Android SDK configurados no Godot (Editor > Configurações do Editor > Export > Android).
      if ! { [ -n "${JAVA_HOME:-}" ] || command -v java >/dev/null 2>&1; }; then PULADOS+=("$alvo: JDK 17 não encontrado"); continue; fi
      if [ -z "${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}" ]; then PULADOS+=("$alvo: Android SDK não encontrado (defina ANDROID_HOME)"); continue; fi
      if [ "$MODO" = "release" ] && [ -z "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:-}" ]; then PULADOS+=("$alvo: release exige GODOT_ANDROID_KEYSTORE_RELEASE_PATH/_USER/_PASSWORD"); continue; fi
      if [ "$alvo" = "android" ]; then exportar android "Android (APK, arm64)" "build/android/Returing.apk"
      else
        if [ ! -d android/build ]; then PULADOS+=("aab: instale o modelo de compilação Android (Projeto > Instalar modelo de compilação Android) — veja EXPORTAR.md"); continue; fi
        exportar aab "Android (AAB, arm64)" "build/android/Returing.aab"
      fi ;;
    ios)
      if [ "$SISTEMA" != "Darwin" ] || ! command -v xcodebuild >/dev/null 2>&1; then
        PULADOS+=("ios: só exporta em macOS com Xcode instalado (conta de desenvolvedor Apple para rodar em aparelho)"); continue
      fi
      exportar ios "iOS (iPhone e iPad)" "build/ios/Returing.xcodeproj" ;;
    *) PULADOS+=("$alvo: alvo desconhecido") ;;
  esac
done

echo; echo "================ RESULTADO ================"
for x in "${OK[@]:-}"; do [ -n "$x" ] && echo "OK       $x"; done
for x in "${PULADOS[@]:-}"; do [ -n "$x" ] && echo "PULADO   $x"; done
for x in "${FALHAS[@]:-}"; do [ -n "$x" ] && echo "FALHOU   $x"; done
[ ${#FALHAS[@]} -eq 0 ] || exit 1
exit 0
