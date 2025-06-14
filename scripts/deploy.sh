#!/bin/bash

# =============================================================================
# Datadog Agent and OPW Production Deployment Script
# =============================================================================
# This script handles the complete deployment workflow:
# 1. Environment variable setup
# 2. Git operations (add, commit, push)
# 3. GitHub Secrets upload
# 4. Deployment monitoring
#
# Usage: ./scripts/deploy.sh [env-file]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
DEFAULT_ENV_FILE=".env"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Helper functions
print_header() {
    echo -e "${CYAN}================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}================================${NC}"
    echo
}

print_step() {
    echo -e "${BLUE}🔄 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

prompt_yes_no() {
    local prompt="$1"
    local default="${2:-n}"
    
    if [[ "$default" == "y" ]]; then
        prompt="$prompt [Y/n]: "
    else
        prompt="$prompt [y/N]: "
    fi
    
    while true; do
        read -p "$prompt" yn
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            "" ) 
                if [[ "$default" == "y" ]]; then
                    return 0
                else
                    return 1
                fi
                ;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

check_prerequisites() {
    print_step "Checking prerequisites..."
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        print_error "Not in a git repository"
        exit 1
    fi
    
    # Check if GitHub CLI is installed
    if ! command -v gh &> /dev/null; then
        print_error "GitHub CLI (gh) is not installed"
        echo "Install it from: https://cli.github.com/"
        exit 1
    fi
    
    # Check if user is authenticated with GitHub
    if ! gh auth status &> /dev/null; then
        print_warning "Not authenticated with GitHub CLI"
        if prompt_yes_no "Would you like to authenticate now?"; then
            gh auth login
        else
            print_error "GitHub authentication required for deployment"
            exit 1
        fi
    fi
    
    # Check for required Datadog configuration files
    local missing_files=()
    if [[ ! -f "datadog.yaml" ]]; then
        missing_files+=("datadog.yaml")
    fi
    if [[ ! -f "Dockerfile" ]]; then
        missing_files+=("Dockerfile")
    fi
    # Note: docker-compose.yaml removed - using standalone Docker deployment
    
    if [[ ${#missing_files[@]} -gt 0 ]]; then
        print_error "Missing required files: ${missing_files[*]}"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
    echo
}

select_env_file() {
    local env_file="$1"
    
    if [[ -z "$env_file" ]]; then
        echo -e "${YELLOW}Available environment files:${NC}" >&2
        local files=()
        for file in .env* env.*; do
            if [[ -f "$file" && "$file" != ".env.example" ]]; then
                files+=("$file")
                echo "  - $file" >&2
            fi
        done
        
        if [[ ${#files[@]} -eq 0 ]]; then
            print_warning "No environment files found" >&2
            if prompt_yes_no "Create $DEFAULT_ENV_FILE from template?"; then
                if [[ -f "env.example" ]]; then
                    cp env.example "$DEFAULT_ENV_FILE"
                    print_success "Created $DEFAULT_ENV_FILE from template" >&2
                    echo -e "${YELLOW}Please edit $DEFAULT_ENV_FILE with your actual values before continuing${NC}" >&2
                    exit 0
                else
                    print_error "No env.example template found" >&2
                    exit 1
                fi
            else
                exit 1
            fi
        fi
        
        echo >&2
        read -p "Enter environment file path [$DEFAULT_ENV_FILE]: " env_file >&2
        env_file="${env_file:-$DEFAULT_ENV_FILE}"
    fi
    
    if [[ ! -f "$env_file" ]]; then
        print_error "Environment file '$env_file' not found" >&2
        exit 1
    fi
    
    echo "$env_file"
}

validate_env_file() {
    local env_file="$1"
    
    print_step "Validating environment file: $env_file"
    
    # Required Datadog Agent and OPW variables
    # Note: SYNOLOGY_SSH_KEY should be uploaded manually to GitHub
    local required_vars=(
        "DD_API_KEY"
        "DD_OPW_API_KEY"
        "DD_OP_PIPELINE_ID"
        "DOCKERHUB_USER"
        "DOCKERHUB_TOKEN"
        "SYNOLOGY_HOST"
        "SYNOLOGY_SSH_PORT"
        "SYNOLOGY_USER"
    )
    
    # Count total variables and placeholders
    local total_vars=0
    local placeholder_vars=0
    local empty_vars=0
    local missing_vars=()
    local found_vars=()
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines and comments
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            
            # Remove quotes
            value=$(echo "$value" | sed 's/^["'\'']\|["'\'']$//g')
            
            ((total_vars++))
            found_vars+=("$key")
            
            if [[ -z "$value" ]]; then
                ((empty_vars++))
                print_warning "Empty value for: $key"
            elif [[ "$value" =~ ^(your-|sk-your-|secret_your-|dd_|change_me|example) ]]; then
                ((placeholder_vars++))
                print_warning "Placeholder value for: $key"
            fi
        fi
    done < "$env_file"
    
    # Check for missing required variables
    for var in "${required_vars[@]}"; do
        if [[ ! " ${found_vars[*]} " =~ " $var " ]]; then
            missing_vars+=("$var")
        fi
    done
    
    echo
    echo -e "${CYAN}Environment File Summary:${NC}"
    echo -e "  Total variables: $total_vars"
    echo -e "  Valid values: $((total_vars - placeholder_vars - empty_vars))"
    echo -e "  Placeholder values: $placeholder_vars"
    echo -e "  Empty values: $empty_vars"
    echo -e "  Missing required: ${#missing_vars[@]}"
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        echo -e "${RED}  Missing variables: ${missing_vars[*]}${NC}"
    fi
    echo
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        print_error "Missing required variables for Datadog Agent and OPW deployment"
        echo -e "${YELLOW}Please add these variables to your $env_file:${NC}"
        for var in "${missing_vars[@]}"; do
            echo "  $var=your_value_here"
        done
        exit 1
    fi
    
    if [[ $placeholder_vars -gt 0 || $empty_vars -gt 0 ]]; then
        print_warning "Some variables have placeholder or empty values"
        if ! prompt_yes_no "Continue with deployment anyway?"; then
            print_error "Please update your environment file with actual values"
            exit 1
        fi
    fi
    
    print_success "Environment file validation completed"
    echo
}

check_git_status() {
    print_step "Checking git status..."
    
    # Check if there are uncommitted changes
    if ! git diff-index --quiet HEAD --; then
        print_warning "You have uncommitted changes:"
        echo
        git status --porcelain
        echo
        
        if prompt_yes_no "Would you like to add and commit all changes?"; then
            return 0  # Proceed with git operations
        else
            print_error "Please commit your changes before deploying"
            exit 1
        fi
    else
        print_success "Working directory is clean"
        return 1  # No git operations needed
    fi
}

perform_git_operations() {
    print_step "Performing git operations..."
    
    # Add all changes
    print_step "Adding all changes..."
    git add .
    
    # Show what will be committed
    echo -e "${YELLOW}Files to be committed:${NC}"
    git diff --cached --name-status
    echo
    
    # Get commit message
    local default_message="Deploy: Update Datadog Agent configuration and deployment"
    read -p "Enter commit message [$default_message]: " commit_message
    commit_message="${commit_message:-$default_message}"
    
    # Commit changes
    print_step "Committing changes..."
    git commit -m "$commit_message"
    
    # Check current branch
    local current_branch=$(git branch --show-current)
    print_step "Current branch: $current_branch"
    
    # Push changes
    if prompt_yes_no "Push changes to origin/$current_branch?" "y"; then
        print_step "Pushing to origin/$current_branch..."
        git push origin "$current_branch"
        print_success "Changes pushed successfully"
    else
        print_warning "Skipping git push - you'll need to push manually"
    fi
    
    echo
}

upload_secrets() {
    local env_file="$1"
    
    print_step "Uploading secrets to GitHub..."
    
    if [[ -f "$SCRIPT_DIR/setup-secrets.sh" ]]; then
        chmod +x "$SCRIPT_DIR/setup-secrets.sh"
        "$SCRIPT_DIR/setup-secrets.sh" "$env_file"
    else
        print_error "setup-secrets.sh not found in scripts directory"
        exit 1
    fi
    
    echo
}

monitor_deployment() {
    print_step "Monitoring deployment..."
    
    # Get repository info
    local repo=$(gh repo view --json nameWithOwner -q .nameWithOwner)
    
    print_step "Checking for running workflows..."
    
    # Wait a moment for workflow to start
    sleep 5
    
    # Check for recent workflow runs
    local workflow_runs=$(gh run list --limit 3 --json status,conclusion,createdAt,workflowName)
    
    if [[ -n "$workflow_runs" ]]; then
        echo -e "${CYAN}Recent workflow runs:${NC}"
        echo "$workflow_runs" | jq -r '.[] | "  \(.workflowName): \(.status) (\(.createdAt))"'
        echo
        
        if prompt_yes_no "Would you like to watch the latest workflow run?"; then
            gh run watch
        fi
    fi
    
    echo -e "${CYAN}Deployment Links:${NC}"
    echo "  📊 Actions: https://github.com/$repo/actions"
    echo "  🔐 Secrets: https://github.com/$repo/settings/secrets/actions"
    echo "  📋 Repository: https://github.com/$repo"
    echo
}

show_post_deployment_info() {
    print_header "Datadog Agent & OPW Deployment Complete!"
    
    echo -e "${GREEN}🎉 Your Datadog Agent and OPW have been deployed!${NC}"
    echo
    echo -e "${CYAN}What happens next:${NC}"
    echo "  1. GitHub Actions will build your custom Datadog Agent and OPW Docker images"
    echo "  2. Configuration files will be copied to your Synology NAS"
    echo "  3. Datadog Agent and OPW will be deployed as standalone containers"  
    echo "  4. Health checks will verify both deployments"
    echo "  5. Deployments will be marked in Datadog for tracking"
    echo
    echo -e "${CYAN}Monitoring:${NC}"
    echo "  • Watch GitHub Actions for build progress"
    echo "  • Check Synology NAS for running containers: dd-agent, dd-opw"
    echo "  • Verify agent status: http://your-synology:5002/status"
    echo "  • Verify OPW status: http://your-synology:8686/health"
    echo "  • Agent sends logs to OPW at: http://your-synology:8282"
    echo
    echo -e "${CYAN}Datadog Monitoring:${NC}"
    echo "  • Infrastructure metrics should appear in Datadog"
    echo "  • PostgreSQL monitoring (if configured)"
    echo "  • MongoDB monitoring (if configured)"
    echo "  • SNMP monitoring from network devices"
    echo "  • Log collection from containers and syslog"
    echo
    echo -e "${CYAN}Troubleshooting:${NC}"
    echo "  • Check GitHub Actions logs for build issues"
    echo "  • SSH to Synology and check container logs:"
    echo "    - docker logs dd-agent"
    echo "    - docker logs dd-opw"
    echo "  • Verify configuration files:"
    echo "    - /volume1/docker/datadog-agent/"
    echo "    - /volume1/docker/datadog-opw/"
    echo "  • Check Datadog Agent status: docker exec dd-agent datadog-agent status"
    echo "  • Check OPW API health: curl http://localhost:8686/health"
    echo "  • Validate API keys and pipeline configuration"
    echo
}

main() {
    cd "$PROJECT_ROOT"
    
    print_header "Datadog Agent & OPW Production Deployment"
    
    # Check prerequisites
    check_prerequisites
    
    # Select and validate environment file
    local env_file
    env_file=$(select_env_file "$1")
    validate_env_file "$env_file"
    
    # Check git status and perform operations if needed
    if check_git_status; then
        perform_git_operations
    fi
    
    # Upload secrets to GitHub
    upload_secrets "$env_file"
    
    # Monitor deployment
    monitor_deployment
    
    # Show post-deployment information
    show_post_deployment_info
}

# Handle script interruption
trap 'echo -e "\n${RED}Deployment interrupted${NC}"; exit 1' INT TERM

# Run main function
main "$@" 