# Build stage
FROM node:18-alpine AS builder

# Create a non-root user and group
RUN addgroup -S saleor && adduser -S -G saleor saleor

# Set the working directory and switch to the non-root user
WORKDIR /app
USER saleor

# Copy package files and install dependencies
COPY --chown=saleor:saleor package*.json ./
RUN npm install

# Copy the rest of the application code
COPY --chown=saleor:saleor . .

# Build the application
RUN npm run build

# Serve stage
FROM nginx:stable-alpine

# Copy the built files from the builder stage
COPY --from=builder /app/build /usr/share/nginx/html

# Expose port
EXPOSE 80

# Start the NGINX server
CMD ["nginx", "-g", "daemon off;"]

# Metadata labels
LABEL org.opencontainers.image.title="saleor/saleor-dashboard" \
      org.opencontainers.image.description="A GraphQL-powered, single-page dashboard application for Saleor." \
      org.opencontainers.image.url="https://saleor.io/" \
      org.opencontainers.image.source="https://github.com/saleor/saleor-dashboard" \
      org.opencontainers.image.authors="Saleor Commerce (https://saleor.io)" \
      org.opencontainers.image.licenses="BSD 3"
