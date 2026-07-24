#!/bin/bash
# Reverse Tunnel Daemon for dansted.org
# Uses autossh for automatic reconnection

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Load configuration
CONFIG_FILE="/etc/reverse_tunnel_daemon.conf"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    print_warning "Configuration file not found, using defaults"
fi

# Default configuration
REMOTE_HOST=${REMOTE_HOST:-"dansted.org"}
REMOTE_USER=${REMOTE_USER:-"tunnel"}
REMOTE_PORT=${REMOTE_PORT:-"22"}
LOCAL_PORT=${LOCAL_PORT:-"22"}
REMOTE_BIND_PORT=${REMOTE_BIND_PORT:-"2222"}
SSH_KEY_FILE=${SSH_KEY_FILE:-"~/.ssh/id_rsa"}
LOG_FILE=${LOG_FILE:-"/var/log/reverse_tunnel_daemon.log"}
AUTOSSH_PORT=${AUTOSSH_PORT:-"0"}
AUTOSSH_GATETIME=${AUTOSSH_GATETIME:-"30"}
AUTOSSH_POLL=${AUTOSSH_POLL:-"600"}

# Function to setup logging
setup_logging() {
    # Create log directory if it doesn't exist
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Redirect all output to log file and stdout
    exec 1> >(tee -a "$LOG_FILE")
    exec 2> >(tee -a "$LOG_FILE" >&2)
}

# Function to check dependencies
check_dependencies() {
    if ! command -v autossh &> /dev/null; then
        print_error "autossh is not installed. Please install it first."
        print_status "On Ubuntu/Debian: sudo apt-get install autossh"
        print_status "On CentOS/RHEL: sudo yum install autossh"
        print_status "On Arch: sudo pacman -S autossh"
        exit 1
    fi
    
    if ! command -v ssh &> /dev/null; then
        print_error "ssh is not installed. Please install openssh-client."
        exit 1
    fi
}

# Function to check SSH key
check_ssh_key() {
    local key_file="${SSH_KEY_FILE/#\~/$HOME}"
    
    if [[ ! -f "$key_file" ]]; then
        print_error "SSH key file not found: $key_file"
        print_status "Please generate an SSH key pair:"
        print_status "ssh-keygen -t rsa -b 4096 -f $key_file"
        exit 1
    fi
    
    # Check key permissions
    local key_perms=$(stat -c %a "$key_file")
    if [[ "$key_perms" != "600" ]]; then
        print_warning "SSH key has incorrect permissions ($key_perms), fixing..."
        chmod 600 "$key_file"
    fi
}

# Function to test SSH connection
test_ssh_connection() {
    print_status "Testing SSH connection to $REMOTE_USER@$REMOTE_HOST..."
    
    if ssh -o ConnectTimeout=10 -o BatchMode=yes -i "$SSH_KEY_FILE" "$REMOTE_USER@$REMOTE_HOST" "echo 'SSH connection test successful'" &> /dev/null; then
        print_status "SSH connection test successful"
        return 0
    else
        print_error "SSH connection test failed"
        print_status "Please ensure:"
        print_status "1. SSH key is added to $REMOTE_USER@$REMOTE_HOST"
        print_status "2. SSH key permissions are correct (600)"
        print_status "3. Network connectivity to $REMOTE_HOST:$REMOTE_PORT"
        return 1
    fi
}

# Function to start the tunnel
start_tunnel() {
    print_status "Starting reverse tunnel..."
    print_status "Local port $LOCAL_PORT -> $REMOTE_HOST:$REMOTE_BIND_PORT"
    
    # Build autossh command
    local autossh_cmd=(
        autossh
        -M "$AUTOSSH_PORT"
        -f
        -N
        -T
        -R "$REMOTE_BIND_PORT:localhost:$LOCAL_PORT"
        -i "$SSH_KEY_FILE"
        -o "ServerAliveInterval=60"
        -o "ServerAliveCountMax=3"
        -o "ExitOnForwardFailure=yes"
        -o "StrictHostKeyChecking=no"
        -o "UserKnownHostsFile=/dev/null"
        "$REMOTE_USER@$REMOTE_HOST"
        -p "$REMOTE_PORT"
    )
    
    print_status "Running: ${autossh_cmd[*]}"
    
    # Start autossh
    if "${autossh_cmd[@]}"; then
        print_status "Reverse tunnel started successfully"
        return 0
    else
        print_error "Failed to start reverse tunnel"
        return 1
    fi
}

# Function to check tunnel status
check_tunnel_status() {
    local tunnel_pid=$(pgrep -f "autossh.*$REMOTE_HOST")
    
    if [[ -n "$tunnel_pid" ]]; then
        print_status "Tunnel is running (PID: $tunnel_pid)"
        return 0
    else
        print_warning "Tunnel is not running"
        return 1
    fi
}

# Function to stop tunnel
stop_tunnel() {
    local tunnel_pid=$(pgrep -f "autossh.*$REMOTE_HOST")
    
    if [[ -n "$tunnel_pid" ]]; then
        print_status "Stopping tunnel (PID: $tunnel_pid)..."
        kill "$tunnel_pid"
        sleep 2
        
        # Force kill if still running
        if kill -0 "$tunnel_pid" 2>/dev/null; then
            print_warning "Force killing tunnel..."
            kill -9 "$tunnel_pid"
        fi
        
        print_status "Tunnel stopped"
    else
        print_status "No tunnel process found"
    fi
}

# Function to restart tunnel
restart_tunnel() {
    print_status "Restarting tunnel..."
    stop_tunnel
    sleep 2
    start_tunnel
}

# Main daemon loop
daemon_loop() {
    print_status "Starting reverse tunnel daemon..."
    
    while true; do
        if ! check_tunnel_status; then
            print_warning "Tunnel is down, attempting to restart..."
            if start_tunnel; then
                print_status "Tunnel restarted successfully"
            else
                print_error "Failed to restart tunnel"
            fi
        fi
        
        # Wait before next check
        sleep 30
    done
}

# Main function
main() {
    setup_logging
    
    print_status "Reverse Tunnel Daemon starting..."
    print_status "Configuration:"
    print_status "  Remote Host: $REMOTE_HOST"
    print_status "  Remote User: $REMOTE_USER"
    print_status "  Remote Port: $REMOTE_PORT"
    print_status "  Local Port: $LOCAL_PORT"
    print_status "  Remote Bind Port: $REMOTE_BIND_PORT"
    print_status "  SSH Key: $SSH_KEY_FILE"
    print_status "  Log File: $LOG_FILE"
    
    check_dependencies
    check_ssh_key
    
    # Handle command line arguments
    case "${1:-}" in
        "start")
            if test_ssh_connection; then
                start_tunnel
            else
                exit 1
            fi
            ;;
        "stop")
            stop_tunnel
            ;;
        "restart")
            restart_tunnel
            ;;
        "status")
            check_tunnel_status
            ;;
        "test")
            test_ssh_connection
            ;;
        "daemon")
            daemon_loop
            ;;
        *)
            print_status "Usage: $0 {start|stop|restart|status|test|daemon}"
            print_status ""
            print_status "Commands:"
            print_status "  start   - Start the reverse tunnel"
            print_status "  stop    - Stop the reverse tunnel"
            print_status "  restart - Restart the reverse tunnel"
            print_status "  status  - Check tunnel status"
            print_status "  test    - Test SSH connection"
            print_status "  daemon  - Run as daemon with auto-restart"
            exit 1
            ;;
    esac
}

# Run main function
main "$@" 