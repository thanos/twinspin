# ============================================
# Stage 1: Builder - Compile Elixir application
# ============================================
FROM hexpm/elixir:1.15.7-erlang-26.1.2-alpine-3.18.4 AS builder

# Install build dependencies
RUN apk add --no-cache \
    git \
    build-base \
    nodejs \
    npm \
    postgresql-dev

# Set working directory
WORKDIR /app

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set build environment
ENV MIX_ENV=prod

# Copy mix files and fetch dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod
RUN mix deps.compile

# Copy application code
COPY config config
COPY priv priv
COPY lib lib
COPY assets assets

# Compile assets
RUN mix assets.deploy

# Compile the application
RUN mix compile

# Build the release
RUN mix release

# ============================================
# Stage 2: Runtime - Minimal production image with ODBC drivers
# ============================================
FROM alpine:3.18.4

# Install runtime dependencies and ODBC drivers
RUN apk add --no-cache \
    bash \
    postgresql-client \
    postgresql-libs \
    unixodbc \
    unixodbc-dev \
    curl \
    openssl \
    ncurses-libs \
    libstdc++ \
    libgcc

# Install PostgreSQL ODBC driver
RUN apk add --no-cache postgresql-odbc

# Create app user and directories
RUN adduser -D -u 1000 -h /app app && \
    mkdir -p /app/odbc && \
    chown -R app:app /app

WORKDIR /app

# Copy the release from builder
COPY --from=builder --chown=app:app /app/_build/prod/rel/twinspin ./

# Copy ODBC configuration files
COPY --chown=app:app docker/odbc/odbcinst.ini /etc/odbcinst.ini
COPY --chown=app:app docker/odbc/odbc.ini /app/odbc/odbc.ini

# Copy entrypoint script
COPY --chown=app:app entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Set environment variables
ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    ODBCINI=/app/odbc/odbc.ini \
    ODBCSYSINI=/etc

# Switch to app user
USER app

# Expose Phoenix port
EXPOSE 4000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:4000/ || exit 1

# Run entrypoint script
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["bin/twinspin", "start"]
