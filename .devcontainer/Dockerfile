FROM ubuntu:26.04

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl git openssh-client less ripgrep jq \
      python3 python3-pip nodejs npm csound sox supercollider ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Media tooling and fonts (separate layer so the layer above stays cached)
RUN apt-get update && apt-get install -y --no-install-recommends \
      imagemagick tesseract-ocr librsvg2-bin libcairo2 fontconfig \
      fonts-inter fonts-roboto fonts-noto-core fonts-noto-color-emoji \
      fonts-firacode fonts-liberation2 fonts-dejavu-core fonts-open-sans \
      fonts-lato fonts-montserrat fonts-ibm-plex \
    && fc-cache -f \
    && rm -rf /var/lib/apt/lists/*

# Playwright + Chromium (browsers in a shared path so the ubuntu user can use them)
ENV PLAYWRIGHT_BROWSERS_PATH=/opt/playwright-browsers
RUN npm install -g playwright \
    && playwright install --with-deps chromium \
    && chmod -R a+rX /opt/playwright-browsers \
    && rm -rf /var/lib/apt/lists/*

# Python libraries for media work (PEP 668: system pip needs the override flag)
RUN pip3 install --no-cache-dir --break-system-packages \
      pillow numpy librosa moviepy cairosvg pytesseract

# Remotion + GSAP (global; NODE_PATH lets scripts outside a project resolve them)
ENV NODE_PATH=/usr/local/lib/node_modules
RUN npm install -g remotion @remotion/cli @remotion/renderer @remotion/bundler react react-dom gsap

# Stable path to Playwright's Chromium (its real path is versioned) for Remotion
RUN ln -s "$(node -e "console.log(require('playwright').chromium.executablePath())")" /usr/local/bin/chromium-playwright \
    && test -x /usr/local/bin/chromium-playwright

# Cobol compiler: GnuCOBOL (provides cobc) and make, needed to build the
# project's Makefile. Kept after the other apt layers so they stay cached.
RUN apt-get update && apt-get install -y --no-install-recommends \
      gnucobol make \
    && rm -rf /var/lib/apt/lists/*

# Scripted 3270 client (s3270) and netcat (card reader) for the Hercules/TK4- mainframe, which runs on
# the Docker host (reachable at 172.17.0.1:3270, not localhost). Kept after the
# other apt layers so they stay cached.
RUN apt-get update && apt-get install -y --no-install-recommends \
      s3270 netcat-openbsd \
    && rm -rf /var/lib/apt/lists/* \
    && command -v s3270 nc

# GitHub CLI (gh) for issues and pull requests. Kept after the other apt layers
# so they stay cached.
RUN apt-get update && apt-get install -y --no-install-recommends \
      gh \
    && rm -rf /var/lib/apt/lists/* \
    && command -v gh

# Ubuntu images already include a non-root user "ubuntu" (UID 1000)
USER ubuntu
ENV PATH="/home/ubuntu/.local/bin:${PATH}"

# Pre-create the config dirs so the named volumes inherit correct ownership
# (~/.config/gh holds the gh login)
RUN mkdir -p /home/ubuntu/.claude /home/ubuntu/.config/gh

# Install Claude Code (native installer)
RUN curl -fsSL https://claude.ai/install.sh | bash

WORKDIR /workspace
