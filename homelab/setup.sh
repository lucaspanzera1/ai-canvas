#!/usr/bin/env bash
# Setup script para Ubuntu Server
# Execute como root: sudo bash setup.sh
set -euo pipefail

APP_DIR="/opt/aicanvas-sync"
DATA_DIR="/var/aicanvas/data"
SERVICE_USER="aicanvas"

echo "==> Criando usuário de serviço: $SERVICE_USER"
id "$SERVICE_USER" &>/dev/null || useradd --system --no-create-home --shell /usr/sbin/nologin "$SERVICE_USER"

echo "==> Criando diretórios"
mkdir -p "$APP_DIR" "$DATA_DIR/drawings" "$DATA_DIR/pdfs"
chown -R "$SERVICE_USER:$SERVICE_USER" "$DATA_DIR"

echo "==> Copiando arquivos do servidor"
cp main.py requirements.txt "$APP_DIR/"

echo "==> Criando virtualenv e instalando dependências"
python3 -m venv "$APP_DIR/venv"
"$APP_DIR/venv/bin/pip" install --quiet --upgrade pip
"$APP_DIR/venv/bin/pip" install --quiet -r "$APP_DIR/requirements.txt"

echo "==> Gerando API key"
API_KEY=$(python3 -c "import secrets; print(secrets.token_hex(32))")
echo ""
echo "  *** SALVE ESTA CHAVE — ela será configurada no app iOS ***"
echo "  API_KEY: $API_KEY"
echo ""

echo "==> Configuração do Notion (Enter para pular)"
echo "  Crie uma integration em: https://www.notion.so/my-integrations"
read -rsp "  NOTION_TOKEN (secret_xxx): " NOTION_TOKEN
echo ""
echo "  Copie o ID do database na URL: notion.so/<workspace>/<DATABASE_ID>?v=..."
read -rp  "  NOTION_DATABASE_ID: " NOTION_DATABASE_ID
echo ""

echo "==> Instalando serviço systemd"
sed \
  -e "s|COLOQUE_SUA_CHAVE_AQUI|$API_KEY|" \
  -e "s|NOTION_TOKEN=|NOTION_TOKEN=$NOTION_TOKEN|" \
  -e "s|NOTION_DATABASE_ID=|NOTION_DATABASE_ID=$NOTION_DATABASE_ID|" \
  aicanvas-sync.service > /etc/systemd/system/aicanvas-sync.service
systemctl daemon-reload
systemctl enable aicanvas-sync
systemctl start aicanvas-sync

echo ""
echo "==> Concluído! Status:"
systemctl status aicanvas-sync --no-pager

echo ""
echo "Próximo passo: configure o Cloudflare Tunnel para apontar"
echo "  sync.seudominio.com → http://127.0.0.1:8765"
if [[ -n "$NOTION_TOKEN" && -n "$NOTION_DATABASE_ID" ]]; then
  echo ""
  echo "  Notion configurado — lembre de compartilhar o database com a integration."
else
  echo ""
  echo "  Para ativar o Notion depois: edite /etc/systemd/system/aicanvas-sync.service,"
  echo "  preencha NOTION_TOKEN e NOTION_DATABASE_ID, e rode:"
  echo "    systemctl daemon-reload && systemctl restart aicanvas-sync"
fi
