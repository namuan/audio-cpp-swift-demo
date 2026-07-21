# AudioCPP Swift Demo

A macOS Swift command-line tool that runs local text-to-speech (TTS) inference using the [audio.cpp](https://github.com/0xShug0/audio.cpp) C++ engine. The bridge exposes TTS through a thin Objective-C++ layer — no Python required at runtime.

Works with models from your local [HuggingFace cache](https://huggingface.co/docs/huggingface_hub/guides/download#download-files-to-local-folder).

## Quick Start

```sh
# 1. Build audio.cpp (one-time)
git clone https://github.com/0xShug0/audio.cpp /tmp/audio-cpp-clone
# ... see Build section below for full cmake + libtool steps ...

# 2. Build the Swift tool
xcodebuild -project Qwen3TTSDemo.xcodeproj -scheme Qwen3TTSDemo \
  -configuration Release -derivedDataPath build build

# 3. Prepare a model from your HuggingFace cache
./scripts/prepare_models.sh qwen3-custom-voice

# 4. Generate speech
./build/Build/Products/Release/Qwen3TTSDemo custom-voice \
  --model models/qwen3-custom-voice \
  --speaker serena \
  --text "Hello, this is a local text-to-speech demo running on my Mac." \
  --out hello.wav
```

## Supported Models

### ✅ Working — from your HuggingFace cache

| Model | Size | Command | How it works |
|-------|------|---------|--------------|
| **Qwen3 TTS CustomVoice 0.6B** | 2.3 GB | `custom-voice` | Pick a built-in speaker preset, no reference audio needed |

**Available speakers:** `serena`, `vivian`, `ryan`, `aiden`, `dylan`, `eric`, `ono_anna`, `sohee`, `uncle_fu`

### ⚠️ Requires model download or workaround

| Model | Size | Command | Status |
|-------|------|---------|--------|
| **Qwen3 TTS Base 1.7B** | 4.2 GB (cached) | `voice-clone` | Speaker encoder has Conv1d dimension mismatch with MLX-exported safetensors. Needs GGUF conversion or code fix. |
| **Qwen3 TTS VoiceDesign 1.7B** | ~4 GB (not cached) | `voice-design` | Not in your cache. Install: `python tools/model_manager.py install qwen3_tts_1_7b_voice_design` |

### 🗂️ Your HuggingFace Cache

```
~/.cache/huggingface/hub/
├── models--Qwen--Qwen3-TTS-12Hz-0.6B-CustomVoice/  ✅ ready
├── models--Qwen--Qwen3-TTS-12Hz-1.7B-Base/          ⚠️ dim issue
├── models--mlx-community--Qwen3-TTS-12Hz-0.6B-Base-bf16/  ⚠️ dim issue
├── models--mlx-community--Qwen3-TTS-12Hz-1.7B-Base-bf16/  ⚠️ dim issue
├── models--k2-fsa--OmniVoice/                        ❌ incomplete download
├── models--aufklarer--IndexTTS2-MLX-fp16/            ❌ broken symlinks
├── models--hexgrad--Kokoro-82M/                      ❌ PyTorch .pth (needs conversion)
├── models--ACE-Step--Ace-Step1.5/                    ❌ not downloaded
└── models--openai--whisper-base/                     ❌ ASR, not TTS
```

## Prerequisites

- **macOS 13.3+** (Apple Silicon or Intel with Metal support)
- **Xcode 16.0+** with Command Line Tools (`xcode-select --install`)
- **CMake 3.20+** (`brew install cmake`)

## Building

### 1. Build audio.cpp library

```sh
# Clone if not already present
git clone https://github.com/0xShug0/audio.cpp /tmp/audio-cpp-clone

# Configure with Metal backend
cmake -S /tmp/audio-cpp-clone \
  -B /tmp/audio-cpp-clone/build/macos-metal-release \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DENGINE_ENABLE_METAL=ON \
  -DENGINE_ENABLE_CUDA=OFF \
  -DENGINE_ENABLE_VULKAN=OFF \
  -DENGINE_ENABLE_LLAMAFILE=ON \
  -DENGINE_ENABLE_NATIVE_CPU=ON \
  -DENGINE_ENABLE_OPENMP=OFF \
  -DGGML_METAL_EMBED_LIBRARY=ON \
  -DENGINE_BUILD_EXAMPLES=OFF \
  -DENGINE_BUILD_TESTS=OFF \
  -DENGINE_BUILD_WARMBENCH=OFF \
  -DBUILD_SHARED_LIBS=OFF

cmake --build /tmp/audio-cpp-clone/build/macos-metal-release \
  --target engine_runtime -j $(sysctl -n hw.logicalcpu)

# Merge all static libs and copy headers
mkdir -p /tmp/audio-cpp-clone/build/xcframework/artifacts/Headers
libtool -static -o /tmp/audio-cpp-clone/build/xcframework/artifacts/libAudioCpp.a \
  /tmp/audio-cpp-clone/build/macos-metal-release/libengine_runtime.a \
  /tmp/audio-cpp-clone/build/macos-metal-release/ggml/src/libggml.a \
  /tmp/audio-cpp-clone/build/macos-metal-release/ggml/src/libggml-base.a \
  /tmp/audio-cpp-clone/build/macos-metal-release/ggml/src/libggml-cpu.a \
  /tmp/audio-cpp-clone/build/macos-metal-release/ggml/src/ggml-metal/libggml-metal.a \
  /tmp/audio-cpp-clone/build/macos-metal-release/ggml/src/ggml-blas/libggml-blas.a \
  /tmp/audio-cpp-clone/build/macos-metal-release/libcjson_vendor.a \
  /tmp/audio-cpp-clone/build/macos-metal-release/libyaml_vendor.a \
  /tmp/audio-cpp-clone/build/macos-metal-release/external/sentencepiece/src/libsentencepiece.a
rsync -a /tmp/audio-cpp-clone/include/ /tmp/audio-cpp-clone/build/xcframework/artifacts/Headers/
```

### 2. Build the Swift CLI

```sh
xcodebuild \
  -project Qwen3TTSDemo.xcodeproj \
  -scheme Qwen3TTSDemo \
  -configuration Release \
  -derivedDataPath build \
  build
```

The binary lands at `build/Build/Products/Release/Qwen3TTSDemo`.

### 3. Prepare models

Use the included script to mirror models from your HuggingFace cache. It resolves symlinks and copies the required `model_specs/`:

```sh
# List available models and their cache status
./scripts/prepare_models.sh list

# Prepare a specific model
./scripts/prepare_models.sh qwen3-custom-voice

# Prepare all cached models
./scripts/prepare_models.sh all
```

You can also point it at different directories:

```sh
MODELS_DIR=/path/to/custom/models ./scripts/prepare_models.sh qwen3-custom-voice
```

Or prepare models manually:

```sh
rsync -aL ~/.cache/huggingface/hub/models--Qwen--Qwen3-TTS-12Hz-0.6B-CustomVoice/snapshots/<hash>/ models/qwen3-custom-voice/
mkdir -p models/qwen3-custom-voice/model_specs
cp /tmp/audio-cpp-clone/model_specs/qwen3_tts.json models/qwen3-custom-voice/model_specs/
```

## Usage

### Custom Voice — speaker presets

Use built-in speakers. No reference audio needed. Works with the **0.6B CustomVoice** model.

```sh
build/Build/Products/Release/Qwen3TTSDemo custom-voice \
  --model models/qwen3-custom-voice \
  --speaker serena \
  --text "The lighthouse keeper records a detailed morning report about the tide, and the ships crossing the horizon." \
  --out output.wav
```

**All 9 speakers:**

```sh
for speaker in serena vivian ryan aiden dylan eric ono_anna sohee uncle_fu; do
  build/Build/Products/Release/Qwen3TTSDemo custom-voice \
    --model models/qwen3-custom-voice \
    --speaker "$speaker" \
    --text "Hello, my name is ${speaker//_/ }." \
    --out "output_${speaker}.wav"
done
```

### Custom Voice with style instruction

Guide the delivery with `--instruct`:

```sh
build/Build/Products/Release/Qwen3TTSDemo custom-voice \
  --model models/qwen3-custom-voice \
  --speaker vivian \
  --instruct "Speak in a cheerful, enthusiastic tone like a morning radio host." \
  --text "Good morning everyone! Today is going to be a wonderful day." \
  --out cheerful.wav
```

### Voice Clone — from reference audio (experimental)

Requires a **Base variant** model (1.7B or 0.6B). Note: currently blocked by a Conv1d weight dimension mismatch in the safetensors export. See Troubleshooting.

```sh
# After preparing a Base model:
./scripts/prepare_models.sh qwen3-base-1.7b

# Voice clone (may fail with tensor shape mismatch — see Troubleshooting)
build/Build/Products/Release/Qwen3TTSDemo voice-clone \
  --model models/qwen3-base-1.7b \
  --voice-ref /path/to/reference_speech.wav \
  --reference-text "What the person says in the reference audio." \
  --text "This text will be spoken in the cloned voice." \
  --out cloned.wav
```

### Voice Design — from text description (requires download)

Use the **VoiceDesign 1.7B** variant (not in cache — download first):

```sh
cd /tmp/audio-cpp-clone
pip install torch safetensors pyyaml
python tools/model_manager.py install qwen3_tts_1_7b_voice_design --models-dir /tmp/models

# Then run:
build/Build/Products/Release/Qwen3TTSDemo voice-design \
  --model /tmp/models/Qwen3-TTS-12Hz-1.7B-VoiceDesign \
  --instruct "A calm, deep male narrator with a warm documentary voice." \
  --text "In the vast expanse of the cosmos, a single star can tell a billion stories." \
  --out designed.wav
```

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `--model <path>` | (required) | Model directory |
| `--text <text>` | (required) | Text to synthesize |
| `--out <path>` | (required) | Output WAV path |
| `--speaker <name>` | (required for custom-voice) | Speaker preset: `serena`, `vivian`, `ryan`, etc. |
| `--instruct <text>` | (optional) | Voice style guidance |
| `--backend <name>` | `metal` | `metal` or `cpu` |
| `--device <n>` | `0` | GPU device index |
| `--threads <n>` | `8` | CPU worker threads |
| `--language <name>` | `English` | Input language |
| `--seed <n>` | `1234` | Random seed |
| `--max-new-tokens <n>` | `256` | Max output tokens |

## Output

All commands produce **16-bit PCM WAV** at **24000 Hz mono**. Typical output: ~45 KB per second of speech.

## Extending

audio.cpp supports 25+ model families. The bridge can be extended to any of them:

| Family | Task | Size |
|--------|------|------|
| `pocket_tts` | TTS, voice cloning | 100M |
| `kokoro_tts` | TTS | 82M |
| `chatterbox` | TTS, voice cloning, VC | 0.5B |
| `omnivoice` | TTS, voice cloning, voice design | 0.6B |
| `vibevoice` | TTS, multi-speaker dialog | 1.5B / 7B |
| `miotts` | TTS, voice cloning | 1.7B |
| `index_tts2` | TTS, voice cloning | — |
| `outetts` | TTS, voice cloning | 1.0B |
| `voxcpm2` | TTS, voice cloning, voice design | 2B |
| `supertonic` | TTS | — |
| `seed_vc` | Voice conversion | — |
| `qwen3_asr` | Speech recognition | 0.6B |
| `stable_audio` | Music / sound generation | 3B |

To add one:
1. Add a method to `MiniTTSDemoBridge.h` / `.mm` mapping the model's request shape
2. Change `family_hint` in `init` (or make it configurable)
3. Add a `case` in `main.swift`

## Troubleshooting

### "Qwen3 custom voice prefill requires speaker"

You're using `voice-clone` with a CustomVoice model. Use `custom-voice --speaker <name>`.

### "tensor shape mismatch for speaker_encoder"

The safetensors Conv1d weights use MLX dimension ordering `(out, kernel, in)` but audio.cpp expects PyTorch ordering `(out, in, kernel)`. This affects Base-variant models. Workarounds:

1. **Use a GGUF-converted model** — convert with `audiocpp_gguf`:
   ```sh
   cd /tmp/audio-cpp-clone
   cmake --build build/macos-metal-release --target audiocpp_gguf
   build/bin/audiocpp_gguf \
     --input models/qwen3-base-1.7b/model.safetensors \
     --family qwen3_tts --output models/qwen3-base-1.7b/model.gguf --type q8_0
   ```
2. **Stick with CustomVoice** — the `custom-voice` command works without a speaker encoder.

### Metal backend hangs

On some Apple Silicon macs, Metal may hang after the first inference. Use `--backend cpu` as fallback.

### HuggingFace cache symlinks

audio.cpp resolves symlinks with `weakly_canonical`, breaking HF blob paths. Use `rsync -aL` or `prepare_models.sh`.

### Model spec not found

```sh
mkdir -p <model_dir>/model_specs
cp /tmp/audio-cpp-clone/model_specs/qwen3_tts.json <model_dir>/model_specs/
```

## Project Structure

```
.
├── scripts/
│   └── prepare_models.sh              # Mirror models from HF cache
├── Qwen3TTSDemo/
│   ├── main.swift                     # Swift CLI entry point
│   ├── MiniTTSDemoBridge.h            # ObjC bridge interface
│   ├── MiniTTSDemoBridge.mm           # ObjC++ → audio.cpp C++ engine
│   └── Qwen3TTSDemo-Bridging-Header.h # Swift bridging header
└── Qwen3TTSDemo.xcodeproj/            # Xcode project (links libAudioCpp.a)
```

## License

MIT — see [audio.cpp](https://github.com/0xShug0/audio.cpp) for the upstream engine license.
