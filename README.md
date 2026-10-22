# Chiru AV1 Converter 🎞️

Script interativo em Bash para converter vídeos usando FFmpeg, com foco em conversão por software de AV1 para H.264 (AVC) ou H.265 (HEVC). Permite ajustar qualidade, preset, resolução, áudio e legendas.

## ✨ Funcionalidades

- 🎬 Conversão para H.264 ou H.265
- ⚙️ Ajuste de qualidade por CRF ou bitrate
- 📐 Opções de resolução, incluindo manter a original
- 🔊 Opções para copiar, converter ou remover áudio
- 💬 Opções para preservar ou selecionar legendas
- 🧾 Exibe informações do arquivo usando FFprobe
- 📁 Salva os arquivos convertidos na pasta `converted/`
- 🖥️ Codificação por CPU, sem depender de aceleração por GPU

## 📋 Requisitos

- Bash
- FFmpeg com os codificadores `libx264` e/ou `libx265`
- FFprobe
- `realpath`

## 🚀 Instalação

Clone o repositório:

```bash
git clone https://github.com/chirusanrestart/reginaldo-kkkk.git
cd reginaldo-kkkk
chmod +x av1-converter.sh
```

Instale FFmpeg e FFprobe usando o gerenciador de pacotes do seu sistema. No Termux, por exemplo:

```bash
pkg install ffmpeg
```

## ▶️ Uso

Execute o script:

```bash
./av1-converter.sh
```

Também é possível fornecer o caminho do vídeo como argumento:

```bash
./av1-converter.sh "/caminho/para/video.mkv"
```

O script faz perguntas sobre o nome de saída, codec, qualidade, preset, resolução, áudio e legendas antes de começar a conversão. Os arquivos resultantes são colocados em `converted/`.

## 🎚️ Dicas de qualidade

- **CRF menor:** geralmente significa maior qualidade e arquivo maior.
- **CRF maior:** geralmente significa arquivo menor, com mais perda de qualidade.
- **Preset mais rápido:** reduz o tempo de conversão, mas pode gerar arquivos maiores para uma qualidade semelhante.
- **H.264:** costuma ter ampla compatibilidade com aparelhos e aplicativos.
- **H.265:** pode reduzir o tamanho do arquivo, mas depende do suporte do dispositivo de reprodução.

A velocidade depende do processador, da resolução, da duração e das opções escolhidas. A conversão por CPU pode ser demorada em aparelhos modestos.

## ⚠️ Observações

- Faça uma cópia do vídeo original antes de conversões importantes.
- Confira se há espaço livre suficiente para os arquivos de saída.
- O contêiner de saída usado pelo script é MKV.
- Nem todas as faixas ou formatos de legenda são compatíveis com todas as combinações de codec e contêiner.

## 👩‍💻 Projeto

Ferramenta pessoal desenvolvida por **Chiru-san**.
