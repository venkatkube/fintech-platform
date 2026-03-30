# Use lightweight base image
FROM node:18-alpine

# Create non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copy only dependency files first (better caching)
COPY package*.json ./

# Install only production deps
RUN npm ci --only=production

# Copy app source
COPY . .

# Set ownership
RUN chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 3000

# Healthcheck (basic)
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s \
  CMD wget -qO- http://localhost:3000/ || exit 1

CMD ["node", "index.js"]