# Exportar o Returing (Windows, Linux, macOS, Android e iOS)

Versão do Godot: **4.7.2** (Forward+ no PC, `gl_compatibility` no celular). Todos os presets estão em
`export_presets.cfg` e usam o mesmo nome (**Returing**), a mesma versão (**1.0.0**), o mesmo identificador
(`com.returing.game`) e os ícones gerados em `assets/gerados/` (`tools/gerar_assets.py`).

## Atalho: um comando para tudo

| Sistema | Comando |
|---|---|
| Linux / macOS / Git Bash | `./exportar.sh` (ou `./exportar.sh release`, ou `./exportar.sh debug windows linux`) |
| Windows (cmd) | `exportar.bat` (ou `exportar.bat release`, ou `exportar.bat debug windows linux`) |

Os scripts exportam todos os alvos possíveis **neste** sistema e **pulam com aviso claro** os que não dá
(sem templates, sem JDK/Android SDK, iOS fora do macOS...). Saídas em `build/<plataforma>/`, logs em `build/log_<alvo>.txt`.
Defina `GODOT=/caminho/do/godot` se o executável não estiver no PATH.

## 1. Templates de exportação (necessário para tudo)

* No editor: **Editor > Gerenciar templates de exportação > Baixar e instalar** (versão 4.7.2).
* Ou à mão: baixe `Godot_v4.7.2-stable_export_templates.tpz` de
  <https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable>, confira o SHA-512 do `SHA512-SUMS.txt`
  e extraia o conteúdo da pasta `templates/` em:
  * Windows: `%APPDATA%\Godot\export_templates\4.7.2.stable\`
  * Linux: `~/.local/share/godot/export_templates/4.7.2.stable/`
  * macOS: `~/Library/Application Support/Godot/export_templates/4.7.2.stable/`

## 2. Plataformas

| Plataforma | Preset | Saída | Onde pode ser gerado |
|---|---|---|---|
| Windows (x86_64) | `Windows (PC)` | `build/windows/Returing.exe` (PCK embutido) | qualquer sistema |
| Linux (x86_64) | `Linux (PC, x86_64)` | `build/linux/Returing.x86_64` | qualquer sistema |
| Linux (arm64) | `Linux (PC, arm64)` | `build/linux-arm64/Returing.arm64` | qualquer sistema |
| macOS (universal) | `macOS (PC, universal)` | `build/macos/Returing.zip` | qualquer sistema (**sem assinatura**; assinar só em Mac) |
| Android (APK, arm64) | `Android (APK, arm64)` | `build/android/Returing.apk` | precisa de JDK 17 + Android SDK |
| Android (AAB, arm64) | `Android (AAB, arm64)` | `build/android/Returing.aab` | idem + modelo de compilação Android (gradle) |
| iOS (iPhone e iPad) | `iOS (iPhone e iPad)` | `build/ios/Returing.xcodeproj` | **só em macOS com Xcode** |
| Navegador (extra) | `Web (iPhone, Android e navegador)` | `build/web/index.html` | qualquer sistema |

### Windows / Linux
Só os templates. Nada de assinatura. (O ícone do `.exe` só é gravado com o `rcedit` configurado em
Editor > Configurações do Editor > Export > Windows; sem ele o jogo usa o ícone do projeto na janela.)

### macOS
O `.zip` gerado contém o `Returing.app` **não assinado**. O macOS vai avisar "desenvolvedor não identificado".
Para distribuir: num Mac, preencha `codesign/identity` (Developer ID), ligue `codesign/codesign` e `notarization/*`
no preset (Apple ID, senha de app e Team ID) — **isso fica pendente e só pode ser feito num Mac com conta Apple Developer**.

### Android
1. Instale **JDK 17** e o **Android SDK** (Android Studio ou `sdkmanager`: `platform-tools`, `build-tools;34.0.0`, `platforms;android-34`, `cmdline-tools`, `cmake;3.10.2.4988404`, NDK 28.1.13356709).
2. No Godot: **Editor > Configurações do Editor > Export > Android**: caminho do JDK (`java_sdk_path`) e do SDK (`android_sdk_path`) e o **keystore de debug** (`debug_keystore`; gere com `keytool -genkeypair -v -keystore debug.keystore -alias androiddebugkey -keyalg RSA -keysize 2048 -validity 10000 -storepass android -keypass android`).
3. APK debug: `./exportar.sh debug android`. Instalar: `adb install -r build/android/Returing.apk`.
4. **Release / Play Store (AAB):** crie um keystore de release **fora do repositório** e informe por variáveis de ambiente (nunca commite):
   `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER`, `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`.
   Para AAB instale o modelo de compilação (**Projeto > Instalar modelo de compilação Android**, cria `android/build/`, que está no `.gitignore`).
* Orientação: paisagem com sensor (`window/handheld/orientation=4`), arm64 apenas, tela imersiva.
* O acelerômetro não exige permissão no Android (taxa padrão de jogo, ~50 Hz).

### iOS
Só em um **Mac com Xcode** e, para rodar em aparelho, uma **conta de desenvolvedor Apple**:
1. Godot 4.7.2 + templates no Mac. Preencha `application/app_store_team_id` no preset (Team ID) e confira `application/bundle_identifier` (`com.returing.game`).
2. `./exportar.sh debug ios` gera `build/ios/Returing.xcodeproj` (o preset exporta só o projeto Xcode).
3. Abra no Xcode, escolha o aparelho/assinatura (Signing & Capabilities) e rode, ou faça Archive para o TestFlight.
* Sensores: o acelerômetro (CoreMotion) **não exige** `NSMotionUsageDescription`, mas o preset já inclui um texto de uso de movimento em `application/additional_plist_content` (inofensivo, e evita surpresa se a Apple pedir).
* iPhone e iPad (`targeted_device_family=2`), paisagem com sensor, ícone 1024x1024 e tela de abertura gerados em `assets/gerados/`.

### Navegador (extra, para iPhone sem Mac)
`./exportar.sh debug web` e hospede `build/web/` (HTTPS) — veja `MOBILE.md`.

## 3. Testar no computador como se fosse celular
```
godot --path . -- --mobile          # o mouse vira o dedo; I/J/K/L inclinam o "celular"
godot --path . -- --mobile --debug-tilt   # mostra o overlay com os valores do acelerômetro
godot --path . -- --mobile --platform=ios --landscape-reverse   # simula iOS e paisagem invertida
```

## 4. Conferir antes de exportar
```
godot --headless --path . --script res://testes/rodar_todos.gd   # suíte completa (código de saída != 0 se algo falhar)
python3 tools/gerar_assets.py                                    # regenera os assets/ícones (determinístico)
```

## 5. O que fica pendente (precisa de você)
* **macOS:** assinatura e notarização (Mac + conta Apple Developer).
* **iOS:** exportar e assinar (Mac + Xcode + conta Apple Developer).
* **Android release:** keystore de release (sua chave, fora do repositório).
* **Testar o acelerômetro num celular real** (Android e iPhone): veja `RELATORIO.md`.
