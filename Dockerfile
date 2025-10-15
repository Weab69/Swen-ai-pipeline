# Use Node.js 18 Alpine as base image
FROM node:24-alpine3.21

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy source code
COPY . .

# Install NestJS CLI globally
RUN npm install -g @nestjs/cli

RUN npm install

# Build the application
RUN npm run build

# Expose port
EXPOSE 3000

# Default command (will be overridden by docker-compose)
CMD ["npm", "run", "start:prod"]
