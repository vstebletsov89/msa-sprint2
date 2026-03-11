
FROM node:18-alpine AS builder

WORKDIR /app

COPY package.json ./
RUN npm install --omit=dev

FROM node:18-alpine

RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

COPY --from=builder /app/node_modules ./node_modules
COPY package.json ./
COPY index.js ./

USER appuser

EXPOSE 4000

CMD ["node", "index.js"]