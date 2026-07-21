# AudioCPP Swift Demo

A macOS Swift command-line tool that runs local text-to-speech (TTS) inference using the [audio.cpp](https://github.com/0xShug0/audio.cpp) C++ engine. The bridge exposes **voice cloning**, **voice design**, and **custom voice** (speaker presets) through a thin Objective-C++ layer — no Python required at runtime.

## Supported Models

### Qwen3 TTS (tested and working)

| Variant | Command | What it does |
|---------|---------|--------------|
| **CustomVoice** (0.6B) | `custom-voice` | Synthesize speech from text using a built-in speaker preset |
| **Base** (0.6B / 1.7B) | `voice-clone` | Clone a voice from a reference WAV file |
| **VoiceDesign** (1.7B) | `voice-design` | Design a voice from a text description |

The bridge is model-family aware and can be extended to other audio.cpp models (PocketTTS, Kokoro TTS, Chatterbox, OmniVoice, VibeVoice, etc.).

## Prerequisites

- **macOS 13.3+** (Apple Silicon or Intel with Metal support)
- **Xcode 16.0+** with Command Line Tools
- **CMake 3.20+** (`brew install cmake`)

## Building the C++ Library

First, build audio.cpp with the Metal backend:

```sh
# Clone audio.cpp
git clone https://github.com/0xShug0/audio.cpp /tmp/audio-cpp-clone

# Configure and build
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

# Merge static libraries and copy headers
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

## Building the Swift CLI

```sh
xcodebuild \
  -project Qwen3TTSDemo.xcodeproj \
  -scheme Qwen3TTSDemo \
  -configuration Release \
  -derivedDataPath build \
  build
```

The binary is at `build/Build/Products/Release/Qwen3TTSDemo`.

## Preparing Models

### Option A: Use HuggingFace Cache (recommended)

If you already have models cached from HuggingFace (e.g. via `huggingface-cli` or MLX), resolve symlinks first — audio.cpp requires regular files:

```sh
# For Qwen3 TTS 0.6B CustomVoice
rsync -aL ~/.cache/huggingface/hub/models--Qwen--Qwen3-TTS-12Hz-0.6B-CustomVoice/snapshots/<hash>/ /tmp/qwen3_custom_voice/

# For Qwen3 TTS 1.7B Base
rsync -aL ~/.cache/huggingface/hub/models--Qwen--Qwen3-TTS-12Hz-1.7B-Base/snapshots/<hash>/ /tmp/qwen3_base/

# Copy the model spec (required by audio.cpp)
mkdir -p /tmp/qwen3_custom_voice/model_specs
cp /tmp/audio-cpp-clone/model_specs/qwen3_tts.json /tmp/qwen3_custom_voice/model_specs/
```

### Option B: Download with audio.cpp Model Manager

```sh
cd /tmp/audio-cpp-clone
pip install torch safetensors pyyaml
python tools/model_manager.py install qwen3_tts_0_6b_custom_voice --models-dir /tmp/models
python tools/model_manager.py install qwen3_tts_1_7b_base --models-dir /tmp/models
python tools/model_manager.py install qwen3_tts_1_7b_voice_design --models-dir /tmp/models
```

## Usage Examples

### Custom Voice (speaker preset) — Qwen3 CustomVoice 0.6B

Use a built-in speaker preset. No reference audio needed.

```sh
./build/Build/Products/Release/Qwen3TTSDemo custom-voice \
  --model /tmp/qwen3_custom_voice \
  --speaker serena \
  --text "The lighthouse keeper records a detailed morning report about the tide, and the ships crossing the horizon." \
  --out /tmp/serena_output.wav \
  --backend metal \
  --threads 8
```

**Available speakers:** `serena`, `vivian`, `ryan`, `aiden`, `dylan`, `eric`, `ono_anna`, `sohee`, `uncle_fu`

### Custom Voice with style instruction

Add an `--instruct` to guide the delivery style:

```sh
./build/Build/Products/Release/Qwen3TTSDemo custom-voice \
  --model /tmp/qwen3_custom_voice \
  --speaker vivian \
  --instruct "Speak in a cheerful, enthusiastic tone like a morning radio host." \
  --text "Good morning everyone! Today is going to be a wonderful day full of possibilities." \
  --out /tmp/vivian_cheerful.wav \
  --backend metal \
  --threads 8
```

### Voice Clone — Qwen3 Base 0.6B / 1.7B

Clone a voice from a reference audio file:

```sh
./build/Build/Products/Release/Qwen3TTSDemo voice-clone \
  --model /tmp/qwen3_base \
  --voice-ref /path/to/reference_speech.wav \
  --reference-text "The transcript of what is said in the reference audio." \
  --text "This is the new text to synthesize in the cloned voice." \
  --out /tmp/cloned_output.wav \
  --backend metal \
  --threads 8
```

### Voice Design — Qwen3 VoiceDesign 1.7B

Design a voice entirely from a text description:

```sh
./build/Build/Products/Release/Qwen3TTSDemo voice-design \
  --model /tmp/qwen3_voice_design \
  --instruct "A calm, deep male narrator with a warm documentary voice, speaking slowly and clearly." \
  --text "In the vast expanse of the cosmos, a single star can tell a billion stories." \
  --out /tmp/designed_output.wav \
  --backend metal \
  --threads 8
```

## Common Options

| Option | Default | Description |
|--------|---------|-------------|
| `--model <path>` | (required) | Path to the model directory |
| `--text <text>` | (required) | Text to synthesize |
| `--out <path>` | (required) | Output WAV file path |
| `--backend <name>` | `metal` | `metal` or `cpu` |
| `--device <n>` | `0` | GPU device index |
| `--threads <n>` | `8` | CPU worker threads |
| `--language <name>` | `English` | Input text language |
| `--seed <n>` | `1234` | Random seed for reproducibility |
| `--max-new-tokens <n>` | `256` | Maximum output tokens |

## Output Format

All commands produce **16-bit PCM WAV** at **24000 Hz mono**.

## Extending for More Models

audio.cpp supports many model families that can be wired into this bridge:

| Family | Task | Install Package |
|--------|------|-----------------|
| `pocket_tts` | TTS, voice cloning | `pocket_tts` |
| `kokoro_tts` | TTS | `kokoro_82m_bf16` |
| `chatterbox` | TTS, voice cloning, voice conversion | `chatterbox` |
| `omnivoice` | TTS, voice cloning, voice design | `omnivoice` |
| `vibevoice` | TTS, multi-speaker dialogue | `vibevoice_1_5b` |
| `miotts` | TTS, voice cloning | `miotts_1_7b` |
| `outetts` | TTS, voice cloning | `outetts_1_0_1b` |
| `voxcpm2` | TTS, voice cloning, voice design | `voxcpm2` |
| `seed_vc` | Voice conversion | `seed_vc` |
| `qwen3_asr` | Speech recognition | `qwen3_asr_0_6b` |
| `stable_audio` | Music/sound generation | `stable_audio_3_medium` |
| `supertonic` | TTS | `supertonic_3` |

To add a new model family:
1. Add a new method to `MiniTTSDemoBridge.h` / `.mm` mapping the model's request shape
2. Change the `family_hint` in the `init` method (or make it configurable)
3. Add a new command case in `main.swift`

See the [audio.cpp docs](https://github.com/0xShug0/audio.cpp) for per-model API details.

## Troubleshooting

### "Qwen3 custom voice prefill requires speaker"
You're using a CustomVoice model with the `voice-clone` command. Use `custom-voice --speaker <name>` instead.

### "model did not produce audio"
The model variant doesn't match the command. CustomVoice needs `custom-voice`, Base needs `voice-clone`, VoiceDesign needs `voice-design`.

### Metal backend hangs
On some Apple Silicon configurations, the Metal backend may hang after the first inference. Use `--backend cpu` as a fallback. This is a known [audio.cpp issue](https://github.com/0xShug0/audio.cpp/issues).

### HuggingFace symlink errors
audio.cpp's `SafeTensorSource` resolves symlinks via `weakly_canonical`, which breaks with HF cache blob paths. Use `rsync -aL` to create a working copy with resolved symlinks.

### Model spec not found
Copy the model spec from audio.cpp's `model_specs/` directory into `<model_dir>/model_specs/`:

```sh
mkdir -p /path/to/model/model_specs
cp /tmp/audio-cpp-clone/model_specs/qwen3_tts.json /path/to/model/model_specs/
```

## Project Structure

```
.
├── Qwen3TTSDemo/
│   ├── main.swift                     # Swift CLI entry point
│   ├── MiniTTSDemoBridge.h            # ObjC bridge interface
│   ├── MiniTTSDemoBridge.mm           # ObjC++ bridge implementation
│   └── Qwen3TTSDemo-Bridging-Header.h # Swift bridging header
└── Qwen3TTSDemo.xcodeproj/
    └── project.pbxproj                # Xcode project (links libAudioCpp.a)
```

## License

MIT — see the audio.cpp [LICENSE](https://github.com/0xShug0/audio.cpp/blob/main/LICENSE) for the upstream engine.
