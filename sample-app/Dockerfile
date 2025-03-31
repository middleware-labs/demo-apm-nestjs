# Stage 1: Build
FROM node:22.12.0-alpine AS builder

# # Install Python and other necessary dependencies
RUN apk add --no-cache python3 py3-pip make g++ curl

# # Verify installation
RUN python3 --version && pip3 --version

RUN apk add --no-cache build-base

# Set working directory
WORKDIR /app

# Install dependencies
COPY package.json ./
RUN yarn install --ignore-optional

# Copy application files
COPY . .

# Generate Prisma Client and build the NestJS app
# RUN npx prisma generate && yarn build

# Stage 2: Production Image
FROM node:22.12.0-alpine

RUN apk add --no-cache bash curl openssl

# Set working directory
WORKDIR /app

# Copy only necessary files from the build stage
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./
# COPY --from=builder /app/prisma ./prisma

# Expose the application port
EXPOSE 3000


# Run the application
CMD ["yarn", "run", "start:prod"]