FROM node:20-slim

RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm install

RUN npx playwright install chromium --with-deps

COPY tsconfig.json ./
COPY src/ ./src/

RUN mkdir -p /app/data

EXPOSE 3000

CMD ["npx", "tsx", "src/server.ts"]
