#!/usr/bin/env bash
# ============================================================================
# LLM Explorer — 互動式安裝腳本（Ubuntu 24.04 / DGX Spark aarch64）
# ============================================================================
set -uo pipefail

# ─── 顏色 / 工具 ────────────────────────────────────────────────
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

# ─── 標題 ───────────────────────────────────────────────────────
clear
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║     LLM Explorer — 一鍵安裝                     ║${NC}"
echo -e "${BOLD}║     Ubuntu 24.04 · DGX Spark · aarch64          ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════╝${NC}"
echo ""

# ─── 選單函式 ───────────────────────────────────────────────────
# toggle_menu "標題" items[@] selected[@]  → 修改 selected 陣列
toggle_menu() {
  local title="$1"
  local -n _items=$2
  local -n _sel=$3
  local cur=0 count=${#_items[@]}

  while true; do
    # 清除前一次輸出（count+3 行：標題 + items + 提示）
    if [[ $cur -ge 0 ]]; then
      tput cuu $((count + 3)) 2>/dev/null || true
      tput ed 2>/dev/null || true
    fi
    echo -e "\n${BOLD}${title}${NC}  ${DIM}(↑↓ 移動 · Space 勾選/取消 · Enter 開始 — 可複選)${NC}"
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

# ─── 選單：安裝項目 ─────────────────────────────────────────────
items=(
  "系統初始化（套件、Docker、CUDA 檢查）"
  "ComfyUI 環境（venv + PyTorch cu130）"
  "影片模型（LTX-2.5 / MiniMax H3 / Wan 2.2）"
  "圖片模型（Flux.2 Klein / Qwen-Image / Z-Image Turbo）"
  "啟動 ComfyUI + 比較工具"
  "Chatbot（Open WebUI + Ollama + LLM）"
)
selected=(0 0 0 0 0 0)   # 預設全部不選，請用 Space 勾選想安裝的項目

# 預留空間
for _ in "${!items[@]}"; do echo; done; echo; echo; echo

toggle_menu "選擇要安裝的項目：" items selected

echo ""
hr

DO_SYSTEM=${selected[0]}
DO_COMFYUI=${selected[1]}
DO_VIDEO=${selected[2]}
DO_IMAGE=${selected[3]}
DO_START=${selected[4]}
DO_CHATBOT=${selected[5]}

# 沒選任何項目就結束
if [[ "$DO_SYSTEM$DO_COMFYUI$DO_VIDEO$DO_IMAGE$DO_START$DO_CHATBOT" == "000000" ]]; then
  warn "未選擇任何項目，結束。"
  exit 0
fi

# 如果選了模型但沒選環境，自動開啟環境
if [[ "$DO_VIDEO" == "1" || "$DO_IMAGE" == "1" ]] && [[ "$DO_COMFYUI" == "0" ]]; then
  if [[ ! -d "comfyui/ComfyUI" ]]; then
    warn "下載模型需要 ComfyUI 環境，自動啟用"
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
# 系統初始化
# ═══════════════════════════════════════════════════════════════
if [[ "$DO_SYSTEM" == "1" ]]; then
  step "系統初始化"

  # ── 架構 ──
  ARCH=$(uname -m)
  if [[ "$ARCH" == "aarch64" ]]; then
    ok "架構：$ARCH"
  else
    warn "架構：$ARCH（預期 aarch64，部分套件可能不相容）"
  fi

  # ── Ubuntu 版本 ──
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    ok "系統：$PRETTY_NAME"
  fi

  # ── CUDA ──
  if command -v nvcc &>/dev/null; then
    CUDA_VER=$(nvcc --version 2>/dev/null | grep -oP 'release \K[0-9.]+')
    if [[ "$CUDA_VER" == 13.* ]]; then
      ok "CUDA $CUDA_VER（sm_121 相容）"
    else
      warn "CUDA $CUDA_VER — Blackwell sm_121 需要 CUDA 13.0+，部分功能可能不可用"
    fi
  else
    fail "找不到 nvcc。請確認 CUDA Toolkit 已安裝並在 PATH 中"
    echo "     export PATH=/usr/local/cuda/bin:\$PATH"
  fi

  # ── nvidia-smi ──
  if command -v nvidia-smi &>/dev/null; then
    GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
    DRIVER=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1)
    MEM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader 2>/dev/null | head -1)
    ok "GPU：$GPU_NAME · Driver $DRIVER · $MEM"
  else
    fail "找不到 nvidia-smi"
  fi

  # ── 記憶體 ──
  TOTAL_MEM=$(free -g | awk '/^Mem:/{print $2}')
  ok "記憶體：${TOTAL_MEM}GB"

  # ── 磁碟 ──
  DISK_AVAIL=$(df -BG "$SCRIPT_DIR" | awk 'NR==2{print $4}')
  ok "可用磁碟空間：$DISK_AVAIL"
  DISK_NUM=${DISK_AVAIL//[^0-9]/}
  if [[ "$DISK_NUM" -lt 100 ]]; then
    warn "磁碟空間偏少（模型下載需要 ~200GB+），請注意"
  fi

  # ── 系統套件 ──
  info "安裝必要套件..."
  PKGS=(python3-dev python3-venv build-essential git curl wget)
  NEED=()
  for p in "${PKGS[@]}"; do
    dpkg -s "$p" &>/dev/null || NEED+=("$p")
  done
  if [[ ${#NEED[@]} -eq 0 ]]; then
    ok "系統套件已齊全"
  else
    info "安裝缺少的套件：${NEED[*]}"
    sudo apt-get update -qq >> "$LOG" 2>&1
    sudo apt-get install -y "${NEED[@]}" >> "$LOG" 2>&1
    ok "套件安裝完成"
  fi

  # ── Docker ──
  if command -v docker &>/dev/null; then
    DOCKER_VER=$(docker --version 2>/dev/null | grep -oP '[0-9]+\.[0-9]+\.[0-9]+')
    if docker ps &>/dev/null; then
      ok "Docker $DOCKER_VER（可用）"
    else
      warn "Docker $DOCKER_VER 已裝但權限不足"
      info "加入 docker 群組..."
      sudo usermod -aG docker "$USER"
      warn "已加入 docker 群組。安裝完成後請登出再登入（或 newgrp docker）"
    fi
  else
    warn "Docker 未安裝"
    echo ""
    read -rp "  是否自動安裝 Docker？[Y/n] " yn
    case "$yn" in
      [nN]*) warn "跳過 Docker 安裝（Chatbot 功能將不可用）" ;;
      *)
        info "安裝 Docker..."
        curl -fsSL https://get.docker.com | sudo sh >> "$LOG" 2>&1
        sudo usermod -aG docker "$USER"
        ok "Docker 已安裝。請安裝完成後登出再登入"
        ;;
    esac
  fi

  # ── nvidia-container-toolkit ──
  if dpkg -s nvidia-container-toolkit &>/dev/null; then
    ok "nvidia-container-toolkit 已安裝"
  else
    warn "nvidia-container-toolkit 未安裝（Docker GPU 支援需要）"
    echo ""
    read -rp "  是否自動安裝？[Y/n] " yn
    case "$yn" in
      [nN]*) warn "跳過（Docker 內將無法使用 GPU）" ;;
      *)
        info "安裝 nvidia-container-toolkit..."
        curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
          sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg 2>/dev/null
        curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
          sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
          sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list > /dev/null
        sudo apt-get update -qq >> "$LOG" 2>&1
        sudo apt-get install -y nvidia-container-toolkit >> "$LOG" 2>&1
        sudo nvidia-ctk runtime configure --runtime=docker >> "$LOG" 2>&1
        sudo systemctl restart docker >> "$LOG" 2>&1 || true
        ok "nvidia-container-toolkit 已安裝"
        ;;
    esac
  fi

  echo ""
  ok "系統初始化完成"
fi

# ═══════════════════════════════════════════════════════════════
# ComfyUI 環境
# ═══════════════════════════════════════════════════════════════
if [[ "$DO_COMFYUI" == "1" ]]; then
  step "ComfyUI 環境"
  if [[ -d "comfyui/ComfyUI" && -d "comfyui/comfyui-env" ]]; then
    ok "ComfyUI 環境已存在，跳過"
  else
    info "建立 venv + 安裝 cu130 PyTorch + ComfyUI + Manager..."
    cd comfyui
    bash setup.sh 2>&1 | tee -a "$LOG"
    cd "$SCRIPT_DIR"
    ok "ComfyUI 環境設定完成"
  fi
fi

# ═══════════════════════════════════════════════════════════════
# HuggingFace 登入
# ═══════════════════════════════════════════════════════════════
if [[ "$DO_VIDEO" == "1" || "$DO_IMAGE" == "1" ]]; then
  step "HuggingFace 登入檢查"
  HF="$SCRIPT_DIR/comfyui/comfyui-env/bin/hf"
  if [[ ! -x "$HF" ]]; then
    info "安裝 HuggingFace CLI..."
    "$SCRIPT_DIR/comfyui/comfyui-env/bin/pip" install -U "huggingface_hub[cli]" -q >> "$LOG" 2>&1
  fi
  if "$HF" auth status &>/dev/null 2>&1; then
    ok "HuggingFace 已登入"
  else
    warn "HuggingFace 未登入"
    echo ""
    echo "  LTX-2.5 是 gated repo，需要登入並接受授權。"
    echo "  1. 執行：$HF auth login"
    echo "  2. 到 https://huggingface.co/Lightricks/LTX-2.5 接受授權"
    echo ""
    read -rp "  按 Enter 繼續（未登入的 gated 模型會下載失敗，其餘不受影響）... "
  fi
fi

# ═══════════════════════════════════════════════════════════════
# 影片模型
# ═══════════════════════════════════════════════════════════════
if [[ "$DO_VIDEO" == "1" ]]; then
  step "下載影片模型"

  vid_items=("LTX-2.5（Lightricks，22B int8）" "MiniMax H3（Hailuo 3.0，int8）" "Wan 2.2（14B fp8）")
  vid_sel=(1 1 1)
  for _ in "${!vid_items[@]}"; do echo; done; echo; echo; echo
  toggle_menu "選擇要下載的影片模型：" vid_items vid_sel

  [[ "${vid_sel[0]}" == "1" ]] && { info "下載 LTX-2.5..."; cd comfyui; bash download-models.sh ltx 2>&1 | tee -a "$LOG"; cd "$SCRIPT_DIR"; }
  [[ "${vid_sel[1]}" == "1" ]] && { info "下載 MiniMax H3..."; cd comfyui; bash download-models.sh h3 2>&1 | tee -a "$LOG"; cd "$SCRIPT_DIR"; }
  [[ "${vid_sel[2]}" == "1" ]] && { info "下載 Wan 2.2..."; cd comfyui; bash download-models.sh wan 2>&1 | tee -a "$LOG"; cd "$SCRIPT_DIR"; }
  ok "影片模型下載流程結束"
fi

# ═══════════════════════════════════════════════════════════════
# 圖片模型
# ═══════════════════════════════════════════════════════════════
if [[ "$DO_IMAGE" == "1" ]]; then
  step "下載圖片模型"

  img_items=("Flux.2 Klein（9B fp8）" "Qwen-Image-2512（bf16）" "Z-Image Turbo（6B bf16）")
  img_sel=(1 1 1)
  for _ in "${!img_items[@]}"; do echo; done; echo; echo; echo
  toggle_menu "選擇要下載的圖片模型：" img_items img_sel

  [[ "${img_sel[0]}" == "1" ]] && { info "下載 Flux.2 Klein..."; cd comfyui; bash download-models.sh flux2 2>&1 | tee -a "$LOG"; cd "$SCRIPT_DIR"; }
  [[ "${img_sel[1]}" == "1" ]] && { info "下載 Qwen-Image-2512..."; cd comfyui; bash download-models.sh qwen 2>&1 | tee -a "$LOG"; cd "$SCRIPT_DIR"; }
  [[ "${img_sel[2]}" == "1" ]] && { info "下載 Z-Image Turbo..."; cd comfyui; bash download-models.sh zimage 2>&1 | tee -a "$LOG"; cd "$SCRIPT_DIR"; }
  ok "圖片模型下載流程結束"
fi

# ═══════════════════════════════════════════════════════════════
# 啟動服務
# ═══════════════════════════════════════════════════════════════
if [[ "$DO_START" == "1" ]]; then
  step "啟動 ComfyUI + 比較工具"

  info "啟動 ComfyUI..."
  cd comfyui; bash start.sh; cd "$SCRIPT_DIR"

  info "等待 ComfyUI 就緒..."
  for i in $(seq 1 30); do
    if curl -s -o /dev/null http://localhost:8188 2>/dev/null; then
      ok "ComfyUI → http://localhost:8188"
      break
    fi
    [[ $i -eq 30 ]] && warn "ComfyUI 啟動逾時，請查看 comfyui/comfyui.log"
    sleep 2
  done

  info "啟動比較工具..."
  cd compare; bash start.sh; cd "$SCRIPT_DIR"
  ok "比較工具 → http://localhost:8890"

  # 自動開啟瀏覽器
  open_url() {
    local url="$1"
    if command -v xdg-open &>/dev/null; then xdg-open "$url" >/dev/null 2>&1 &
    elif command -v gio &>/dev/null; then gio open "$url" >/dev/null 2>&1 &
    elif command -v sensible-browser &>/dev/null; then sensible-browser "$url" >/dev/null 2>&1 &
    else warn "找不到瀏覽器開啟指令，請手動開啟：$url"; return 1; fi
  }
  info "開啟瀏覽器..."
  open_url "http://localhost:8188" && ok "已開啟 ComfyUI"
  open_url "http://localhost:8890" && ok "已開啟 比較工具"
fi

# ═══════════════════════════════════════════════════════════════
# Chatbot
# ═══════════════════════════════════════════════════════════════
if [[ "$DO_CHATBOT" == "1" ]]; then
  step "Chatbot（Open WebUI + Ollama）"

  if ! docker ps &>/dev/null; then
    fail "Docker 不可用。請登出再登入後手動執行："
    echo "    cd chatbot && ./start.sh && ./pull-models.sh"
  else
    info "啟動 Open WebUI + Ollama..."
    cd chatbot; bash start.sh 2>&1 | tee -a "$LOG"; cd "$SCRIPT_DIR"

    echo ""
    # 動態從 chatbot/models.txt 讀取清單，而非寫死在 install.sh（避免內容過時）。
    # 未加 # 的行預設勾選；以 # 開頭且後面是合法 tag 的行視為「可選、預設不勾選」。
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
            continue  # 純標題註解（如 "--- 日常聊天 ---"），略過
        tag = m.group(1)
        desc = body[len(tag):].strip().lstrip("#").strip()
        print(f"{tag}\t{desc}\t{'0' if commented else '1'}")
PYEOF
      )
    fi

    if [[ ${#LLM_LIST[@]} -eq 0 ]]; then
      warn "chatbot/models.txt 無有效項目，跳過 LLM 下載"
    else
      for _ in "${!llm_items[@]}"; do echo; done; echo; echo; echo
      toggle_menu "選擇要下載的 LLM（來自 chatbot/models.txt）：" llm_items llm_sel

      for i in "${!LLM_LIST[@]}"; do
        if [[ "${llm_sel[$i]}" == "1" ]]; then
          info "下載 ${LLM_LIST[$i]}..."
          docker exec open-webui ollama pull "${LLM_LIST[$i]}" 2>&1 | tee -a "$LOG"
        fi
      done
    fi
    ok "Chatbot → http://localhost:8080"
  fi
fi

# ═══════════════════════════════════════════════════════════════
# 完成
# ═══════════════════════════════════════════════════════════════
echo ""
hr
echo ""
echo -e "${GREEN}${BOLD}  ✔ 安裝完成！${NC}"
echo ""
echo -e "  ${BOLD}服務一覽${NC}"
echo "  ┌──────────────────┬───────────────────────────┐"
echo "  │ ComfyUI           │ http://localhost:8188      │"
echo "  │ 模型比較工具       │ http://localhost:8890      │"
echo "  │ Chatbot (WebUI)   │ http://localhost:8080      │"
echo "  └──────────────────┴───────────────────────────┘"
echo ""
echo -e "  ${BOLD}常用指令${NC}"
echo "  啟動全部：comfyui/start.sh && compare/start.sh && chatbot/start.sh"
echo "  停止全部：comfyui/stop.sh && compare/stop.sh && chatbot/stop.sh"
echo ""
echo -e "  ${DIM}詳細 log：$LOG${NC}"
echo ""
