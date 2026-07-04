#!/usr/bin/env bash
# Sobe o projeto para o GitHub (repositório EVPV-2026).
#
# Pré-requisitos:
#   - git instalado e autenticado (GitHub CLI `gh auth login`, ou o
#     credential manager do Git pedindo login no push).
#   - Criar o repositório VAZIO antes: https://github.com/new
#         Repository name: EVPV-2026   (NÃO marque "Add a README")
#
# Uso (na raiz do projeto):
#   bash scripts/init_and_push.sh SEU_USUARIO_GITHUB
#
# O .gitignore já impede que .env / segredos subam.

set -euo pipefail
GH_USER="${1:?uso: bash scripts/init_and_push.sh SEU_USUARIO_GITHUB}"

git init -b main
git add .
git status --short
git commit -m "Eles Votam Por Voce - backend inicial (ingestao, scores, API, infra)"
git remote add origin "https://github.com/${GH_USER}/EVPV-2026.git"
git push -u origin main

echo ""
echo "OK - codigo no GitHub. Agora:"
echo "  1) Settings > Secrets and variables > Actions > New secret"
echo "     Nome: DATABASE_URL  | Valor: string do POOLER do Supabase (+ ?sslmode=require)"
echo "  2) Actions > 'Ingestao diaria' > Run workflow (informe start/end)"
