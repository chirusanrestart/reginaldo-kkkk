#!/usr/bin/env bash
# Chiru AV1 Converter: software-only AV1 -> H.264/H.265 for GitHub Codespaces
# Requires: ffmpeg + ffprobe. No GPU/hardware acceleration is used.
set -Eeuo pipefail
IFS=$'\n\t'

THREADS=16
THREADS_DEFAULT=16
OUTDIR="converted"
mkdir -p "$OUTDIR"

die() { printf '\n❌ %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "Comando obrigatório não encontrado: $1"; }
ask() { local prompt="$1" default="$2" value; read -r -p "$prompt [$default]: " value; printf '%s' "${value:-$default}"; }
choose() {
  local prompt="$1" default="$2" value
  while true; do
    read -r -p "$prompt [$default]: " value
    value="${value:-$default}"
    if [[ "$value" =~ ^[0-9]+$ ]] && (( value >= 1 && value <= 999999 )); then printf '%s' "$value"; return; fi
    printf 'Digite um número válido.\n'
  done
}

need ffmpeg
need ffprobe
printf '\n🎞️  CHIRU AV1 CONVERTER | CPU only | %s threads detectadas\n' "$THREADS"
printf 'Nada de NVENC, VAAPI ou MediaCodec: decodificação e codificação por software.\nPreset padrão ultrafast para priorizar velocidade; use todos os núcleos detectados como padrão.\n\n'

if (( $# > 0 )); then INPUT="$1"; else read -r -p "Caminho do vídeo de entrada: " INPUT; fi
[[ -f "$INPUT" ]] || die "Arquivo não encontrado: $INPUT"
INPUT="$(realpath "$INPUT")"

printf '\n📋 Informações do arquivo:\n'
ffprobe -v error -show_entries format=duration,size,format_name -of default=noprint_wrappers=1 "$INPUT" || true
printf '\n📺 Streams disponíveis:\n'
ffprobe -v error -show_entries stream=index,codec_type,codec_name,width,height,channels,channel_layout:stream_tags=language,title -of compact=p=0:nk=0 "$INPUT" || true
printf '\n'

OUTBASE="$(basename "${INPUT%.*}")"
read -r -p "Nome do arquivo de saída (sem extensão) [$OUTBASE-convertido]: " OUTNAME
OUTNAME="${OUTNAME:-$OUTBASE-convertido}"
OUTNAME="${OUTNAME//\//_}"

printf '\nCodec de vídeo:\n  1) H.264 / AVC (libx264, maior compatibilidade)\n  2) H.265 / HEVC (libx265, geralmente menor arquivo)\n'
VCODEC="$(choose 'Escolha' 1)"
case "$VCODEC" in
  1) VENC=libx264; VEXT=mkv; DEFAULT_CRF=23; DEFAULT_PRESET=ultrafast ;;
  2) VENC=libx265; VEXT=mkv; DEFAULT_CRF=28; DEFAULT_PRESET=ultrafast ;;
  *) die "Opção de codec inválida." ;;
esac

printf '\nQualidade de vídeo (CRF): valor menor = melhor qualidade e arquivo maior.\n'
if [[ "$VENC" == libx264 ]]; then printf 'Referência H.264: 18 alta, 23 padrão, 28 menor arquivo.\n'; else printf 'Referência H.265: 20 alta, 28 padrão, 32 menor arquivo.\n'; fi
CRF="$(ask 'CRF' "$DEFAULT_CRF")"
[[ "$CRF" =~ ^[0-9]+$ ]] || die "CRF precisa ser número inteiro."
if [[ "$VENC" == libx264 ]]; then (( CRF <= 51 )) || die "CRF do x264 deve ficar entre 0 e 51."; else (( CRF <= 51 )) || die "CRF do x265 deve ficar entre 0 e 51."; fi

printf '\nPresets: ultrafast (velocidade máxima), superfast, veryfast, faster, fast, medium, slow, slower, veryslow\n'
PRESET="$(ask 'Preset' "$DEFAULT_PRESET")"
case "$PRESET" in ultrafast|superfast|veryfast|faster|fast|medium|slow|slower|veryslow) ;; *) die "Preset inválido." ;; esac

printf '\nBitrate de vídeo (opcional). Deixe vazio para usar CRF/qualidade constante. Exemplos: 2500k, 5M\n'
read -r -p 'Bitrate de vídeo: ' VBITRATE
VARGS=(-crf "$CRF")
if [[ -n "$VBITRATE" ]]; then
  [[ "$VBITRATE" =~ ^[0-9]+([.][0-9]+)?[kKmMgG]?$ ]] || die "Bitrate inválido. Exemplo: 2500k ou 5M."
  VARGS=(-b:v "$VBITRATE" -maxrate "$VBITRATE")
  read -r -p 'Buffer de bitrate (vazio = automático): ' VBUF
  [[ -z "$VBUF" ]] || VARGS+=(-bufsize "$VBUF")
fi

printf '\nResolução:\n  1) Manter original\n  2) 1920x1080 (Full HD)\n  3) 1280x720 (HD)\n  4) 854x480\n  5) Informar largura máxima (proporção preservada)\n'
RS="$(choose 'Escolha' 1)"
SCALE=()
case "$RS" in
  1) ;;
  2) SCALE=(-vf 'scale=1920:1080:force_original_aspect_ratio=decrease:force_divisible_by=2') ;;
  3) SCALE=(-vf 'scale=1280:720:force_original_aspect_ratio=decrease:force_divisible_by=2') ;;
  4) SCALE=(-vf 'scale=854:480:force_original_aspect_ratio=decrease:force_divisible_by=2') ;;
  5) W="$(choose 'Largura máxima em pixels' 1280)"; SCALE=(-vf "scale='min($W,iw)':-2") ;;
  *) die "Opção de resolução inválida." ;;
esac

printf '\nÁudio:\n  1) Copiar sem reencodar (rápido, sem perda)\n  2) AAC com bitrate configurável\n  3) Opus com bitrate configurável\n  4) Remover áudio\n'
AC="$(choose 'Escolha' 1)"
AARGS=()
case "$AC" in
  1) AARGS=(-c:a copy) ;;
  2) AB="$(ask 'Bitrate AAC' '192k')"; [[ "$AB" =~ ^[0-9]+([.][0-9]+)?[kKmMgG]?$ ]] || die "Bitrate de áudio inválido."; AARGS=(-c:a aac -b:a "$AB") ;;
  3) AB="$(ask 'Bitrate Opus' '128k')"; [[ "$AB" =~ ^[0-9]+([.][0-9]+)?[kKmMgG]?$ ]] || die "Bitrate de áudio inválido."; AARGS=(-c:a libopus -b:a "$AB") ;;
  4) AARGS=(-an) ;;
  *) die "Opção de áudio inválida." ;;
esac

printf '\nLegendas:\n  1) Copiar todas as legendas (recomendado com MKV)\n  2) Escolher uma stream de legenda\n  3) Não incluir legendas\n'
SC="$(choose 'Escolha' 1)"
SARGS=()
case "$SC" in
  1) SARGS=(-map '0:s?' -c:s copy) ;;
  2)
    mapfile -t SUBS < <(ffprobe -v error -select_streams s -show_entries stream=index -of csv=p=0 "$INPUT")
    (("${#SUBS[@]}" > 0)) || die "Este arquivo não tem streams de legenda."
    printf 'Índices de legenda disponíveis: %s\n' "${SUBS[*]}"
    SI="$(choose 'Índice global da legenda' "${SUBS[0]}")"
    FOUND=0; for x in "${SUBS[@]}"; do [[ "$x" == "$SI" ]] && FOUND=1; done
    (( FOUND == 1 )) || die "Esse índice não é uma stream de legenda."
    SARGS=(-map "0:$SI" -c:s copy)
    ;;
  3) SARGS=(-sn) ;;
  *) die "Opção de legenda inválida." ;;
esac

printf '\nOutras opções:\n'
FPS="$(ask 'Limitar FPS (vazio = manter original)' '')"
EXTRA=()
if [[ -n "$FPS" ]]; then [[ "$FPS" =~ ^[0-9]+([.][0-9]+)?$ ]] || die "FPS inválido."; EXTRA+=(-r "$FPS"); fi
PIX="$(ask 'Formato de pixel (yuv420p é mais compatível)' 'yuv420p')"
[[ "$PIX" =~ ^[A-Za-z0-9_]+$ ]] || die "Formato de pixel inválido."
THREADS=16
printf "Threads fixas no código: %s\\n" "$THREADS"

OUTPUT="$OUTDIR/$OUTNAME.$VEXT"
[[ ! -e "$OUTPUT" ]] || { read -r -p "Arquivo já existe. Sobrescrever? [s/N]: " OW; [[ "$OW" =~ ^[sS]$ ]] || die "Cancelado."; }
printf '\n🧾 Resumo:\nEntrada: %s\nSaída: %s\nVídeo: %s | threads: %s | preset: %s | %s\nÁudio: opção %s | Legendas: opção %s\n\n' "$INPUT" "$OUTPUT" "$VENC" "$THREADS" "$PRESET" "${VARGS[*]}" "$AC" "$SC"
read -r -p 'Iniciar conversão? [S/n]: ' CONFIRM
[[ -z "$CONFIRM" || "$CONFIRM" =~ ^[sS]$ ]] || die "Conversão cancelada."

# Map video and optional data/attachments. Explicitly map first video stream.
ffmpeg -hide_banner -y -i "$INPUT" \
  -map 0:v:0 -map '0:d?' \
  "${SARGS[@]}" \
  -c:v "$VENC" -preset "$PRESET" "${VARGS[@]}" \
  -pix_fmt "$PIX" -threads "$THREADS" -filter_threads "$THREADS" \
  "${SCALE[@]}" "${EXTRA[@]}" \
  "${AARGS[@]}" \
  -map_metadata 0 -map_chapters 0 \
  -max_muxing_queue_size 2048 \
  -progress pipe:1 -stats_period 2 \
  "$OUTPUT"

printf '\n✅ Conversão concluída!\n'
printf 'Arquivo: %s\n' "$(realpath "$OUTPUT")"
ls -lh "$OUTPUT"
printf '\nVerificação rápida de streams:\n'
ffprobe -v error -show_entries stream=index,codec_type,codec_name,width,height,channels:stream_tags=language,title -of compact=p=0 "$OUTPUT" || true
