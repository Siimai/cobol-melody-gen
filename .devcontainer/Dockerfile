# The published "mainframe" variant of Siimai/claude-devcontainer already has
# git, Python, Node, gh, Claude Code, GnuCOBOL + make, s3270 and netcat.
# Pinned to a commit so a rebuild does not change underneath us.
FROM ghcr.io/siimai/claude-devcontainer/mainframe:sha-27cf63aef772bd46176861cc920944acbbf4cbde

USER root

# Only for the demo video (mvs/demo): ffmpeg and the Fira Code and Inter fonts
RUN apt-get update && apt-get install -y --no-install-recommends \
      ffmpeg fontconfig fonts-firacode fonts-inter \
    && fc-cache -f \
    && rm -rf /var/lib/apt/lists/*

# Playwright + Chromium for mvs/demo/render.js (browsers in a shared path so
# the ubuntu user can use them; NODE_PATH lets the script find the global module)
ENV PLAYWRIGHT_BROWSERS_PATH=/opt/playwright-browsers
ENV NODE_PATH=/usr/local/lib/node_modules
RUN npm install -g playwright \
    && playwright install --with-deps chromium \
    && chmod -R a+rX /opt/playwright-browsers \
    && rm -rf /var/lib/apt/lists/*

USER ubuntu
