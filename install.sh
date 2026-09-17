#!/usr/bin/env bash
# ============================================================================
# LLM Explorer — interactive installer (Ubuntu 24.04 / DGX Spark aarch64)
# ============================================================================
set -uo pipefail

# ─── Colours / helpers ─────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'
CHECK="${GREEN}✔${NC}"; CROSS="${RED}✘${NC}"; WARN="${YELLOW}⚠${NC}"

info()  { echo -e "${CYAN}▸${NC} $*"; }
ok()    { echo -e "${CHECK} $*"; }
warn()  { echo -e "${WARN} $*"; }
fail()  { echo -e "${CROSS} $*"; }
hr()    { echo -e "${DIM}$(printf '─%.0s' {1..60})${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
LOG="$SCRIPT_DIR/install.log"
echo "=== LLM Explorer install $(date) ===" > "$LOG"

run_logged() { "$@" >> "$LOG" 2>&1; }

clear
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║     LLM Explorer — one-shot install              ║${NC}"
echo -e "${BOLD}║     Ubuntu 24.04 · DGX Spark · aarch64           ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════╝${NC}"
echo ""

# ─── Menu helper ───────────────────────────────────────────────
# toggle_menu "title" items[@] selected[@] → updates the selected array
toggle_menu() {
  local title="$1"
  local -n _items=$2
  local -n _sel=$3
  local cur=0 count=${#_items[@]}

  while true; do
    # Clear the previous render (count+3 lines: title + items + hint)
    # Clear the previous render (count+3 lines: title + items + hint)
    if [[ $cur -ge 0 ]]; then
      tput cuu $((count + 3)) 2>/dev/null || true
      tput ed 2>/dev/null || true
    fi
    echo -e "\n${BOLD}${title}${NC}  ${DIM}(↑↓ move · Space select · Enter start — multi-select)${NC}"
    for i in "${!_items[@]}"; do
      local marker="  "
      [[ "${_sel[$i]}" == "1" ]] && marker="${GREEN}● ${NC}" || marker="${DIM}○ ${NC}"
      if [[ $i -eq $cur ]]; then
        echo -e "  ${BOLD}▸ ${marker}${_items[$i]}${NC}"
      else
        echo -e "    ${marker}${_items[$i]}"
      fi
    done
    echo -e "${DIM}  ──────────────────────────────────${NC}"

    IFS= read -rsn1 key
    case "$key" in
      $'\x1b')
        read -rsn2 rest
        case "$rest" in
          '[A') ((cur > 0)) && ((cur--)) ;;
          '[B') ((cur < count - 1)) && ((cur++)) ;;
        esac ;;
      ' ') [[ "${_sel[$cur]}" == "1" ]] && _sel[$cur]=0 || _sel[$cur]=1 ;;
      '') break ;;
    esac
  done
}

# ─── Menu: what to install ─────────────────────────────────────
items=(
  "System bootstrap (packages, Docker, CUDA checks)"
  "ComfyUI environment (venv + PyTorch cu130)"
  "Video models (LTX-2.5 / MiniMax H3 / Wan 2.2)"
  "Image models (Flux.2 Klein / Qwen-Image / Z-Image Turbo)"
  "Start ComfyUI + the comparison tool"
  "Chatbot (Open WebUI + Ollama + LLMs)"
)
selected=(0 0 0 0 0 0)   # nothing selected by default — use Space to pick

# Reserve screen space
for _ in "${!items[@]}"; do echo; done; echo; echo; echo

toggle_menu "Select what to install:" items selected

echo ""
hr

DO_SYSTEM=${selected[0]}
DO_COMFYUI=${selected[1]}
DO_VIDEO=${selected[2]}
DO_IMAGE=${selected[3]}
DO_START=${selected[4]}
DO_CHATBOT=${selected[5]}

# Nothing selected → exit
if [[ "$DO_SYSTEM$DO_COMFYUI$DO_VIDEO$DO_IMAGE$DO_START$DO_CHATBOT" == "000000" ]]; then
  warn "Nothing selected, exiting."
  exit 0
fi

# Models selected without the environment → enable the environment automatically
if [[ "$DO_VIDEO" == "1" || "$DO_IMAGE" == "1" ]] && [[ "$DO_COMFYUI" == "0" ]]; then
  if [[ ! -d "comfyui/ComfyUI" ]]; then
    warn "Model downloads need the ComfyUI environment — enabling it"
    DO_COMFYUI=1
  fi
fi

STEP=0
count_steps() {
  local total=0
  [[ "$DO_SYSTEM"  == "1" ]] && ((total++))
  [[ "$DO_COMFYUI" == "1" ]] && ((total++))
  [[ "$DO_VIDEO" == "1" || "$DO_IMAGE" == "1" ]] && ((total++))  # HF login
  [[ "$DO_VIDEO"   == "1" ]] && ((total++))
  [[ "$DO_IMAGE"   == "1" ]] && ((total++))
  [[ "$DO_START"   == "1" ]] && ((total++))
  [[ "$DO_CHATBOT" == "1" ]] && ((total++))
  echo $total
}
TOTAL=$(count_steps)
step() { ((STEP++)); echo ""; echo -e "${BOLD}[$STEP/$TOTAL] $1${NC}"; hr; }

# ═══════════════════════════════════════════════════════════════
# System bootstrap
# ═══════════════════════════════════════════════════════════════
if [[ "$DO_SYSTEM" == "1" ]]; then
  step "System bootstrap"

  ARCH=$(uname -m)
  if [[ "$ARCH" == "aarch64" ]]; then
    ok "Architecture: $ARCH"
  else
    warn "Architecture: $ARCH (expected aarch64; some packages may not work)"
  fi

  # ── Ubuntu version ──
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    ok "OS: $PRETTY_NAME"
  fi

  # ── CUDA ──
  if command -v nvcc &>/dev/null; then
    CUDA_VER=$(nvcc --version 2>/dev/null | grep -oP 'release \K[0-9.]+')
    if [[ "$CUDA_VER" == 13.* ]]; then
      ok "CUDA $CUDA_VER (sm_121 compatible)"
    else
      warn "CUDA $CUDA_VER — Blackwell sm_121 needs CUDA 13.0+; some features will not work"
    fi
  else
    fail "nvcc not found — check the CUDA Toolkit is installed and on PATH"
    echo "     export PATH=/usr/local/cuda/bin:\$PATH"
  fi

  # ── nvidia-smi ──
  if command -v nvidia-smi &>/dev/null; then
    GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
    DRIVER=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1)
    MEM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader 2>/dev/null | head -1)
    ok "GPU: $GPU_NAME · Driver $DRIVER · $MEM"
  else
    fail "nvidia-smi not found"
  fi

  TOTAL_MEM=$(free -g | awk '/^Mem:/{print $2}')
  ok "Memory: ${TOTAL_MEM}GB"

  DISK_AVAIL=$(df -BG "$SCRIPT_DIR" | awk 'NR==2{print $4}')
  ok "Free disk space: $DISK_AVAIL"
  DISK_NUM=${DISK_AVAIL//[^0-9]/}
  if [[ "$DISK_NUM" -lt 100 ]]; then
    warn "Low disk space — model downloads need ~200GB+"
  fi

  # ── System packages ──
  info "Installing required packages..."
  PKGS=(python3-dev python3-venv build-essential git curl wget)
  NEED=()
  for p in "${PKGS[@]}"; do
    dpkg -s "$p" &>/dev/null || NEED+=("$p")
  done
  if [[ ${#NEED[@]} -eq 0 ]]; then
    ok "All system packages present"
  else
    info "Installing missing packages: ${NEED[*]}"
    sudo apt-get update -qq >> "$LOG" 2>&1
    sudo apt-get install -y "${NEED[@]}" >> "$LOG" 2>&1
    ok "Packages installed"
  fi

  # ── Docker ──
  if command -v docker &>/dev/null; then
    DOCKER_VER=$(docker --version 2>/dev/null | grep -oP '[0-9]+\.[0-9]+\.[0-9]+')
    if docker ps &>/dev/null; then
      ok "Docker $DOCKER_VER (usable)"
    else
      warn "Docker $DOCKER_VER installed but permissions are missing"
      info "Adding you to the docker group..."
      sudo usermod -aG docker "$USER"
      warn "Added to the docker group — log out and back in afterwards (or newgrp docker)"
    fi
  else
    warn "Docker is not installed"
    echo ""
    read -rp "  Install Docker automatically? [Y/n] " yn
    case "$yn" in
      [nN]*) warn "Skipping Docker (the chatbot will be unavailable)" ;;
      *)
        info "Installing Docker..."
        curl -fsSL https://get.docker.com | sudo sh >> "$LOG" 2>&1
        sudo usermod -aG docker "$USER"
        ok "Docker installed — log out and back in when the installer finishes"
        ;;
    esac
  fi

  # ── nvidia-container-toolkit ──
  if dpkg -s nvidia-container-toolkit &>/dev/null; then
    ok "nvidia-container-toolkit installed"
  else
    warn "nvidia-container-toolkit missing (needed for GPU support in Docker)"
    echo ""
    read -rp "  Install it automatically? [Y/n] " yn
    case "$yn" in
      [nN]*) warn "Skipped — containers will have no GPU access" ;;
      *)
        info "Installing nvidia-container-toolkit..."
        curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
          sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg 2>/dev/null
        curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
          sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
          sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list > /dev/null
        sudo apt-get update -qq >> "$LOG" 2>&1
        sudo apt-get install -y nvidia-container-toolkit >> "$LOG" 2>&1
        sudo nvidia-ctk runtime configure --runtime=docker >> "$LOG" 2>&1
        sudo systemctl restart docker >> "$LOG" 2>&1 || true
        ok "nvidia-container-toolkit installed"
        ;;
    esac
  fi

  echo ""
  ok "System bootstrap complete"
fi

# ═══════════════════════════════════════════════════════════════
# ComfyUI environment
# ═══════════════════════════════════════════════════════════════
if [[ "$DO_COMFYUI" == "1" ]]; then
  step "ComfyUI environment"
  if [[ -d "comfyui/ComfyUI" && -d "comfyui/comfyui-env" ]]; then
    ok "ComfyUI environment already exists, skipping"
  else
    info "Creating venv + installing cu130 PyTorch + ComfyUI + Manager..."
    cd comfyui
    bash setup.sh 2>&1 | tee -a "$LOG"
    cd "$SCRIPT_DIR"
    ok "ComfyUI environment ready"
  fi
fi

# ═══════════════════════════════════════════════════════════════
# HuggingFace login
# ═══════════════════════════════════════════════════════════════
if [[ "$DO_VIDEO" == "1" || "$DO_IMAGE" == "1" ]]; then
  step "HuggingFace login check"
  HF="$SCRIPT_DIR/comfyui/comfyui-env/bin/hf"
  if [[ ! -x "$HF" ]]; then
    info "Installing the HuggingFace CLI..."
    "$SCRIPT_DIR/comfyui/comfyui-env/bin/pip" install -U "huggingface_hub[cli]" -q >> "$LOG" 2>&1
  fi
  if "$HF" auth status &>/dev/null 2>&1; then
    ok "HuggingFace: logged in"
  else
    warn "HuggingFace: not logged in"
    echo ""
    echo "  LTX-2.5 is a gated repo: you must log in and accept its licence."
    echo "  LTX-2.5 is a gated repo: you must log in and accept its licence."
    echo "  1. Run: $HF auth login"
    echo "  2. Accept the licence at https://huggingface.co/Lightricks/LTX-2.5"
    echo ""
    read -rp "  Press Enter to continue (gated models will fail without a login; others are fine)... "
  fi
fi

# ═══════════════════════════════════════════════════════════════
# Video models
# ═══════════════════════════════════════════════════════════════
if [[ "$DO_VIDEO" == "1" ]]; then
  step "Download video models"

  vid_items=("LTX-2.5 (Lightricks, 22B int8)" "MiniMax H3 (Hailuo 3.0, int8)" "Wan 2.2 (14B fp8)")
  vid_sel=(1 1 1)
  for _ in "${!vid_items[@]}"; do echo; done; echo; echo; echo
  toggle_menu "Select video models to download:" vid_items vid_sel

  [[ "${vid_sel[0]}" == "1" ]] && { info "Downloading LTX-2.5..."; cd comfyui; bash download-models.sh ltx 2>&1 | tee -a "$LOG"; cd "$SCRIPT_DIR"; }
  [[ "${vid_sel[1]}" == "1" ]] && { info "Downloading MiniMax H3..."; cd comfyui; bash download-models.sh h3 2>&1 | tee -a "$LOG"; cd "$SCRIPT_DIR"; }
  [[ "${vid_sel[2]}" == "1" ]] && { info "Downloading Wan 2.2..."; cd comfyui; bash download-models.sh wan 2>&1 | tee -a "$LOG"; cd "$SCRIPT_DIR"; }
  ok "Video model downloads finished"
fi

# ═══════════════════════════════════════════════════════════════
# Image models
# ═══════════════════════════════════════════════════════════════
if [[ "$DO_IMAGE" == "1" ]]; then
  step "Download image models"

  img_items=("Flux.2 Klein (9B fp8)" "Qwen-Image-2512 (bf16)" "Z-Image Turbo (6B bf16)")
  img_sel=(1 1 1)
  for _ in "${!img_items[@]}"; do echo; done; echo; echo; echo
  toggle_menu "Select image models to download:" img_items img_sel

  [[ "${img_sel[0]}" == "1" ]] && { info "Downloading Flux.2 Klein..."; cd comfyui; bash download-models.sh flux2 2>&1 | tee -a "$LOG"; cd "$SCRIPT_DIR"; }
  [[ "${img_sel[1]}" == "1" ]] && { info "Downloading Qwen-Image-2512..."; cd comfyui; bash download-models.sh qwen 2>&1 | tee -a "$LOG"; cd "$SCRIPT_DIR"; }
  [[ "${img_sel[2]}" == "1" ]] && { info "Downloading Z-Image Turbo..."; cd comfyui; bash download-models.sh zimage 2>&1 | tee -a "$LOG"; cd "$SCRIPT_DIR"; }
  ok "Image model downloads finished"
fi

# ═══════════════════════════════════════════════════════════════
# Start services
# ═══════════════════════════════════════════════════════════════
if [[ "$DO_START" == "1" ]]; then
  step "Start ComfyUI + the comparison tool"

  info "Starting ComfyUI..."
  cd comfyui; bash start.sh; cd "$SCRIPT_DIR"

  info "Waiting for ComfyUI to come up..."
  for i in $(seq 1 30); do
    if curl -s -o /dev/null http://localhost:8188 2>/dev/null; then
      ok "ComfyUI → http://localhost:8188"
      break
    fi
    [[ $i -eq 30 ]] && warn "ComfyUI start timed out — check comfyui/comfyui.log"
    sleep 2
  done

  info "Starting the comparison tool..."
  cd compare; bash start.sh; cd "$SCRIPT_DIR"
  ok "Comparison tool → http://localhost:8890"

  # Open the browser automatically
  open_url() {
    local url="$1"
    if command -v xdg-open &>/dev/null; then xdg-open "$url" >/dev/null 2>&1 &
    elif command -v gio &>/dev/null; then gio open "$url" >/dev/null 2>&1 &
    elif command -v sensible-browser &>/dev/null; then sensible-browser "$url" >/dev/null 2>&1 &
    else warn "No browser opener found — open it manually: $url"; return 1; fi
  }
  info "Opening the browser..."
  open_url "http://localhost:8188" && ok "Opened ComfyUI"
  open_url "http://localhost:8890" && ok "Opened the comparison tool"
fi

# ═══════════════════════════════════════════════════════════════
# Chatbot
# ═══════════════════════════════════════════════════════════════
if [[ "$DO_CHATBOT" == "1" ]]; then
  step "Chatbot (Open WebUI + Ollama)"

  if ! docker ps &>/dev/null; then
    fail "Docker is unavailable. Log out and back in, then run manually:"
    echo "    cd chatbot && ./start.sh && ./pull-models.sh"
  else
    info "Starting Open WebUI + Ollama..."
    cd chatbot; bash start.sh 2>&1 | tee -a "$LOG"; cd "$SCRIPT_DIR"

    echo ""
    # Read the list from chatbot/models.txt rather than hard-coding it here, so the
    # menu never goes stale. Uncommented lines are pre-selected; a commented line whose
    # body is a valid tag counts as optional and starts unselected.
    # The list comes from chatbot/models.txt rather than being hard-coded here, so the
    # menu never goes stale. Uncommented lines start selected; a commented line whose
    # body is a valid tag counts as optional and starts unselected.
    MODELS_TXT="$SCRIPT_DIR/chatbot/models.txt"
    LLM_LIST=(); llm_items=(); llm_sel=()
    if [[ -f "$MODELS_TXT" ]]; then
      while IFS=$'\t' read -r tag desc sel; do
        [[ -z "$tag" ]] && continue
        LLM_LIST+=("$tag")
        llm_items+=("$tag$( [[ -n "$desc" ]] && echo "  — $desc" )")
        llm_sel+=("$sel")
      done < <(python3 - "$MODELS_TXT" <<'PYEOF'
import re, sys
with open(sys.argv[1]) as f:
    for line in f:
        s = line.strip()
        if not s:
            continue
        commented = s.startswith("#")
        body = s.lstrip("#").strip()
        if not body:
            continue
        m = re.match(r'^([A-Za-z0-9_.\-]+(?::[A-Za-z0-9_.\-]+)?)\s*(#.*)?$', body)
        if not m:
            continue  # a section-header comment (e.g. "--- daily chat ---") — skip
        tag = m.group(1)
        desc = body[len(tag):].strip().lstrip("#").strip()
        print(f"{tag}\t{desc}\t{'0' if commented else '1'}")
PYEOF
      )
    fi

    if [[ ${#LLM_LIST[@]} -eq 0 ]]; then
      warn "No valid entries in chatbot/models.txt — skipping LLM downloads"
    else
      for _ in "${!llm_items[@]}"; do echo; done; echo; echo; echo
      toggle_menu "Select LLMs to download (from chatbot/models.txt):" llm_items llm_sel

      for i in "${!LLM_LIST[@]}"; do
        if [[ "${llm_sel[$i]}" == "1" ]]; then
          info "Downloading ${LLM_LIST[$i]}..."
          docker exec open-webui ollama pull "${LLM_LIST[$i]}" 2>&1 | tee -a "$LOG"
        fi
      done
    fi
    ok "Chatbot → http://localhost:8080"
  fi
fi

# ═══════════════════════════════════════════════════════════════
# Finished
# ═══════════════════════════════════════════════════════════════
echo ""
hr
echo ""
echo -e "${GREEN}${BOLD}  ✔ Installation complete!${NC}"
echo ""
echo -e "  ${BOLD}Services${NC}"
echo "  ┌──────────────────┬───────────────────────────┐"
echo "  │ ComfyUI          │ http://localhost:8188     │"
echo "  │ Compare          │ http://localhost:8890     │"
echo "  │ Chatbot (WebUI)  │ http://localhost:8080     │"
echo "  └──────────────────┴───────────────────────────┘"
echo ""
echo -e "  ${BOLD}Common commands${NC}"
echo "  Start all: comfyui/start.sh && compare/start.sh && chatbot/start.sh"
echo "  Stop all:  comfyui/stop.sh && compare/stop.sh && chatbot/stop.sh"
echo ""
echo -e "  ${DIM}Full log: $LOG${NC}"
echo ""
