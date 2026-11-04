
#!/usr/bin/env bash

set -euo pipefail

# ==============================================
# BILLHARD - VERSIONAMENTO E PUBLICAÇÃO GIT
# ==============================================

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"

if [[ -z "$REPO_ROOT" ]]; then
  echo "ERRO: Execute dentro de um repositório Git."
  exit 1
fi

cd "$REPO_ROOT"

PUBSPEC="$REPO_ROOT/pubspec.yaml"
DART_VERSION="$REPO_ROOT/lib/generated/git_version.dart"

REMOTE="origin"

if [[ ! -f "$PUBSPEC" ]]; then
  echo "ERRO: pubspec.yaml não encontrado."
  exit 1
fi

if ! git remote get-url "$REMOTE" >/dev/null 2>&1; then
  echo "ERRO: Remote '$REMOTE' não configurado."
  exit 1
fi

BRANCH="$(git symbolic-ref --quiet --short HEAD || true)"

if [[ -z "$BRANCH" ]]; then
  echo "ERRO: HEAD desconectado. Selecione uma branch."
  exit 1
fi

# Entrada interativa pelo terminal.
if [[ ! -r /dev/tty || ! -w /dev/tty ]]; then
  echo "ERRO: É necessário um terminal interativo."
  exit 1
fi

perguntar() {
  local __variavel="$1"
  local __mensagem="$2"
  local __resposta

  read -r -p "$__mensagem" __resposta </dev/tty
  printf -v "$__variavel" '%s' "$__resposta"
}

validar_versao() {
  [[ "$1" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]
}

echo ""
echo "=============================================="
echo " BILLHARD - PUBLICAÇÃO DE VERSÃO"
echo "=============================================="
echo " Branch: $BRANCH"
echo " Remote: $REMOTE"
echo ""

# ==============================================
# 1. SINCRONIZAR REFERÊNCIAS REMOTAS
# ==============================================

echo "Consultando tags remotas..."

if ! git fetch "$REMOTE" --tags; then
  echo "ERRO: Não foi possível consultar o remoto."
  exit 1
fi

# Impede publicação sobre uma branch desatualizada.
if git show-ref --verify --quiet "refs/remotes/$REMOTE/$BRANCH"; then
  if ! git merge-base --is-ancestor \
    "$REMOTE/$BRANCH" HEAD; then
    echo ""
    echo "ERRO: A branch remota contém commits"
    echo "que não estão na branch local."
    echo "Sincronize a branch antes de publicar."
    exit 1
  fi
fi

# ==============================================
# 2. IDENTIFICAR A MAIOR VERSÃO EXISTENTE
# ==============================================


# Identifica a maior versão das tags existentes.
# Compatível com o Bash padrão do macOS.

ULTIMA_VERSAO=""

TAGS="$(git tag --list)"

while IFS= read -r TAG_EXISTENTE; do

  [[ -z "$TAG_EXISTENTE" ]] && continue

  CANDIDATA="${TAG_EXISTENTE#v}"

  if validar_versao "$CANDIDATA"; then

    if [[ -z "$ULTIMA_VERSAO" ]]; then
      ULTIMA_VERSAO="$CANDIDATA"
    else

      IFS='.' read -r A B C <<< "$CANDIDATA"
      IFS='.' read -r X Y Z <<< "$ULTIMA_VERSAO"

      if (( 10#$A > 10#$X )) ||
         (( 10#$A == 10#$X && 10#$B > 10#$Y )) ||
         (( 10#$A == 10#$X && 10#$B == 10#$Y && 10#$C > 10#$Z )); then
        ULTIMA_VERSAO="$CANDIDATA"
      fi

    fi

  fi

done <<< "$TAGS"


# ==============================================
# 3. DEFINIR A NOVA VERSÃO
# ==============================================

if [[ -z "$ULTIMA_VERSAO" ]]; then

  echo ""
  echo "Nenhuma tag de versão foi encontrada."
  echo ""

  while true; do
    perguntar VERSAO \
      "Digite a primeira versão (ex: 1.0.0): "

    if validar_versao "$VERSAO"; then
      break
    fi

    echo "Versão inválida. Use MAJOR.MINOR.PATCH."
  done

else

  IFS='.' read -r MAJOR MINOR PATCH \
    <<< "$ULTIMA_VERSAO"

  PROXIMO_PATCH=$((10#$PATCH + 1))

  SUGESTAO="${MAJOR}.${MINOR}.${PROXIMO_PATCH}"

  echo ""
  echo "Última versão: $ULTIMA_VERSAO"
  echo "Próxima versão sugerida: $SUGESTAO"
  echo ""

  while true; do
    perguntar ENTRADA \
      "Nova versão [Enter = $SUGESTAO]: "

    VERSAO="${ENTRADA:-$SUGESTAO}"

    if ! validar_versao "$VERSAO"; then
      echo "Versão inválida."
      continue
    fi

    MAIOR="$(
      printf '%s\n%s\n' \
        "$ULTIMA_VERSAO" "$VERSAO" |
        sort -V |
        tail -n 1
    )"

    if [[ "$VERSAO" == "$ULTIMA_VERSAO" ||
          "$MAIOR" != "$VERSAO" ]]; then
      echo "A nova versão deve ser maior que $ULTIMA_VERSAO."
      continue
    fi

    break
  done

fi

# Mantém o padrão das tags existentes.
# Para o primeiro lançamento, usa prefixo v.
TAG="v$VERSAO"

if [[ -n "$ULTIMA_VERSAO" ]]; then
  if git rev-parse -q --verify \
    "refs/tags/$ULTIMA_VERSAO" >/dev/null; then
    TAG="$VERSAO"
  fi
fi

# Evita tags duplicadas com ou sem prefixo.
if git rev-parse -q --verify \
  "refs/tags/$VERSAO" >/dev/null ||
   git rev-parse -q --verify \
  "refs/tags/v$VERSAO" >/dev/null; then
  echo "ERRO: Já existe uma tag para $VERSAO."
  exit 1
fi

# ==============================================
# 4. DEFINIR BUILD DO FLUTTER
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

# Incrementa o build a cada publicação.
NOVO_BUILD=$((10#$BUILD_ATUAL + 1))

NOVA_VERSAO="${VERSAO}+${NOVO_BUILD}"

# ==============================================
# 5. SOLICITAR MENSAGEM DO COMMIT
# ==============================================

echo ""
echo "----------------------------------------------"
echo " Nova tag:       $TAG"
echo " Versão Flutter: $NOVA_VERSAO"
echo " Branch:         $BRANCH"
echo "----------------------------------------------"
echo ""

while true; do
  perguntar MENSAGEM \
    "Digite a mensagem do commit: "

  if [[ -n "${MENSAGEM//[[:space:]]/}" ]]; then
    break
  fi

  echo "A mensagem não pode estar vazia."
done

echo ""
git status --short

echo ""
perguntar CONFIRMAR \
  "Confirmar commit, tag e push? [s/N]: "

case "$CONFIRMAR" in
  s|S|sim|SIM|Sim)
    ;;
  *)
    echo "Operação cancelada."
    exit 0
    ;;
esac

# ==============================================
# 6. ATUALIZAR PUBSPEC.YAML
# ==============================================

echo ""
echo "Atualizando pubspec.yaml..."

sed -i.bak -E \
  "s/^version:[[:space:]]*.*/version: ${NOVA_VERSAO}/" \
  "$PUBSPEC"

rm -f "${PUBSPEC}.bak"

# ==============================================
# 7. GERAR INFORMAÇÕES DART
# ==============================================

echo "Gerando git_version.dart..."

mkdir -p "$(dirname "$DART_VERSION")"

DATA="$(date '+%d/%m/%Y %H:%M:%S')"

# O commit é identificado em tempo de execução.
# Assim não é gravado um hash anterior ao commit.
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
# 8. ADICIONAR E CRIAR COMMIT
# ==============================================

echo ""
echo "Adicionando arquivos ao Git..."

git add .

if git diff --cached --quiet; then
  echo "ERRO: Nenhuma alteração para commit."
  exit 1
fi

echo "Criando commit..."

git commit -m "$MENSAGEM"

COMMIT="$(git rev-parse --short HEAD)"

# ==============================================
# 9. CRIAR TAG ANOTADA
# ==============================================

echo ""
echo "Criando tag $TAG..."

git tag -a "$TAG" \
  -m "Billhard versão $VERSAO"

# ==============================================
# 10. ENVIAR BRANCH E TAG AO REMOTO
# ==============================================

echo ""
echo "Enviando branch e tag para $REMOTE..."

# Push atômico: quando suportado pelo servidor,
# branch e tag são atualizadas juntas.
if ! git push --atomic "$REMOTE" \
  "HEAD:refs/heads/$BRANCH" \
  "refs/tags/$TAG:refs/tags/$TAG"; then

  echo ""
  echo "ERRO: O push não foi concluído."
  echo "O commit e a tag continuam salvos localmente."
  echo ""
  echo "Depois de resolver o problema, execute:"
  echo "git push --atomic $REMOTE HEAD:refs/heads/$BRANCH refs/tags/$TAG:refs/tags/$TAG"
  exit 1
fi

# ==============================================
# 11. RESULTADO
# ==============================================

echo ""
echo "=============================================="
echo " BILLHARD - PUBLICAÇÃO CONCLUÍDA"
echo "=============================================="
echo " Versão:        $VERSAO"
echo " Build:         $NOVO_BUILD"
echo " Flutter:       $NOVA_VERSAO"
echo " Tag:           $TAG"
echo " Commit:        $COMMIT"
echo " Branch:        $BRANCH"
echo " Remote:        $REMOTE"
echo "=============================================="
echo ""
echo "Projeto publicado com sucesso!"
echo ""
