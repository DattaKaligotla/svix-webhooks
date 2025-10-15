#!/bin/bash
set -euo pipefail

# Svix Docker Setup Script
# This script helps you quickly start the Svix webhooks infrastructure

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

show_help() {
    cat << EOF
🚀 Svix Docker Setup Script

Usage: $0 [COMMAND] [OPTIONS]

Commands:
  start         Start Svix services (production mode)
  dev           Start development environment with hot reloading
  stop          Stop all services
  restart       Restart all services
  logs          Show logs for all services
  status        Show status of all services
  clean         Clean up containers, networks, and volumes
  reset         Complete reset (clean + restart)
  jwt           Generate a JWT token
  test          Run tests
  help          Show this help message

Options:
  --monitoring  Include monitoring services (pgAdmin, Redis UI)
  --bridge      Include Svix bridge service
  --testing     Include testing services
  --all         Include all optional services

Examples:
  $0 start                    # Start core services
  $0 start --monitoring       # Start with monitoring
  $0 dev --all               # Development with all services
  $0 logs                    # Show logs
  $0 jwt                     # Generate JWT token
  $0 clean                   # Clean up everything

EOF
}

check_dependencies() {
    log_info "Checking dependencies..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not available. Please install Docker Compose."
        exit 1
    fi
    
    log_success "Dependencies check passed"
}

build_profiles() {
    local profiles=()
    
    if [[ "${MONITORING:-}" == "true" ]]; then
        profiles+=(--profile monitoring)
    fi
    
    if [[ "${BRIDGE:-}" == "true" ]]; then
        profiles+=(--profile bridge)
    fi
    
    if [[ "${TESTING:-}" == "true" ]]; then
        profiles+=(--profile testing)
    fi
    
    echo "${profiles[@]:-}"
}

start_services() {
    local compose_file="docker-compose.yml"
    local build_flag=""
    
    if [[ "${DEV_MODE:-}" == "true" ]]; then
        compose_file="docker-compose.dev.yml"
        log_info "Starting Svix in development mode..."
    else
        log_info "Starting Svix in production mode..."
        build_flag="--build"
    fi
    
    local profiles
    profiles=$(build_profiles)
    
    log_info "Using compose file: $compose_file"
    if [[ -n "${profiles}" ]]; then
        log_info "Enabled profiles: $profiles"
    fi
    
    # Check if JWT secret is set
    if [[ "${DEV_MODE:-}" != "true" ]] && ! grep -q "SVIX_JWT_SECRET.*your-super-secret" "$compose_file" 2>/dev/null; then
        log_warning "Consider setting a secure JWT secret in production!"
        log_info "Run: $0 jwt   # to generate a secure JWT secret"
    fi
    
    # Start services
    if [[ -n "${profiles}" ]]; then
        docker compose -f "$compose_file" $profiles up -d $build_flag
    else
        docker compose -f "$compose_file" up -d $build_flag
    fi
    
    log_success "Services starting..."
    
    # Wait for health checks
    log_info "Waiting for services to be healthy..."
    sleep 5
    
    # Show status
    show_status "$compose_file" "$profiles"
    
    # Show useful URLs
    echo ""
    log_success "Svix is running! 🎉"
    echo ""
    echo "📊 Useful URLs:"
    echo "   Svix Server:     http://localhost:8071"
    
    if [[ "${MONITORING:-}" == "true" ]]; then
        echo "   PostgreSQL UI:   http://localhost:8080 (admin@svix.local / admin)"
        echo "   Redis UI:        http://localhost:8081 (admin / admin)"
    fi
    
    if [[ "${BRIDGE:-}" == "true" ]]; then
        echo "   Svix Bridge:     http://localhost:5000"
    fi
    
    if [[ "${TESTING:-}" == "true" ]]; then
        echo "   Webhook Tester:  http://localhost:8082"
    fi
    
    echo ""
    echo "🛠  Useful commands:"
    echo "   View logs:       $0 logs"
    echo "   Generate JWT:    $0 jwt"
    echo "   Stop services:   $0 stop"
    echo "   Show status:     $0 status"
}

stop_services() {
    log_info "Stopping Svix services..."
    
    # Try both compose files
    docker compose down 2>/dev/null || true
    docker compose -f docker-compose.dev.yml down 2>/dev/null || true
    
    log_success "Services stopped"
}

show_logs() {
    local compose_file="docker-compose.yml"
    
    if [[ "${DEV_MODE:-}" == "true" ]]; then
        compose_file="docker-compose.dev.yml"
    fi
    
    local profiles
    profiles=$(build_profiles)
    
    log_info "Showing logs..."
    
    if [[ -n "${profiles}" ]]; then
        docker compose -f "$compose_file" $profiles logs -f --tail=50
    else
        docker compose -f "$compose_file" logs -f --tail=50
    fi
}

show_status() {
    local compose_file="${1:-docker-compose.yml}"
    local profiles="${2:-}"
    
    log_info "Service status:"
    
    if [[ -n "${profiles}" ]]; then
        docker compose -f "$compose_file" $profiles ps
    else
        docker compose -f "$compose_file" ps
    fi
}

generate_jwt() {
    log_info "Generating JWT token..."
    
    # Try to use running container, fallback to temporary container
    if docker compose exec svix-server svix-server jwt generate 2>/dev/null; then
        log_success "JWT token generated using running server"
    elif docker compose -f docker-compose.dev.yml exec svix-server-dev svix-server jwt generate 2>/dev/null; then
        log_success "JWT token generated using development server"
    else
        log_info "No running server found. Starting temporary container..."
        docker run --rm svix/svix-complete:latest svix-server jwt generate
    fi
    
    echo ""
    log_info "You can also generate JWT for specific organizations:"
    log_info "docker compose exec svix-server svix-server jwt generate org_23rb8YdGqMT0qIzpgGwdXfHirMu"
}

run_tests() {
    log_info "Running tests..."
    docker compose -f docker-compose.dev.yml --profile testing up --build test
    log_success "Tests completed"
}

clean_up() {
    log_warning "This will remove all containers, networks, and volumes. Continue? (y/N)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        log_info "Cleaning up Svix Docker resources..."
        
        # Stop and remove containers
        docker compose down -v --remove-orphans 2>/dev/null || true
        docker compose -f docker-compose.dev.yml down -v --remove-orphans 2>/dev/null || true
        
        # Remove Svix-related images
        docker images | grep svix | awk '{print $3}' | xargs docker rmi -f 2>/dev/null || true
        
        # Prune unused resources
        docker system prune -f
        
        log_success "Cleanup completed"
    else
        log_info "Cleanup cancelled"
    fi
}

# Parse arguments
COMMAND="${1:-help}"
shift || true

# Parse options
while [[ $# -gt 0 ]]; do
    case $1 in
        --monitoring)
            MONITORING=true
            shift
            ;;
        --bridge)
            BRIDGE=true
            shift
            ;;
        --testing)
            TESTING=true
            shift
            ;;
        --all)
            MONITORING=true
            BRIDGE=true
            TESTING=true
            shift
            ;;
        --dev)
            DEV_MODE=true
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Main command handling
case $COMMAND in
    start)
        check_dependencies
        start_services
        ;;
    dev)
        check_dependencies
        DEV_MODE=true
        start_services
        ;;
    stop)
        stop_services
        ;;
    restart)
        stop_services
        sleep 2
        start_services
        ;;
    logs)
        show_logs
        ;;
    status)
        show_status
        ;;
    jwt)
        generate_jwt
        ;;
    test)
        check_dependencies
        run_tests
        ;;
    clean)
        clean_up
        ;;
    reset)
        clean_up
        if [[ "$?" -eq 0 ]]; then
            sleep 2
            start_services
        fi
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        log_error "Unknown command: $COMMAND"
        show_help
        exit 1
        ;;
esac