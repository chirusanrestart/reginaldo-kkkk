# Chiru Converter

Conversor de mídia para Termux. O Node.js cuida da interface e validação dos parâmetros; o FFmpeg nativo faz o processamento; o shell detecta os encoders disponíveis e escolhe MediaCodec ou CPU.

## Requisitos

- Android com Termux
- Node.js 18 ou superior
- FFmpeg instalado e acessível no PATH

Instalação no Termux:

```bash
pkg update
pkg install nodejs ffmpeg git
git clone https://github.com/chirusanrestart/reginaldo-kkkk.git
cd reginaldo-kkkk
chmod +x ffmpeg.js convert.sh
npm test
```

## Uso

Ver capacidades da build instalada:

```bash
node ffmpeg.js --capabilities
```

Converter para H.264 em 720p:

```bash
node ffmpeg.js entrada.mkv saida.mp4 --codec h264 --resolution 720p --bitrate 2500k --audio-bitrate 128k --engine auto
```

Converter para HEVC usando MediaCodec obrigatoriamente:

```bash
node ffmpeg.js entrada.mp4 saida.mp4 --codec hevc --resolution 1080p --bitrate 3M --engine gpu
```

Converter para AV1 usando um encoder de CPU disponível:

```bash
node ffmpeg.js entrada.mp4 saida.mkv --codec av1 --resolution 720p --bitrate 1500k --engine cpu
```

Remux sem recodificar:

```bash
node ffmpeg.js entrada.mkv saida.mp4 --codec copy
```

Resoluções aceitas: original, 480p, 720p, 1080p, 1440p, 2160p ou dimensões como 1280x720. O redimensionamento preserva a proporção e evita ampliar vídeos menores.

## Aceleração

- `auto`: prefere H.264/HEVC MediaCodec quando o encoder aparece na build; caso contrário usa encoder de CPU.
- `gpu`: exige encoder MediaCodec compatível.
- `cpu`: força encoder de CPU.
- AV1: procura libsvtav1, libaom-av1 ou librav1e. AV1 MediaCodec só será escolhido se a build expuser explicitamente esse encoder.

A listagem de Vulkan é diagnóstica nesta primeira versão. Ter Vulkan funcional no Android não garante que o FFmpeg tenha filtros Vulkan compilados, nem que o pipeline completo evite cópias entre CPU e GPU. A integração Vulkan será adicionada depois de testar os filtros e a transferência de frames no aparelho.

## Limitações da versão inicial

- A conversão de vídeo usa um encoder selecionado por disponibilidade, não benchmark automático.
- O áudio é convertido para AAC durante recodificação.
- O modo `copy` apenas remuxa os streams, sem redimensionar ou alterar bitrate.
- A disponibilidade e as opções de MediaCodec dependem da build do FFmpeg e do Android.

## Testes

```bash
npm test
bash -n convert.sh
node --check ffmpeg.js
``
