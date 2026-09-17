#!/usr/bin/env bash
# Download local open-weight video/image models into the matching ComfyUI/models/
# folders. Quantised builds are preferred (less memory, faster on Blackwell).
# The files are large — roughly 20-40 GB per model.
#
#   ./download-models.sh          # everything (video + image)
#   ./download-models.sh video    # video models (ltx + wan + h3)
#   ./download-models.sh image    # image models (flux2 + qwen + zimage)
#   ./download-models.sh flux2    # Flux.2 Klein only
#   ./download-models.sh qwen     # Qwen-Image-2512 only
#   ./download-models.sh zimage   # Z-Image Turbo only
#
# Requires the HuggingFace CLI, logged in (LTX-2.5 is a gated repo — accept its licence):
#   pip install -U "huggingface_hub[cli]"
#   hf auth login
#
# If a filename or path changes upstream, the safest fallback is opening the official
# template in ComfyUI — it fetches whatever is missing (see workflows/README.md).
#
# Note: -e is deliberately omitted so one failed download (e.g. LTX without a login)
# does not abort the remaining models.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMFY="$SCRIPT_DIR/ComfyUI"
VENV="$SCRIPT_DIR/comfyui-env"
STAGE="$SCRIPT_DIR/.hf-stage"
mkdir -p "$STAGE"

# Prefer the hf CLI inside the ComfyUI venv (installed by setup.sh) to avoid system pip limits
if [[ -x "$VENV/bin/hf" ]]; then HF="$VENV/bin/hf"; PY="$VENV/bin/python"
elif command -v hf >/dev/null 2>&1; then HF="hf"; PY="python3"
else echo "!! hf CLI not found — run ./setup.sh first, or pip install -U 'huggingface_hub[cli]'"; exit 1; fi

# Recent huggingface_hub uses Xet transfer; enable high-performance mode (replaces the deprecated hf_transfer)
export HF_XET_HIGH_PERFORMANCE=1

# dl <repo> <filename> <models subfolder>: matches by filename glob, so the exact path inside the repo does not matter
dl(){
  local repo="$1" fname="$2" sub="$3"
  local dest="$COMFY/models/$sub"
  mkdir -p "$dest"
  if [[ -f "$dest/$fname" ]]; then echo "  ✓ already present, skipping: $sub/$fname"; return 0; fi
  echo ">> downloading: $fname  ←  $repo"
  if ! "$HF" download "$repo" --include "**/$fname" --include "$fname" --local-dir "$STAGE/$repo" >/dev/null; then
    echo "  !! download failed: $repo / $fname (check hf auth login / licence accepted)"; return 1
  fi
  local found; found="$(find "$STAGE/$repo" -type f -name "$fname" | head -n1)"
  if [[ -n "$found" ]]; then mv -f "$found" "$dest/$fname"; echo "  → $dest/$fname"; else
    echo "  !! $fname not found in the repo — use the ComfyUI template to auto-download it"; return 1; fi
}

get_ltx(){
  echo "=== LTX-2.5 (Lightricks, gated; text encoder is Gemma-4) ==="
  dl "Lightricks/LTX-2.5" "ltx-2.5-22b-distilled-transformer-comfy-int8-convrot.safetensors" "diffusion_models"
  dl "Lightricks/LTX-2.5" "gemma4-12b-with-proj-ltx-2.5-comfy-int8-convrot.safetensors"       "text_encoders"
  dl "Lightricks/LTX-2.5" "ltx-2.5-video-vae-bf16.safetensors"                                 "vae"
  dl "Lightricks/LTX-2.5" "ltx-2.5-audio-vae-bf16.safetensors"                                 "vae"
  # Optional: prompt enhancer / upscaler — uncomment to use
  # dl "Lightricks/LTX-2.5" "gemma4_e2b_it_int8_convrot.safetensors" "text_encoders"
  # dl "Lightricks/LTX-2.5" "ltx-2.5-latent-spatial-upscaler-x2-bf16-1.0.safetensors" "latent_upscale_models"
}

get_wan(){
  echo "=== Wan 2.2 T2V 14B (Comfy-Org repack, fp8; text-to-image and text-to-video) ==="
  dl "Comfy-Org/Wan_2.2_ComfyUI_Repackaged" "wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors" "diffusion_models"
  dl "Comfy-Org/Wan_2.2_ComfyUI_Repackaged" "wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors"  "diffusion_models"
  dl "Comfy-Org/Wan_2.2_ComfyUI_Repackaged" "umt5_xxl_fp8_e4m3fn_scaled.safetensors"           "text_encoders"
  dl "Comfy-Org/Wan_2.2_ComfyUI_Repackaged" "wan_2.1_vae.safetensors"                          "vae"
}

get_h3(){
  echo "=== MiniMax H3 / Hailuo 3.0 (Comfy-Org, local open weights int8; Qwen3-VL NVFP4 encoder) ==="
  dl "Comfy-Org/MiniMax-H3" "minimax_h3_fl2va_pruned_int8_convrot.safetensors" "diffusion_models"
  dl "Comfy-Org/MiniMax-H3" "qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors"     "text_encoders"
  dl "Comfy-Org/MiniMax-H3" "minimax_h3_video_vae_fp16.safetensors"            "vae"
  dl "Comfy-Org/MiniMax-H3" "minimax_h3_audio_vae_fp32.safetensors"            "vae"
  # Optional: reference-to-video mode
  # dl "Comfy-Org/MiniMax-H3" "minimax_h3_ref2va_pruned_int8_convrot.safetensors" "diffusion_models"
}

get_flux2(){
  echo "=== Flux.2 Klein 9B (Black Forest Labs, text-to-image) ==="
  dl "black-forest-labs/FLUX.2-klein-9b-fp8" "flux-2-klein-9b-fp8.safetensors"  "diffusion_models"
  dl "Comfy-Org/vae-text-encorder-for-flux-klein-9b" "flux2-vae.safetensors"    "vae"
  dl "Comfy-Org/vae-text-encorder-for-flux-klein-9b" "qwen_3_8b.safetensors"   "text_encoders"
}

get_qwen_image(){
  echo "=== Qwen-Image-2512 (Alibaba, text-to-image) ==="
  dl "Comfy-Org/Qwen-Image_ComfyUI" "qwen_image_2512_bf16.safetensors"        "diffusion_models"
  dl "Comfy-Org/Qwen-Image_ComfyUI" "qwen_2.5_vl_7b_fp8_scaled.safetensors"  "text_encoders"
  dl "Comfy-Org/Qwen-Image_ComfyUI" "qwen_image_vae.safetensors"             "vae"
}

get_zimage(){
  echo "=== Z-Image Turbo (Alibaba Tongyi, 6B distilled text-to-image) ==="
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
  *)      echo "Usage: $0 [ltx|wan|h3|flux2|qwen|zimage|video|image|all]"; exit 1 ;;
esac

echo
echo ">> Downloads finished. Clean the staging dir with: rm -rf \"$STAGE\""
echo ">> Models in place:"
find "$COMFY/models" -maxdepth 2 -type f \( -name '*.safetensors' \) 2>/dev/null | sed "s#$COMFY/##" || true
