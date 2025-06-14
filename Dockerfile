FROM datadog/observability-pipelines-worker:latest

# Metadata
LABEL maintainer="Dirk <dirk@quickstark.com>"
LABEL description="Datadog Observability Pipelines Worker"
LABEL version="1.0"

# Create configuration directory
RUN mkdir -p /etc/datadog-opw

# Copy any custom configuration files if they exist
# COPY opw-config/ /etc/datadog-opw/

# Set environment variables with defaults
ENV DD_SITE=datadoghq.com
ENV PUID=1026
ENV PGID=100
ENV DD_OP_SOURCE_DATADOG_AGENT_ADDRESS=0.0.0.0:8282
ENV DD_OP_CONFIG_SOURCE=datadog
ENV DD_LOG_LEVEL=info
ENV RUST_LOG=info,observability_pipelines_worker=debug,vector=debug
ENV DD_OP_API_ENABLED=true
ENV DD_OP_API_ADDRESS=0.0.0.0:8686

# Create user for running the service
RUN groupadd -r datadog-opw && useradd -r -g datadog-opw datadog-opw

# Create data directory and set permissions
RUN mkdir -p /var/lib/datadog/observability-pipelines-worker && \
    chown -R datadog-opw:datadog-opw /var/lib/datadog/observability-pipelines-worker

# Expose ports for OPW
EXPOSE 8282/tcp 8686/tcp

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8686/health || exit 1

# Use the default command from the base image but ensure it runs as the correct user
USER datadog-opw

# Default command (can be overridden)
CMD ["run"] 