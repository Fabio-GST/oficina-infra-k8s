#!/usr/bin/env bash
# Renova as credenciais temporárias do AWS Academy Learner Lab nos secrets dos
# 4 repositórios do projeto. Rode logo após "Start Lab", com o bloco de
# credenciais do painel "AWS Details" colado em ~/.aws/credentials
# (perfil [default]).
#
# Uso: ./scripts/atualizar-credenciais-aws.sh [perfil]
set -euo pipefail

PERFIL="${1:-default}"
REPOS=(
  Fabio-GST/oficina-auth-lambda
  Fabio-GST/oficina-infra-k8s
  Fabio-GST/oficina-infra-db
  Fabio-GST/oficina-api
)

ler() { aws configure get "$1" --profile "$PERFIL"; }

ACCESS_KEY="$(ler aws_access_key_id)"
SECRET_KEY="$(ler aws_secret_access_key)"
SESSION_TOKEN="$(ler aws_session_token)"

if [[ -z "$ACCESS_KEY" || -z "$SECRET_KEY" || -z "$SESSION_TOKEN" ]]; then
  echo "Perfil '$PERFIL' sem access key, secret ou session token. Cole o bloco do lab em ~/.aws/credentials." >&2
  exit 1
fi

echo "Validando sessão do lab..."
aws sts get-caller-identity --profile "$PERFIL" --query Arn --output text

for repo in "${REPOS[@]}"; do
  echo "→ $repo"
  gh secret set AWS_ACCESS_KEY_ID     --repo "$repo" --body "$ACCESS_KEY"
  gh secret set AWS_SECRET_ACCESS_KEY --repo "$repo" --body "$SECRET_KEY"
  gh secret set AWS_SESSION_TOKEN     --repo "$repo" --body "$SESSION_TOKEN"
done

echo "Credenciais atualizadas em ${#REPOS[@]} repositórios. Elas expiram quando a sessão do lab terminar."
