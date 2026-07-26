#!/usr/bin/env bash

set -euo pipefail

# Sempre trabalha a partir da raiz do repositório.
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"

if [[ -z "$REPO_ROOT" ]]; then
  echo "Erro: execute este script dentro do repositório Git do projeto."
  exit 1
fi

cd "$REPO_ROOT"

# Atualiza as tags do remoto antes de descobrir a mais recente.
# Caso esteja sem internet, mantém as tags locais e continua.
if ! git fetch --tags --force --quiet; then
  echo "Aviso: não foi possível atualizar as tags remotas. Usando tags locais."
fi

# Obtém a tag mais recente alcançável pelo commit atual.
TAG="$(git describe --tags --abbrev=0 2>/dev/null || true)"

# Se a branch atual ainda não alcança nenhuma tag, usa a tag mais recente por data.
if [[ -z "$TAG" ]]; then
  TAG="$(git tag --sort=-creatordate | head -n 1)"
fi

if [[ -z "$TAG" ]]; then
  TAG="v0.0.0"
  echo "Aviso: nenhuma tag encontrada. Usando $TAG."
fi

OUTPUT_FILE="lib/generated/app_version.dart"
mkdir -p "$(dirname "$OUTPUT_FILE")"

cat > "$OUTPUT_FILE" <<EOF
// ARQUIVO GERADO AUTOMATICAMENTE.
// Não edite manualmente. Gerado por scripts/gerar_versao_git.sh.

const String appVersion = '$TAG';
EOF

echo "Versão gerada: $TAG"
echo "Arquivo atualizado: $OUTPUT_FILE"
