# ---- Build Stage ----
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files and install only production deps
COPY package*.json ./
RUN npm ci --only=production

# ---- Production Stage ----
FROM node:18-alpine

# Create a non-root user for security
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copy node_modules from builder
COPY --from=builder /app/node_modules ./node_modules

# Copy application source
COPY . .

# Remove dev/sensitive files if present
RUN rm -f .env

# Set ownership
RUN chown -R appuser:appgroup /app

USER appuser

EXPOSE 8080

ENV NODE_ENV=production

CMD ["node", "index.js"]
