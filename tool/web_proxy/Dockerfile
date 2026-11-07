# Wisp relay for Collider's in-app browser (Scramjet). Build context: tool/web_proxy.
FROM node:22-alpine
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY wisp_server.mjs ./
ENV HOST=0.0.0.0 \
    PORT=8080 \
    ALLOWED_ORIGINS=https://davidebri1.github.io
EXPOSE 8080
USER node
CMD ["node", "wisp_server.mjs"]
