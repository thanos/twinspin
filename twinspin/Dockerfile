# Build stage
FROM hexpm/elixir:1.15.7-erlang-26.1.2-alpine-3.18.4 AS builder

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    git \
    nodejs \
    npm

# Set build ENV
ENV MIX_ENV=prod

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Create app directory
WORKDIR /app

# Copy mix files
COPY mix.exs mix.lock ./

# Install mix dependencies
RUN mix deps.get --only prod && \
    mix deps.compile

# Copy config files
COPY config/config.exs config/prod.exs config/runtime.exs config/

# Copy assets
COPY assets assets
COPY priv priv

# Compile assets
RUN mix assets.deploy

# Copy application code
COPY lib lib

# Compile and build release
RUN mix compile && \
    mix phx.gen.release && \
    mix release

# Runtime stage
FROM alpine:3.18.4

# Install runtime dependencies
RUN apk add --no-cache \
    libstdc++ \
    openssl \
    ncurses-libs \
    postgresql-client

# Create app user (for rootless compatibility)
RUN addgroup -g 1000 app && \
    adduser -D -u 1000 -G app app

# Set work directory
WORKDIR /app

# Copy release from builder
COPY --from=builder --chown=app:app /app/_build/prod/rel/twinspin ./

# Create directories for runtime
RUN mkdir -p /app/tmp && \
    chown -R app:app /app

# Switch to app user
USER app

# Set environment
ENV HOME=/app \
    MIX_ENV=prod \
    PORT=4000 \
    PHX_SERVER=true

# Expose port
EXPOSE 4000

# Copy entrypoint script
COPY --chown=app:app entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s \
  CMD wget --no-verbose --tries=1 --spider http://localhost:4000/ || exit 1

# Start the application
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["/app/bin/twinspin", "start"]
