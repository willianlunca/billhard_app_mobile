
#!/usr/bin/env bash

set -euo pipefail

# ==============================================
# BILLHARD - VERSIONAMENTO, BUILD E PUBLICAÇÃO
# ==============================================

REMOTE="origin"

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"

if [[ -z "$REPO_ROOT" ]]; then
  echo "ERRO: Repositório Git não encontrado."
  exit 1
fi

cd "$REPO_ROOT"

PUBSPEC="$REPO_ROOT/pubspec.yaml"
DART_VERSION="$REPO_ROOT/lib/generated/git_version.dart"

if [[ ! -f "$PUBSPEC" ]]; then
  echo "ERRO: pubspec.yaml não encontrado."
  exit 1
fi

BRANCH="$(git symbolic-ref --quiet --short HEAD || true)"

if [[ -z "$BRANCH" ]]; then
  echo "ERRO: Nenhuma branch ativa."
  exit 1
fi

if ! git remote get-url "$REMOTE" >/dev/null 2>&1; then
  echo "ERRO: Remote origin não configurado."
  exit 1
fi

if [[ ! -r /dev/tty ]]; then
  echo "ERRO: Terminal interativo necessário."
  exit 1
fi


perguntar() {
  local variavel="$1"
  local mensagem="$2"
  local entrada_usuario

  read -r -p "$mensagem" entrada_usuario </dev/tty
  printf -v "$variavel" '%s' "$entrada_usuario"
}


confirmar() {
  local resposta
  perguntar resposta "$1 [y/N]: "

  case "$resposta" in
    y|Y|s|S|yes|YES|sim|SIM)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

validar_versao() {
  [[ "$1" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]
}

versao_maior() {
  local a1 a2 a3 b1 b2 b3

  IFS='.' read -r a1 a2 a3 <<< "$1"
  IFS='.' read -r b1 b2 b3 <<< "$2"

  if (( 10#$a1 > 10#$b1 )); then return 0; fi
  if (( 10#$a1 < 10#$b1 )); then return 1; fi

  if (( 10#$a2 > 10#$b2 )); then return 0; fi
  if (( 10#$a2 < 10#$b2 )); then return 1; fi

  (( 10#$a3 > 10#$b3 ))
}

echo ""
echo "=============================================="
echo " BILLHARD - VERSIONAMENTO E BUILD"
echo "=============================================="
echo " Branch: $BRANCH"
echo " Remote: $REMOTE"
echo ""

# ==============================================
# 1. ATUALIZAR TAGS
# ==============================================

echo "Consultando repositório remoto..."

git fetch "$REMOTE" --tags

if git show-ref --verify --quiet \
  "refs/remotes/$REMOTE/$BRANCH"; then

  if ! git merge-base --is-ancestor \
    "$REMOTE/$BRANCH" HEAD; then

    echo "ERRO: A branch remota possui commits pendentes."
    echo "Sincronize antes de continuar."
    exit 1
  fi
fi

# ==============================================
# 2. IDENTIFICAR ÚLTIMA VERSÃO
# ==============================================

ULTIMA_VERSAO=""
TAGS="$(git tag --list)"

while IFS= read -r TAG_EXISTENTE; do

  [[ -z "$TAG_EXISTENTE" ]] && continue

  CANDIDATA="${TAG_EXISTENTE#v}"

  if validar_versao "$CANDIDATA"; then

    if [[ -z "$ULTIMA_VERSAO" ]] ||
       versao_maior "$CANDIDATA" "$ULTIMA_VERSAO"; then

      ULTIMA_VERSAO="$CANDIDATA"
    fi
  fi

done <<< "$TAGS"

# ==============================================
# 3. ESCOLHER NOVA VERSÃO
# ==============================================

if [[ -z "$ULTIMA_VERSAO" ]]; then

  echo "Nenhuma tag encontrada."

  while true; do
    perguntar VERSAO \
      "Digite a primeira versão (ex: 1.0.0): "

    if validar_versao "$VERSAO"; then
      break
    fi

    echo "Formato inválido. Exemplo: 1.0.0"
  done

else

  IFS='.' read -r MAJOR MINOR PATCH \
    <<< "$ULTIMA_VERSAO"

  SUGESTAO="${MAJOR}.${MINOR}.$((10#$PATCH + 1))"

  echo ""
  echo "Última versão: $ULTIMA_VERSAO"
  echo "Próxima versão sugerida: $SUGESTAO"

  while true; do

    perguntar ENTRADA \
      "Nova versão [Enter = $SUGESTAO]: "

    VERSAO="${ENTRADA:-$SUGESTAO}"

    if ! validar_versao "$VERSAO"; then
      echo "Versão inválida."
      continue
    fi

    if ! versao_maior "$VERSAO" "$ULTIMA_VERSAO"; then
      echo "A versão deve ser maior que $ULTIMA_VERSAO."
      continue
    fi

    break
  done
fi

TAG="v$VERSAO"

# Mantém o padrão de tags sem prefixo v.
if [[ -n "$ULTIMA_VERSAO" ]] &&
   git show-ref --verify --quiet \
     "refs/tags/$ULTIMA_VERSAO"; then
  TAG="$VERSAO"
fi

if git show-ref --verify --quiet "refs/tags/v$VERSAO" ||
   git show-ref --verify --quiet "refs/tags/$VERSAO"; then

  echo "ERRO: Tag já existente."
  exit 1
fi

# ==============================================
# 4. INCREMENTAR BUILD NUMBER
# ==============================================

VERSAO_ATUAL="$(
  sed -nE \
    's/^version:[[:space:]]*([^[:space:]]+).*/\1/p' \
    "$PUBSPEC" |
    head -n 1
)"

if [[ -z "$VERSAO_ATUAL" ]]; then
  echo "ERRO: Campo version não encontrado."
  exit 1
fi

BUILD_ATUAL="${VERSAO_ATUAL##*+}"

if [[ "$VERSAO_ATUAL" != *"+"* ||
      ! "$BUILD_ATUAL" =~ ^[0-9]+$ ]]; then
  BUILD_ATUAL=0
fi

NOVO_BUILD=$((10#$BUILD_ATUAL + 1))
NOVA_VERSAO="${VERSAO}+${NOVO_BUILD}"

# ==============================================
# 5. ESCOLHER PLATAFORMAS
# ==============================================

echo ""
echo "=============================================="
echo " SELEÇÃO DE BUILDS"
echo "=============================================="

BUILD_IOS=false
BUILD_ANDROID=false

if confirmar "Gerar build iOS (.ipa)?"; then
  BUILD_IOS=true
fi

if confirmar "Gerar build Android (.aab)?"; then
  BUILD_ANDROID=true
fi

if [[ "$BUILD_IOS" == true ||
      "$BUILD_ANDROID" == true ]]; then

  if ! command -v flutter >/dev/null 2>&1; then
    echo "ERRO: Flutter não encontrado no PATH."
    exit 1
  fi
fi

if [[ "$BUILD_IOS" == true ]]; then

  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "ERRO: Build iOS requer macOS."
    exit 1
  fi

  if ! command -v xcodebuild >/dev/null 2>&1; then
    echo "ERRO: Xcode não encontrado."
    exit 1
  fi
fi

# ==============================================
# 6. SOLICITAR COMMIT
# ==============================================

echo ""
echo "=============================================="
echo " RESUMO DA PUBLICAÇÃO"
echo "=============================================="
echo " Versão:  $NOVA_VERSAO"
echo " Tag:     $TAG"
echo " Branch:  $BRANCH"
echo " iOS:     $BUILD_IOS"
echo " Android: $BUILD_ANDROID"
echo "=============================================="

while true; do

  perguntar MENSAGEM \
    "Mensagem do commit: "

  if [[ -n "${MENSAGEM//[[:space:]]/}" ]]; then
    break
  fi

  echo "Mensagem obrigatória."
done

echo ""
git status --short
echo ""

if ! confirmar "Confirmar operação?"; then
  echo "Operação cancelada."
  exit 0
fi

# ==============================================
# 7. ATUALIZAR PUBSPEC
# ==============================================

echo ""
echo "Atualizando pubspec.yaml..."

sed -i.bak -E \
  "s/^version:[[:space:]]*.*/version: ${NOVA_VERSAO}/" \
  "$PUBSPEC"

rm -f "${PUBSPEC}.bak"

# ==============================================
# 8. GERAR ARQUIVO DART
# ==============================================

mkdir -p "$(dirname "$DART_VERSION")"

DATA="$(date '+%d/%m/%Y %H:%M:%S')"

cat > "$DART_VERSION" <<EOF
// ARQUIVO GERADO AUTOMATICAMENTE.
// NÃO EDITAR MANUALMENTE.

class GitVersion {
  GitVersion._();

  static const String version = '$VERSAO';
  static const String build = '$NOVO_BUILD';
  static const String fullVersion = '$NOVA_VERSAO';
  static const String tag = '$TAG';
  static const String branch = '$BRANCH';
  static const String generatedAt = '$DATA';
}
EOF

# ==============================================
# 9. GERAR BUILDS
# ==============================================

if [[ "$BUILD_IOS" == true ||
      "$BUILD_ANDROID" == true ]]; then

  echo ""
  echo "Atualizando dependências Flutter..."

  flutter pub get
fi

if [[ "$BUILD_IOS" == true ]]; then

  echo ""
  echo "=============================================="
  echo " GERANDO BUILD IOS"
  echo "=============================================="

  flutter build ipa --release

  echo ""
  echo "Build iOS concluído."
  echo "Diretório: build/ios/ipa/"
fi

if [[ "$BUILD_ANDROID" == true ]]; then

  echo ""
  echo "=============================================="
  echo " GERANDO BUILD ANDROID"
  echo "=============================================="

  flutter build appbundle --release

  echo ""
  echo "Build Android concluído."
  echo "Diretório: build/app/outputs/bundle/release/"
fi

# ==============================================
# 10. GIT ADD E COMMIT
# ==============================================

echo ""
echo "Adicionando alterações ao Git..."

git add .

if git diff --cached --quiet; then
  echo "ERRO: Nenhuma alteração para commit."
  exit 1
fi

echo "Criando commit..."

git commit -m "$MENSAGEM"

COMMIT="$(git rev-parse --short HEAD)"

# ==============================================
# 11. CRIAR TAG
# ==============================================

echo ""
echo "Criando tag $TAG..."

git tag -a "$TAG" \
  -m "Billhard versão $VERSAO"

# ==============================================
# 12. ENVIAR PARA GIT REMOTO
# ==============================================

echo ""
echo "Enviando commit e tag para $REMOTE..."

if ! git push --atomic "$REMOTE" \
  "HEAD:refs/heads/$BRANCH" \
  "refs/tags/$TAG:refs/tags/$TAG"; then

  echo ""
  echo "ERRO: Falha no envio ao Git."
  echo "Commit e tag permanecem salvos localmente."
  echo ""
  echo "Para tentar novamente:"
  echo "git push --atomic $REMOTE HEAD:refs/heads/$BRANCH refs/tags/$TAG:refs/tags/$TAG"

  exit 1
fi

# ==============================================
# 13. RESULTADO
# ==============================================

echo ""
echo "=============================================="
echo " BILLHARD - PUBLICAÇÃO CONCLUÍDA"
echo "=============================================="
echo " Versão:        $VERSAO"
echo " Build:         $NOVO_BUILD"
echo " Versão Flutter:$NOVA_VERSAO"
echo " Tag:           $TAG"
echo " Commit:        $COMMIT"
echo " Branch:        $BRANCH"
echo "=============================================="

if [[ "$BUILD_IOS" == true ]]; then
  echo " iOS:     build/ios/ipa/"
fi

if [[ "$BUILD_ANDROID" == true ]]; then
  echo " Android: build/app/outputs/bundle/release/"
fi

echo ""
echo "Projeto publicado com sucesso!"
echo ""
