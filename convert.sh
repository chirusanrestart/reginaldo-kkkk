#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

has_encoder() {
  ffmpeg -hide_banner -encoders 2>/dev/null | awk '{print $2}' | grep -Fxq "$1"
}

capabilities() {
  echo "=== Chiru Converter: capacidades do FFmpeg ==="
  ffmpeg -version | head -n 2
  echo
  echo "Aceleradores:"
  ffmpeg -hide_banner -hwaccels 2>/dev/null | sed '1d' | sed 's/^/  /'
  echo
  echo "Encoders de vídeo relevantes:"
  ffmpeg -hide_banner -encoders 2>/dev/null | grep -E '264|265|hevc|av1|vp9|mediacodec' || true
  echo
  echo "Decoders MediaCodec:"
  ffmpeg -hide_banner -decoders 2>/dev/null | grep -i mediacodec || true
  echo
  echo "Filtros Vulkan:"
  ffmpeg -hide_banner -filters 2>/dev/null | grep -i vulkan || true
  echo
  echo "Vulkan listado não significa que todo o pipeline esteja acelerado."
}

if [[ "${1:-}" == "--capabilities" ]]; then
  command -v ffmpeg >/dev/null 2>&1 || { echo "FFmpeg não encontrado. Instale com: pkg install ffmpeg" >&2; exit 127; }
  capabilities
  exit 0
fi

if [[ $# -ne 7 ]]; then
  echo "Uso interno inválido. Execute: node ffmpeg.js --help" >&2
  exit 2
fi

INPUT=$1
OUTPUT=$2
CODEC=$3
RESOLUTION=$4
VIDEO_BITRATE=$5
AUDIO_BITRATE=$6
ENGINE=$7

command -v ffmpeg >/dev/null 2>&1 || { echo "FFmpeg não encontrado. Instale com: pkg install ffmpeg" >&2; exit 127; }
[[ -f "$INPUT" ]] || { echo "Arquivo de entrada não encontrado: $INPUT" >&2; exit 2; }
[[ "$INPUT" != "$OUTPUT" ]] || { echo "Entrada e saída precisam ser arquivos diferentes." >&2; exit 2; }

FILTER_ARGS=()
case "$RESOLUTION" in
  original) ;;
  480p) FILTER_ARGS=(-vf "scale=w='min(854,iw)':h='min(480,ih)':force_original_aspect_ratio=decrease:force_divisible_by=2") ;;
  720p) FILTER_ARGS=(-vf "scale=w='min(1280,iw)':h='min(720,ih)':force_original_aspect_ratio=decrease:force_divisible_by=2") ;;
  1080p) FILTER_ARGS=(-vf "scale=w='min(1920,iw)':h='min(1080,ih)':force_original_aspect_ratio=decrease:force_divisible_by=2") ;;
  1440p) FILTER_ARGS=(-vf "scale=w='min(2560,iw)':h='min(1440,ih)':force_original_aspect_ratio=decrease:force_divisible_by=2") ;;
  2160p) FILTER_ARGS=(-vf "scale=w='min(3840,iw)':h='min(2160,ih)':force_original_aspect_ratio=decrease:force_divisible_by=2") ;;
  *x*)
    WIDTH=${RESOLUTION%x*}
    HEIGHT=${RESOLUTION#*x}
    FILTER_ARGS=(-vf "scale=w='min($WIDTH,iw)':h='min($HEIGHT,ih)':force_original_aspect_ratio=decrease:force_divisible_by=2")
    ;;
  *) echo "Resolução não suportada: $RESOLUTION" >&2; exit 2 ;;
esac

if [[ "$CODEC" == "copy" ]]; then
  [[ "$RESOLUTION" == "original" ]] || { echo "Codec copy não permite redimensionamento." >&2; exit 2; }
  echo "Remux sem recodificação..."
  exec ffmpeg -hide_banner -y -i "$INPUT" -map 0 -c copy "$OUTPUT"
fi

ENCODER=""
CPU_ENCODER=""
case "$CODEC" in
  h264)
    CPU_ENCODER=libx264
    if [[ "$ENGINE" != "cpu" ]] && has_encoder h264_mediacodec; then ENCODER=h264_mediacodec
    elif [[ "$ENGINE" == "gpu" ]]; then echo "Encoder H.264 MediaCodec não está disponível nesta build." >&2; exit 3
    elif has_encoder libx264; then ENCODER=libx264
    else echo "Nenhum encoder H.264 compatível encontrado." >&2; exit 3
    fi
    ;;
  hevc)
    CPU_ENCODER=libx265
    if [[ "$ENGINE" != "cpu" ]] && has_encoder hevc_mediacodec; then ENCODER=hevc_mediacodec
    elif [[ "$ENGINE" == "gpu" ]]; then echo "Encoder HEVC MediaCodec não está disponível nesta build." >&2; exit 3
    elif has_encoder libx265; then ENCODER=libx265
    else echo "Nenhum encoder HEVC compatível encontrado." >&2; exit 3
    fi
    ;;
  av1)
    if [[ "$ENGINE" != "cpu" ]] && has_encoder av1_mediacodec; then ENCODER=av1_mediacodec
    elif [[ "$ENGINE" == "gpu" ]]; then echo "Encoder AV1 MediaCodec não está disponível nesta build." >&2; exit 3
    elif has_encoder libsvtav1; then ENCODER=libsvtav1
    elif has_encoder libaom-av1; then ENCODER=libaom-av1
    elif has_encoder librav1e; then ENCODER=librav1e
    else echo "Nenhum encoder AV1 compatível encontrado." >&2; exit 3
    fi
    ;;
  *) echo "Codec inválido: $CODEC" >&2; exit 2 ;;
esac

if [[ "$ENGINE" == "gpu" && "$ENCODER" != *mediacodec ]]; then
  echo "Não foi possível selecionar um encoder MediaCodec." >&2
  exit 3
fi

build_encoder_args() {
  ENCODER_ARGS=(-c:v "$ENCODER" -b:v "$VIDEO_BITRATE")
  case "$ENCODER" in
    libx264) ENCODER_ARGS+=(-preset veryfast) ;;
    libx265) ENCODER_ARGS+=(-preset ultrafast) ;;
    libsvtav1) ENCODER_ARGS+=(-preset 10) ;;
    libaom-av1) ENCODER_ARGS+=(-cpu-used 8) ;;
    librav1e) ENCODER_ARGS+=(-speed 10) ;;
  esac
}

AUDIO_ARGS=(-c:a aac -b:a "$AUDIO_BITRATE")
OUTPUT_ARGS=()
EXTENSION="${OUTPUT##*.}"
EXTENSION="${EXTENSION,,}"
if [[ "$EXTENSION" == "webm" ]]; then
  has_encoder libopus || { echo "Esta build não possui libopus para saída WebM." >&2; exit 3; }
  AUDIO_ARGS=(-c:a libopus -b:a "$AUDIO_BITRATE")
elif [[ "$EXTENSION" == "mp4" || "$EXTENSION" == "m4v" || "$EXTENSION" == "mov" ]]; then
  OUTPUT_ARGS=(-movflags +faststart)
fi

build_encoder_args
echo "Entrada: $INPUT"
echo "Saída:   $OUTPUT"
echo "Codec:   $CODEC ($ENCODER)"
echo "Tamanho: $RESOLUTION"
echo "Bitrate: vídeo=$VIDEO_BITRATE áudio=$AUDIO_BITRATE"
echo "Motor:   $([[ "$ENCODER" == *mediacodec ]] && echo MediaCodec || echo CPU)"
echo

run_conversion() {
  ffmpeg -hide_banner -y -i "$INPUT" \
    "${FILTER_ARGS[@]}" \
    "${ENCODER_ARGS[@]}" \
    "${AUDIO_ARGS[@]}" \
    -map 0:v:0 -map '0:a?' \
    "${OUTPUT_ARGS[@]}" \
    "$OUTPUT"
}

if ! run_conversion; then
  if [[ "$ENGINE" == "auto" && "$ENCODER" == *mediacodec ]]; then
    echo
    echo "MediaCodec falhou neste arquivo. Tentando encoder de CPU..."
    rm -f "$OUTPUT"
    case "$CODEC" in
      h264) has_encoder libx264 && ENCODER=libx264 ;;
      hevc) has_encoder libx265 && ENCODER=libx265 ;;
      av1)
        if has_encoder libsvtav1; then ENCODER=libsvtav1
        elif has_encoder libaom-av1; then ENCODER=libaom-av1
        elif has_encoder librav1e; then ENCODER=librav1e
        fi
        ;;
    esac
    if [[ -z "$ENCODER" ]]; then
      echo "Fallback de CPU indisponível para $CODEC." >&2
      exit 4
    fi
    build_encoder_args
    run_conversion
  else
    exit 4
  fi
fi

echo
echo "Conversão concluída: $OUTPUT"
