{ pkgs }:

pkgs.writeShellScriptBin "update-open-bsp-ui" ''
  #!${pkgs.bash}/bin/bash
  set -e

  ${pkgs.gum}/bin/gum style --border rounded --align center --margin "1" --padding "1 2" --foreground "#25D366" --border-foreground "#25D366" --bold "OpenBSP UI - WhatsApp & Instagram Web"

  APP_DIR="''${HOME}/open-bsp-ui"
  BRANCH="main"

  echo "🚀 Updating OpenBSP UI (Branch: $BRANCH -> $APP_DIR)..."

  if [ ! -d "$APP_DIR" ]; then
    echo "📁 Cloning open-bsp-ui ($BRANCH) into $APP_DIR..."
    git clone -b "$BRANCH" git@github.com:AlphaFintechMx/open-bsp-ui.git "$APP_DIR" || git clone git@github.com:AlphaFintechMx/open-bsp-ui.git "$APP_DIR"
  fi

  cd "$APP_DIR" || { echo "Directory $APP_DIR not found"; exit 1; }

  echo "📥 Pulling latest updates for branch $BRANCH..."
  git fetch origin
  git checkout "$BRANCH" || git checkout -b "$BRANCH" "origin/$BRANCH"
  git reset --hard "origin/$BRANCH" 2>/dev/null || git pull origin "$BRANCH"

  if [ ! -f .env ] && [ -f .env.example ]; then
    echo "⚙️ Initializing .env from .env.example..."
    cp .env.example .env
  fi

  echo "📦 Installing dependencies and building production frontend..."
  ${pkgs.nodejs}/bin/npm install
  ${pkgs.nodejs}/bin/npm run build

  chmod -R 755 "$APP_DIR/dist" 2>/dev/null || true

  echo "🌐 Reloading Nginx..."
  sudo systemctl reload nginx.service || true

  ${pkgs.toilet}/bin/toilet -t -f smmono12 "OpenBSP UI Updated" -F crop -F border -F metal
''
