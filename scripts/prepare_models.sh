#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MODELS_DIR="${MODELS_DIR:-$PROJECT_DIR/models}"
AUDIOCPP_DIR="${AUDIOCPP_DIR:-/tmp/audio-cpp-clone}"

get_cache_path() {
    case "$1" in
        qwen3-custom-voice) echo "$HOME/.cache/huggingface/hub/models--Qwen--Qwen3-TTS-12Hz-0.6B-CustomVoice/snapshots/85e237c12c027371202489a0ec509ded67b5e4b5" ;;
        qwen3-base-0.6b)    echo "$HOME/.cache/huggingface/hub/models--mlx-community--Qwen3-TTS-12Hz-0.6B-Base-bf16/snapshots/1eccf1cb2519b5a4e8a95b5f0544f3303568164f" ;;
        qwen3-base-1.7b)    echo "$HOME/.cache/huggingface/hub/models--Qwen--Qwen3-TTS-12Hz-1.7B-Base/snapshots/a6eb4f68e4b056f1215157bb696209bc82a6db48" ;;
        *) echo "" ;;
    esac
}

get_family() {
    case "$1" in
        qwen3-custom-voice) echo "qwen3_tts" ;;
        qwen3-base-0.6b)    echo "qwen3_tts" ;;
        qwen3-base-1.7b)    echo "qwen3_tts" ;;
        *) echo "" ;;
    esac
}

get_description() {
    case "$1" in
        qwen3-custom-voice) echo "Qwen3 TTS 0.6B CustomVoice (speaker presets)" ;;
        qwen3-base-0.6b)    echo "Qwen3 TTS 0.6B Base (voice clone, smaller)" ;;
        qwen3-base-1.7b)    echo "Qwen3 TTS 1.7B Base (voice clone, larger)" ;;
        *) echo "Unknown model: $1" ;;
    esac
}

ALL_MODELS="qwen3-custom-voice qwen3-base-0.6b qwen3-base-1.7b"

usage() {
    cat <<EOF
Usage: prepare_models.sh <model-key>|all|list

Available models:
  qwen3-custom-voice   Qwen3 TTS 0.6B CustomVoice (speaker presets)
  qwen3-base-0.6b      Qwen3 TTS 0.6B Base (voice clone, smaller)
  qwen3-base-1.7b      Qwen3 TTS 1.7B Base (voice clone, larger)

Environment:
  MODELS_DIR      Output directory (default: $PROJECT_DIR/models)
  AUDIOCPP_DIR    Path to audio.cpp clone (default: /tmp/audio-cpp-clone)

Examples:
  prepare_models.sh qwen3-custom-voice
  prepare_models.sh all
EOF
    exit 0
}

prepare_model() {
    local key="$1"
    local cache_path
    local family
    local target_dir

    cache_path="$(get_cache_path "$key")"
    family="$(get_family "$key")"
    target_dir="$MODELS_DIR/$key"

    if [[ -z "$cache_path" ]]; then
        echo "ERROR: Unknown model key '$key'"
        echo "  Run: $0 list"
        return 1
    fi

    if [[ ! -d "$cache_path" ]]; then
        echo "ERROR: Cache path not found: $cache_path"
        echo "  Try downloading first with: huggingface-cli download <model>"
        return 1
    fi

    echo "=== Preparing $key ==="
    echo "  Description: $(get_description "$key")"
    echo "  Cache:       $cache_path"
    echo "  Target:      $target_dir"

    mkdir -p "$target_dir"
    rsync -aL "$cache_path/" "$target_dir/"
    echo "  Copied model files."

    # Copy model spec
    local spec_file="$AUDIOCPP_DIR/model_specs/${family}.json"
    if [[ -f "$spec_file" ]]; then
        mkdir -p "$target_dir/model_specs"
        cp "$spec_file" "$target_dir/model_specs/"
        echo "  Copied model spec: ${family}.json"
    else
        echo "  WARNING: model spec not found at $spec_file"
    fi

    # Show size
    local size
    size=$(du -sh "$target_dir" | cut -f1)
    echo "  Total size: $size"
    echo "  Done: $target_dir"
    echo ""
}

# --- Main ---
MODEL_KEY="${1:-}"

if [[ -z "$MODEL_KEY" ]] || [[ "$MODEL_KEY" == "-h" ]] || [[ "$MODEL_KEY" == "--help" ]]; then
    usage
fi

if [[ "$MODEL_KEY" == "list" ]]; then
    echo "Available models:"
    for key in $ALL_MODELS; do
        cache="$(get_cache_path "$key")"
        if [[ -d "$cache" ]]; then
            echo "  $key  ($(get_description "$key")) [cached]"
        else
            echo "  $key  ($(get_description "$key")) [needs download]"
        fi
    done
    exit 0
fi

if [[ "$MODEL_KEY" == "all" ]]; then
    for key in $ALL_MODELS; do
        cache="$(get_cache_path "$key")"
        if [[ -d "$cache" ]]; then
            prepare_model "$key"
        else
            echo "SKIP $key: not found in HuggingFace cache"
        fi
    done
    exit 0
fi

# Validate single model key
if [[ -z "$(get_cache_path "$MODEL_KEY")" ]]; then
    echo "ERROR: Unknown model key '$MODEL_KEY'"
    echo "  Run '$0 list' to see available models."
    exit 1
fi

prepare_model "$MODEL_KEY"
