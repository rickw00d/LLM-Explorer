#!/usr/bin/env bash
# 下載影片/圖片模型的「本地開放權重」到 ComfyUI/models/ 對應資料夾。
# 優先用量化版（Blackwell 上省記憶體、較快）。檔案很大（每組 ~20-40GB）。
#
# 用法：
#   ./download-models.sh          # 全部（影片 + 圖片）
#   ./download-models.sh video    # 影片模型（ltx + wan + h3）
#   ./download-models.sh image    # 圖片模型（flux2 + qwen + zimage）
#   ./download-models.sh flux2    # 只下 Flux.2 Klein
#   ./download-models.sh qwen     # 只下 Qwen-Image-2512
#   ./download-models.sh zimage   # 只下 Z-Image Turbo
#
# 需求：先安裝並登入 HuggingFace CLI（LTX-2.5 為 gated repo，需接受授權）：
#   pip install -U "huggingface_hub[cli]"
#   hf auth login
#
# 若某檔路徑/名稱有變，最穩的替代方式：在 ComfyUI 開官方 Template，
# 介面會自動抓取缺少的模型（見 workflows/README.md）。
# 注意：刻意不用 -e，讓單一檔案下載失敗（例如 LTX 未登入）不會中止其餘模型
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMFY="$SCRIPT_DIR/ComfyUI"
VENV="$SCRIPT_DIR/comfyui-env"
STAGE="$SCRIPT_DIR/.hf-stage"
mkdir -p "$STAGE"

# 優先用 ComfyUI venv 內的 hf（setup.sh 已安裝 huggingface-hub），免去系統 pip 限制
if [[ -x "$VENV/bin/hf" ]]; then HF="$VENV/bin/hf"; PY="$VENV/bin/python"
elif command -v hf >/dev/null 2>&1; then HF="hf"; PY="python3"
else echo "!! 找不到 hf。請先跑 ./setup.sh，或 pip install -U 'huggingface_hub[cli]'"; exit 1; fi

# 新版 huggingface_hub 用 Xet 傳輸，開高效能模式（取代已棄用的 hf_transfer）
export HF_XET_HIGH_PERFORMANCE=1

# dl <repo> <檔名> <models 子資料夾>：以檔名 glob 比對，不依賴 repo 內確切路徑
dl(){
  local repo="$1" fname="$2" sub="$3"
  local dest="$COMFY/models/$sub"
  mkdir -p "$dest"
  if [[ -f "$dest/$fname" ]]; then echo "  ✓ 已存在，略過：$sub/$fname"; return 0; fi
  echo ">> 下載：$fname  ←  $repo"
  if ! "$HF" download "$repo" --include "**/$fname" --include "$fname" --local-dir "$STAGE/$repo" >/dev/null; then
    echo "  !! 下載失敗：$repo / $fname（檢查 hf auth login / 是否已接受授權）"; return 1
  fi
  local found; found="$(find "$STAGE/$repo" -type f -name "$fname" | head -n1)"
  if [[ -n "$found" ]]; then mv -f "$found" "$dest/$fname"; echo "  → $dest/$fname"; else
    echo "  !! repo 內找不到 $fname，請改用 ComfyUI Template 自動下載"; return 1; fi
}

get_ltx(){
  echo "=== LTX-2.5（Lightricks，gated；文字編碼器就是 Gemma-4）==="
  dl "Lightricks/LTX-2.5" "ltx-2.5-22b-distilled-transformer-comfy-int8-convrot.safetensors" "diffusion_models"
  dl "Lightricks/LTX-2.5" "gemma4-12b-with-proj-ltx-2.5-comfy-int8-convrot.safetensors"       "text_encoders"
  dl "Lightricks/LTX-2.5" "ltx-2.5-video-vae-bf16.safetensors"                                 "vae"
  dl "Lightricks/LTX-2.5" "ltx-2.5-audio-vae-bf16.safetensors"                                 "vae"
  # 可選：提示詞增強器 / 上採樣器（要用再取消註解）
  # dl "Lightricks/LTX-2.5" "gemma4_e2b_it_int8_convrot.safetensors" "text_encoders"
  # dl "Lightricks/LTX-2.5" "ltx-2.5-latent-spatial-upscaler-x2-bf16-1.0.safetensors" "latent_upscale_models"
}

get_wan(){
  echo "=== Wan 2.2 T2V 14B（Comfy-Org 重打包，fp8；可做文生圖/文生影片）==="
  dl "Comfy-Org/Wan_2.2_ComfyUI_Repackaged" "wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors" "diffusion_models"
  dl "Comfy-Org/Wan_2.2_ComfyUI_Repackaged" "wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors"  "diffusion_models"
  dl "Comfy-Org/Wan_2.2_ComfyUI_Repackaged" "umt5_xxl_fp8_e4m3fn_scaled.safetensors"           "text_encoders"
  dl "Comfy-Org/Wan_2.2_ComfyUI_Repackaged" "wan_2.1_vae.safetensors"                          "vae"
}

get_h3(){
  echo "=== MiniMax H3 / Hailuo 3.0（Comfy-Org，本地開放權重 int8；編碼器為 Qwen3-VL NVFP4）==="
  dl "Comfy-Org/MiniMax-H3" "minimax_h3_fl2va_pruned_int8_convrot.safetensors" "diffusion_models"
  dl "Comfy-Org/MiniMax-H3" "qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors"     "text_encoders"
  dl "Comfy-Org/MiniMax-H3" "minimax_h3_video_vae_fp16.safetensors"            "vae"
  dl "Comfy-Org/MiniMax-H3" "minimax_h3_audio_vae_fp32.safetensors"            "vae"
  # 可選：Reference-to-Video 模式
  # dl "Comfy-Org/MiniMax-H3" "minimax_h3_ref2va_pruned_int8_convrot.safetensors" "diffusion_models"
}

get_flux2(){
  echo "=== Flux.2 Klein 9B（Black Forest Labs，文生圖）==="
  dl "black-forest-labs/FLUX.2-klein-9b-fp8" "flux-2-klein-9b-fp8.safetensors"  "diffusion_models"
  dl "Comfy-Org/vae-text-encorder-for-flux-klein-9b" "flux2-vae.safetensors"    "vae"
  dl "Comfy-Org/vae-text-encorder-for-flux-klein-9b" "qwen_3_8b.safetensors"   "text_encoders"
}

get_qwen_image(){
  echo "=== Qwen-Image-2512（Alibaba，文生圖）==="
  dl "Comfy-Org/Qwen-Image_ComfyUI" "qwen_image_2512_bf16.safetensors"        "diffusion_models"
  dl "Comfy-Org/Qwen-Image_ComfyUI" "qwen_2.5_vl_7b_fp8_scaled.safetensors"  "text_encoders"
  dl "Comfy-Org/Qwen-Image_ComfyUI" "qwen_image_vae.safetensors"             "vae"
}

get_zimage(){
  echo "=== Z-Image Turbo（Alibaba Tongyi，6B 蒸餾文生圖）==="
  dl "Comfy-Org/z_image_turbo" "z_image_turbo_bf16.safetensors"                    "diffusion_models"
  dl "Comfy-Org/z_image_turbo" "qwen_3_4b.safetensors"                            "text_encoders"
  dl "Comfy-Org/z_image_turbo" "ae.safetensors"                                    "vae"
  dl "Comfy-Org/z_image_turbo" "z_image_turbo_distill_patch_lora_bf16.safetensors" "loras"
}

case "${1:-all}" in
  ltx)    get_ltx ;;
  wan)    get_wan ;;
  h3)     get_h3 ;;
  flux2)  get_flux2 ;;
  qwen)   get_qwen_image ;;
  zimage) get_zimage ;;
  video)  get_ltx; get_wan; get_h3 ;;
  image)  get_flux2; get_qwen_image; get_zimage ;;
  all)    get_ltx; get_wan; get_h3; get_flux2; get_qwen_image; get_zimage ;;
  *)      echo "用法： $0 [ltx|wan|h3|flux2|qwen|zimage|video|image|all]"; exit 1 ;;
esac

echo
echo ">> 下載流程結束。清理暫存： rm -rf \"$STAGE\""
echo ">> 已放置的模型："
find "$COMFY/models" -maxdepth 2 -type f \( -name '*.safetensors' \) 2>/dev/null | sed "s#$COMFY/##" || true
