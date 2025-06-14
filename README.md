# Datadog Agent & OPW Deployment

A complete automated deployment solution for Datadog Agent and Observability Pipelines Worker (OPW) on Synology NAS using GitHub Actions.

## 🚀 Features

- **Dual Container Deployment**: Datadog Agent + Observability Pipelines Worker
- **Automated CI/CD**: GitHub Actions for building and deployment
- **Synology NAS Optimized**: Designed for DS923+ and compatible models
- **Custom Configuration**: Support for custom OPW pipelines and Agent configs
- **Health Monitoring**: Built-in health checks and deployment tracking
- **Docker Hub Integration**: Automated image building and registry push

## 📋 Architecture

```
┌─────────────────┐    Port 8282    ┌──────────────────┐
│  Datadog Agent  │ ─────────────► │       OPW        │
│   (dd-agent)    │                │    (dd-opw)      │
│                 │                │                  │
│ • Host metrics  │                │ • Log processing │
│ • Container mon │                │ • Data pipelines │
│ • SNMP polling  │                │ • API (Port 8686)│
└─────────────────┘                └──────────────────┘
                                             │
                                             ▼
                                   ┌─────────────────┐
                                   │  Datadog Cloud  │
                                   └─────────────────┘
```

## 🛠 Prerequisites

### Required Tools
- [GitHub CLI](https://cli.github.com/) (`gh`) for secrets management
- [Docker Hub Account](https://hub.docker.com/) for image registry
- SSH access to your Synology NAS

### Synology Requirements
- Synology DS923+ (or compatible AMD64 model)
- Docker package installed
- SSH enabled
- Sufficient storage for containers and logs

## 📦 Quick Start

### 1. Clone and Setup

```bash
git clone https://github.com/quickstark/datadog-opw.git
cd datadog-opw
```

### 2. Environment Configuration

Create a `.env` file with your secrets:

```bash
# Datadog Configuration
DD_API_KEY=your_datadog_api_key_here
DD_OPW_API_KEY=your_opw_api_key_here
DD_OP_PIPELINE_ID=your_pipeline_id_here

# Infrastructure Secrets
DOCKERHUB_USER=your_dockerhub_username
DOCKERHUB_TOKEN=your_dockerhub_access_token
SYNOLOGY_HOST=192.168.1.100
SYNOLOGY_SSH_PORT=22
SYNOLOGY_USER=your_ssh_username
SYNOLOGY_SSH_KEY="-----BEGIN OPENSSH PRIVATE KEY-----
your_private_key_content_here
-----END OPENSSH PRIVATE KEY-----"
```

### 3. Deploy

```bash
# Upload secrets to GitHub and deploy
./scripts/deploy.sh
```

This will:
- ✅ Validate your configuration
- ✅ Upload secrets to GitHub repository
- ✅ Trigger GitHub Actions workflow
- ✅ Build custom Docker images
- ✅ Deploy to your Synology NAS
- ✅ Verify health checks

## 📁 Project Structure

```
datadog-opw/
├── .github/workflows/
│   └── deploy.yaml              # GitHub Actions CI/CD pipeline
├── scripts/
│   ├── deploy.sh               # Main deployment script
│   └── setup-secrets.sh        # GitHub secrets management
├── opw-config/                 # OPW configuration files
│   └── README.md               # Configuration documentation
├── Dockerfile                  # OPW custom image
└── opw-config/                # OPW configuration files
```

## 🔧 Configuration Files

### Agent Configuration
The Datadog Agent is configured entirely through environment variables in the deployment. No custom configuration files are needed.

### OPW Custom Pipelines
Add custom configurations to `opw-config/`:

```yaml
# opw-config/custom-pipeline.yaml
sources:
  agent:
    type: datadog_agent
    address: 0.0.0.0:8282

transforms:
  parse_logs:
    type: remap
    inputs: [agent]
    source: |
      . = parse_json!(.message)

sinks:
  datadog:
    type: datadog_logs
    inputs: [parse_logs]
    default_api_key: "${DD_OPW_API_KEY}"
    site: "${DD_SITE}"
```

## 🔐 Secrets Management

The project uses GitHub repository secrets for secure deployment:

### Required Secrets
- `DD_API_KEY` - Datadog API key for Agent
- `DD_OPW_API_KEY` - Datadog API key for OPW  
- `DD_OP_PIPELINE_ID` - Observability Pipelines pipeline ID
- `DOCKERHUB_USER` - Docker Hub username
- `DOCKERHUB_TOKEN` - Docker Hub access token
- `SYNOLOGY_HOST` - Synology NAS IP address
- `SYNOLOGY_SSH_PORT` - SSH port (usually 22)
- `SYNOLOGY_USER` - SSH username
- `SYNOLOGY_SSH_KEY` - SSH private key

### Manual Setup
Secrets are automatically uploaded by the deployment script, but SSH keys may need manual setup:

1. Go to your repository settings: `https://github.com/YOUR_USERNAME/datadog-opw/settings/secrets/actions`
2. Add `SYNOLOGY_SSH_KEY` with your full private key content

## 📊 Monitoring & Verification

### Service Endpoints
- **Agent Status**: `http://your-synology:5002/status`
- **OPW Health**: `http://your-synology:8686/health`
- **OPW Log Intake**: `http://your-synology:8282` (internal)

### Container Management
```bash
# SSH to your Synology NAS
ssh user@your-synology

# Check running containers
docker ps | grep -E "(dd-agent|dd-opw)"

# View logs
docker logs dd-agent
docker logs dd-opw

# Check agent status
docker exec dd-agent datadog-agent status

# Check OPW health
curl http://localhost:8686/health
```

## 🚨 Troubleshooting

### Common Issues

**Build Failures**
- Check GitHub Actions logs for specific errors
- Verify all required files exist (Dockerfile)
- Validate YAML syntax in configuration files

**Deployment Failures**
- Verify SSH connectivity to Synology
- Check Docker Hub authentication
- Ensure sufficient disk space on Synology

**Container Issues**
- Check container logs: `docker logs dd-agent` / `docker logs dd-opw`
- Verify API keys and pipeline configuration
- Check network connectivity between containers

### Log Locations
- **GitHub Actions**: Repository Actions tab
- **Agent Logs**: `docker logs dd-agent`
- **OPW Logs**: `docker logs dd-opw`
- **Configuration**: 
  - Agent: `/volume1/docker/datadog-agent/`
  - OPW: `/volume1/docker/datadog-opw/`

## 🔄 Development Workflow

### Making Changes

1. **Update Configuration**: Modify OPW configs in `opw-config/` or environment variables
2. **Test Locally**: Validate YAML syntax and configuration
3. **Deploy**: Run `./scripts/deploy.sh` to deploy changes
4. **Monitor**: Check GitHub Actions and container health

### CI/CD Pipeline

The GitHub Actions workflow automatically:
- ✅ Builds custom Docker images
- ✅ Validates all configuration files
- ✅ Copies configs to Synology
- ✅ Deploys containers with proper networking
- ✅ Performs health checks
- ✅ Marks deployments in Datadog

## 📝 Environment Variables

### Datadog Agent
- `DD_API_KEY` - Your Datadog API key
- `DD_SITE` - Datadog site (datadoghq.com)

### OPW Configuration
- `DD_OPW_API_KEY` - Datadog API key for OPW
- `DD_OP_PIPELINE_ID` - Pipeline ID
- `DD_OP_SOURCE_DATADOG_AGENT_ADDRESS` - Agent log forwarding address
- `DD_OP_CONFIG_SOURCE` - Configuration source (datadog)
- `DD_OP_API_ENABLED` - Enable OPW API
- `DD_OP_API_ADDRESS` - OPW API listening address

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Commit changes: `git commit -am 'Add your feature'`
4. Push to branch: `git push origin feature/your-feature`
5. Submit a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔗 Links

- [Datadog Agent Documentation](https://docs.datadoghq.com/agent/)
- [Observability Pipelines Documentation](https://docs.datadoghq.com/observability_pipelines/)
- [Synology Docker Documentation](https://www.synology.com/en-us/dsm/packages/Docker)
- [GitHub Actions Documentation](https://docs.github.com/en/actions) 