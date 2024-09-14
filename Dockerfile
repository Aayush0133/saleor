### Build and install packages
FROM python:3.12-slim AS build-python

# Create a non-root user
RUN groupadd -r saleor && useradd -r -g saleor saleor

# Set work directory
WORKDIR /app

# Install apt dependencies for Pillow and others
RUN apt-get update \
  && apt-get install -y gettext libffi-dev libgdk-pixbuf2.0-dev liblcms2-dev \
     libopenjp2-7-dev libssl-dev libtiff-dev libwebp-dev libpq-dev \
     shared-mime-info mime-support \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt ./  # Copy the requirements first to cache dependencies
RUN --mount=type=cache,mode=0755,target=/root/.cache/pip pip install --no-cache-dir -r requirements.txt

# Copy the application code
COPY . .

# Change ownership of the directory
RUN chown -R saleor:saleor /app

# Run as non-root user
USER saleor

### Final stage: Minimal production image
FROM python:3.12-slim

# Create the non-root user again
RUN groupadd -r saleor && useradd -r -g saleor saleor

# Set work directory
WORKDIR /app

# Install Pillow and other dependencies (repeat in final stage)
RUN apt-get update \
  && apt-get install -y libffi8 libgdk-pixbuf2.0-0 liblcms2-2 \
     libopenjp2-7 libssl3 libtiff6 libwebp7 libpq5 \
     shared-mime-info mime-support \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# Copy the built Python packages and code from the build stage
COPY --from=build-python /usr/local/lib/python3.12/site-packages/ /usr/local/lib/python3.12/site-packages/
COPY --from=build-python /usr/local/bin/ /usr/local/bin/
COPY . /app

# Set permissions for media and static folders
RUN mkdir -p /app/media /app/static \
  && chown -R saleor:saleor /app/

# Collect static files
ARG STATIC_URL
ENV STATIC_URL=${STATIC_URL:-/static/}
RUN SECRET_KEY=dummy STATIC_URL=${STATIC_URL} python3 manage.py collectstatic --no-input

# Expose port
EXPOSE 8000

# Run as non-root user
USER saleor

# Set command to run gunicorn with UvicornWorker
CMD ["gunicorn", "--bind", ":8000", "--workers", "4", "--worker-class", "saleor.asgi.gunicorn_worker.UvicornWorker", "saleor.wsgi"]

# Metadata labels
LABEL org.opencontainers.image.title="saleor/saleor" \
      org.opencontainers.image.description="A modular, high performance, headless e-commerce platform built with Python, GraphQL, Django, and ReactJS." \
      org.opencontainers.image.url="https://saleor.io/" \
      org.opencontainers.image.source="https://github.com/saleor/saleor" \
      org.opencontainers.image.authors="Saleor Commerce (https://saleor.io)" \
      org.opencontainers.image.licenses="BSD 3"
