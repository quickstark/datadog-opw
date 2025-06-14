# OPW Configuration Directory

This directory contains configuration files for the Datadog Observability Pipelines Worker (OPW).

## Purpose

The OPW configuration files placed in this directory will be copied to the Synology NAS at `/volume1/docker/datadog-opw/` during deployment. This allows you to customize the OPW behavior beyond the default environment variables.

## Supported Configuration Files

- `*.yaml` - YAML configuration files for OPW pipelines
- `*.yml` - YAML configuration files (alternative extension)
- Custom pipeline configurations
- Transform configurations
- Sink configurations

## Environment Variables

The following environment variables are configured automatically during deployment:

- `DD_OPW_API_KEY` - Your Datadog API key for OPW authentication
- `DD_OP_PIPELINE_ID` - Your Observability Pipelines pipeline ID
- `DD_SITE` - Datadog site (datadoghq.com)
- `DD_OP_SOURCE_DATADOG_AGENT_ADDRESS` - Address for receiving logs from Agent (0.0.0.0:8282)
- `DD_OP_CONFIG_SOURCE` - Configuration source (datadog)
- `DD_LOG_LEVEL` - Log level (debug)
- `RUST_LOG` - Rust logging configuration
- `DD_OP_API_ENABLED` - Enable OPW API (true)
- `DD_OP_API_ADDRESS` - OPW API address (0.0.0.0:8686)

## Usage

1. Add your custom configuration files to this directory
2. Run the deployment script: `./scripts/deploy.sh`
3. The configuration files will be validated and copied during deployment
4. OPW will be restarted with the new configuration

## Example Configuration

Here's an example of what you might put in this directory:

```yaml
# pipeline.yaml - Custom pipeline configuration
sources:
  agent:
    type: datadog_agent
    address: 0.0.0.0:8282

transforms:
  parse_logs:
    type: remap
    inputs:
      - agent
    source: |
      . = parse_json!(.message)

sinks:
  datadog:
    type: datadog_logs
    inputs:
      - parse_logs
    default_api_key: "${DD_OPW_API_KEY}"
    site: "${DD_SITE}"
```

## Validation

All YAML files in this directory are automatically validated during the GitHub Actions workflow. Invalid YAML will cause the deployment to fail.

## Notes

- Configuration files are copied with read-only permissions
- Environment variable substitution is supported using `${VARIABLE_NAME}` syntax
- The OPW container runs as a non-root user for security
- Logs are available via `docker logs dd-opw` on the Synology NAS 