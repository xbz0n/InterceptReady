#!/bin/bash

# ==========================================
# InterceptReady - Android Security Testing Toolkit
# Created by: Ivan Spiridonov (xbz0n)
# Website: https://xbz0n.sh
# GitHub: https://github.com/xbz0n
# ==========================================
# A comprehensive toolkit for configuring Android emulators
# with Frida and Burp Suite for mobile security testing
# ==========================================

# ANSI color codes for better readability
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}===========================================${NC}"
echo -e "${GREEN}         InterceptReady v1.0${NC}"
echo -e "${GREEN}===========================================${NC}"
echo -e "${YELLOW}Created by: Ivan Spiridonov (xbz0n)${NC}"
echo -e "${YELLOW}Website: https://xbz0n.sh${NC}"
echo -e "${GREEN}===========================================${NC}"
echo ""
echo -e "${YELLOW}This script will:${NC}"
echo "1. Install Burp certificate on your Android Studio emulator"
echo "2. Install Frida on both your computer and emulator"
echo "3. Automatically configure proxy settings to intercept traffic"
echo ""

# Find Android SDK location
find_android_sdk() {
    # Try to find SDK from common locations
    if [ -d "$HOME/Library/Android/sdk" ]; then
        ANDROID_SDK="$HOME/Library/Android/sdk"
    elif [ -d "$HOME/Android/Sdk" ]; then
        ANDROID_SDK="$HOME/Android/Sdk"
    elif [ -n "$ANDROID_HOME" ]; then
        ANDROID_SDK="$ANDROID_HOME"
    elif [ -n "$ANDROID_SDK_ROOT" ]; then
        ANDROID_SDK="$ANDROID_SDK_ROOT"
    else
        # Ask the user for Android SDK location
        read -p "Android SDK not found. Please enter your Android SDK path: " ANDROID_SDK
        if [ ! -d "$ANDROID_SDK" ]; then
            echo -e "${RED}Invalid SDK path${NC}"
            exit 1
        fi
    fi
    
    # Add emulator and platform-tools to PATH if not already present
    if ! command -v emulator &> /dev/null; then
        export PATH="$ANDROID_SDK/emulator:$PATH"
    fi
    
    if ! command -v adb &> /dev/null; then
        export PATH="$ANDROID_SDK/platform-tools:$PATH"
    fi
    
    echo -e "Using Android SDK at: ${YELLOW}$ANDROID_SDK${NC}"
}

# Check for required tools
check_requirements() {
    echo -e "${YELLOW}Checking requirements...${NC}"
    
    # Find Android SDK
    find_android_sdk
    
    # Check for ADB
    if ! command -v adb &> /dev/null; then
        echo -e "${RED}Error: ADB is not installed or not in your PATH${NC}"
        echo "Please ensure Android Studio is properly installed with platform tools"
        exit 1
    fi
    
    # Check for emulator command
    if ! command -v emulator &> /dev/null; then
        echo -e "${RED}Error: 'emulator' command not found in PATH${NC}"
        echo "Make sure Android Studio emulator is installed and in your PATH"
        echo "You can add it manually: export PATH=\$PATH:$ANDROID_SDK/emulator"
        echo -e "${YELLOW}Trying to continue without emulator command...${NC}"
    fi
    
    # Check for Python/pip (needed for Frida)
    if ! command -v python3 &> /dev/null; then
        echo -e "${RED}Error: Python 3 is not installed${NC}"
        echo "Please install Python 3: https://www.python.org/downloads/"
        exit 1
    fi
    
    # Check for virtual environment module
    python3 -c "import venv" 2>/dev/null
    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}Warning: Python venv module not available${NC}"
        echo "You may need to install it manually or use an alternative method"
    fi
    
    echo -e "${GREEN}All requirements satisfied!${NC}"
}

# Get the local IP address for proxy settings
get_local_ip() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # MacOS
        LOCAL_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -n 1)
    else
        # Linux
        LOCAL_IP=$(ip addr show | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | cut -d/ -f1 | head -n 1)
    fi
    
    if [[ -z "$LOCAL_IP" ]]; then
        echo -e "${YELLOW}Could not automatically determine your IP address.${NC}"
        read -p "Please enter your local IP address for proxy (e.g. 192.168.0.100): " LOCAL_IP
    fi
    
    echo -e "Using local IP for proxy: ${YELLOW}$LOCAL_IP${NC}"
}

# Kill any running emulator
kill_emulator() {
    echo -e "${YELLOW}Killing any running emulators...${NC}"
    adb devices | grep emulator | cut -f1 | while read -r line; do
        adb -s "$line" emu kill
    done
    
    # Wait until no emulators are running
    while adb devices | grep -q emulator; do
        echo "Waiting for emulators to shut down..."
        sleep 2
    done
    
    echo -e "${GREEN}All emulators terminated${NC}"
}

# Start a specific emulator with writable system
start_emulator_writable() {
    local avd_name="$1"
    echo -e "Starting emulator: ${YELLOW}$avd_name${NC} with writable system"
    
    # Start emulator in background with writable system
    emulator -avd "$avd_name" -writable-system -no-snapshot -partition-size 2048 &
    
    # Wait for emulator to boot
    echo "Waiting for emulator to boot (this may take a while)..."
    adb wait-for-device
    
    # Wait for system to be ready
    while [ "$(adb shell getprop sys.boot_completed 2>/dev/null)" != "1" ]; do
        echo "Waiting for boot to complete..."
        sleep 2
    done
    
    echo -e "${GREEN}Emulator started and ready!${NC}"
}

# Check and start emulator if needed
check_emulator() {
    echo -e "${YELLOW}Checking for running emulators...${NC}"
    
    # Check if emulator is running
    if adb devices | grep -q "emulator"; then
        echo -e "${GREEN}Emulator detected!${NC}"
        
        read -p "Do you want to restart the emulator with writable system? (y/n): " restart_choice
        if [ "$restart_choice" = "y" ]; then
            select_and_start_emulator
        fi
    else
        echo -e "${YELLOW}No emulator detected. Starting one...${NC}"
        select_and_start_emulator
    fi
}

# Select and start an emulator
select_and_start_emulator() {
    # Try to list available emulators
    if command -v emulator &> /dev/null; then
        echo "Available emulators:"
        emulator -list-avds
        
        if [ $? -eq 0 ]; then
            # Get list of available AVDs
            avds=($(emulator -list-avds))
            
            if [ ${#avds[@]} -eq 0 ]; then
                echo -e "${RED}No emulators found. Please create one in Android Studio first.${NC}"
                exit 1
            elif [ ${#avds[@]} -eq 1 ]; then
                # If only one emulator exists, use it
                selected_avd="${avds[0]}"
                echo -e "Only one emulator found, using: ${YELLOW}$selected_avd${NC}"
            else
                # Let user select which emulator to use
                echo "Select an emulator to start:"
                select avd_name in "${avds[@]}"; do
                    if [ -n "$avd_name" ]; then
                        selected_avd="$avd_name"
                        break
                    else
                        echo "Invalid selection. Please try again."
                    fi
                done
            fi
            
            # Kill any running emulators
            kill_emulator
            
            # Start the selected emulator
            start_emulator_writable "$selected_avd"
        else
            echo -e "${RED}Failed to list emulators. Please check your Android Studio installation.${NC}"
            exit 1
        fi
    else
        echo -e "${RED}Emulator command not found. Please ensure Android SDK emulator is in your PATH.${NC}"
        exit 1
    fi
}

# Enable root on the emulator
enable_root() {
    echo -e "${YELLOW}Enabling root access on emulator...${NC}"
    
    # Restart ADB as root
    adb root
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Root access enabled on emulator!${NC}"
    else
        echo -e "${RED}Failed to enable root access on emulator${NC}"
        echo "This script requires an emulator with root capabilities"
        exit 1
    fi
    
    # Remount system as writable
    echo "Remounting system partition as writable..."
    adb remount
    
    # Check if remount was successful or try alternative method
    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}Standard remount failed, trying alternative method...${NC}"
        
        # Try alternative remount methods
        adb shell "mount -o rw,remount /system"
        adb shell "mount -o rw,remount /"
        
        # Check if any of those worked
        if adb shell "touch /system/testfile" &>/dev/null; then
            adb shell "rm /system/testfile"
            echo -e "${GREEN}System partition remounted as writable!${NC}"
        else
            echo -e "${RED}Failed to remount system partition${NC}"
            echo -e "${YELLOW}Warning: Some features may not work correctly.${NC}"
            echo "You might need to restart the emulator with '-writable-system' flag."
            echo "This script already attempted to do this, but it may not have worked."
            
            read -p "Do you want to continue anyway? (y/n): " continue_choice
            if [ "$continue_choice" != "y" ]; then
                exit 1
            fi
        fi
    else
        echo -e "${GREEN}System partition remounted as writable!${NC}"
    fi
}

# Install Burp certificate
install_cert() {
    echo -e "${YELLOW}Installing Burp certificate...${NC}"
    
    # Check if certificate exists
    if [ ! -f "cacert.der" ]; then
        echo -e "${RED}Error: cacert.der not found in current directory${NC}"
        echo "Please export the Burp certificate in DER format to this directory first"
        exit 1
    fi
    
    # Push certificate to emulator
    adb push cacert.der /data/local/tmp/
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Certificate pushed to emulator${NC}"
        
        # Get Android version
        android_version=$(adb shell getprop ro.build.version.sdk)
        echo -e "Detected Android SDK version: ${YELLOW}$android_version${NC}"
        
        if [ "$android_version" -ge 28 ]; then
            # For newer Android versions (SDK 28+, Android 9.0+)
            echo -e "${YELLOW}Installing certificate on Android SDK $android_version...${NC}"
            
            # Convert DER to PEM if needed
            echo "Converting certificate to PEM format..."
            openssl x509 -inform DER -in cacert.der -out cacert.pem
            
            # Push to emulator
            adb push cacert.pem /data/local/tmp/

            # Generate a unique hash for the certificate
            cert_hash=$(openssl x509 -inform PEM -subject_hash_old -in cacert.pem | head -1)
            
            # Create directories if they don't exist
            adb shell "mkdir -p /data/misc/user/0/cacerts-added/"
            
            # Create the certificate file with proper extension
            adb shell "cat /data/local/tmp/cacert.pem > /data/misc/user/0/cacerts-added/$cert_hash.0"
            
            # Set proper permissions
            adb shell "chmod 664 /data/misc/user/0/cacerts-added/$cert_hash.0"
            
            echo -e "${GREEN}Certificate installed successfully!${NC}"
            echo -e "${YELLOW}NOTE: You may need to enable 'User Certificates' in your emulator settings${NC}"
            echo "Go to Settings > Security > Encryption & Credentials > Trusted Credentials"
            
            # Additional step for Android 10+
            if [ "$android_version" -ge 29 ]; then
                echo -e "${YELLOW}For Android 10+, you may need to set a PIN/pattern for the emulator${NC}"
                echo "Go to Settings > Security > Screen Lock to set a PIN/pattern"
            fi
        else
            # For older Android versions
            echo -e "${YELLOW}Installing certificate on Android SDK $android_version...${NC}"
            
            # Convert and install certificate
            cert_hash=$(openssl x509 -inform DER -subject_hash_old -in cacert.der | head -1)
            
            # Create certificate with proper hash name
            adb shell "cp /data/local/tmp/cacert.der /data/local/tmp/$cert_hash.0"
            
            # Install to system certificate store
            adb shell "mount -o rw,remount /system"
            adb shell "mkdir -p /system/etc/security/cacerts"
            adb shell "cp /data/local/tmp/$cert_hash.0 /system/etc/security/cacerts/"
            adb shell "chmod 644 /system/etc/security/cacerts/$cert_hash.0"
            adb shell "mount -o ro,remount /system"
            
            echo -e "${GREEN}Certificate installed successfully!${NC}"
        fi
    else
        echo -e "${RED}Failed to push certificate to emulator${NC}"
        exit 1
    fi
}

# Configure proxy settings on the emulator
configure_proxy() {
    echo -e "${YELLOW}Configuring proxy settings...${NC}"
    
    # Get the local IP address for proxy
    get_local_ip
    
    # Default Burp port
    DEFAULT_PORT="8080"
    
    # Ask for proxy port
    read -p "Enter proxy port [default: $DEFAULT_PORT]: " PROXY_PORT
    PROXY_PORT=${PROXY_PORT:-$DEFAULT_PORT}
    
    # Construct proxy string
    PROXY="$LOCAL_IP:$PROXY_PORT"
    echo -e "Setting proxy to: ${YELLOW}$PROXY${NC}"
    
    # Set global proxy via settings
    echo "Setting global proxy via settings..."
    adb shell settings put global http_proxy "$PROXY"
    
    # Also set proxy via properties for some apps that don't respect global settings
    echo "Setting additional proxy properties..."
    adb shell "setprop net.eth0.proxy.host $LOCAL_IP"
    adb shell "setprop net.eth0.proxy.port $PROXY_PORT"
    adb shell "setprop net.gprs.proxy.host $LOCAL_IP"
    adb shell "setprop net.gprs.proxy.port $PROXY_PORT"
    adb shell "setprop net.ppp0.proxy.host $LOCAL_IP"
    adb shell "setprop net.ppp0.proxy.port $PROXY_PORT"
    adb shell "setprop net.wlan0.proxy.host $LOCAL_IP"
    adb shell "setprop net.wlan0.proxy.port $PROXY_PORT"
    
    # For good measure, set it for WiFi as well (though emulators typically use ethernet)
    adb shell "cmd wifi set-httpproxy eth0 $LOCAL_IP $PROXY_PORT" &>/dev/null
    
    echo -e "${GREEN}Proxy settings configured successfully!${NC}"
    echo -e "${YELLOW}NOTE: Make sure Burp Suite is running and listening on ${PROXY}${NC}"
    
    # Verify proxy settings
    echo "Verifying proxy settings:"
    adb shell settings get global http_proxy
}

# Clear proxy settings on the emulator
clear_proxy() {
    echo -e "${YELLOW}Clearing proxy settings...${NC}"
    
    # Clear global proxy
    adb shell settings put global http_proxy :0
    
    # Clear other proxy properties
    adb shell "setprop net.eth0.proxy.host ''"
    adb shell "setprop net.eth0.proxy.port ''"
    adb shell "setprop net.gprs.proxy.host ''"
    adb shell "setprop net.gprs.proxy.port ''"
    adb shell "setprop net.ppp0.proxy.host ''"
    adb shell "setprop net.ppp0.proxy.port ''"
    adb shell "setprop net.wlan0.proxy.host ''"
    adb shell "setprop net.wlan0.proxy.port ''"
    
    # Clear WiFi proxy
    adb shell "cmd wifi clear-httpproxy eth0" &>/dev/null
    
    echo -e "${GREEN}Proxy settings cleared!${NC}"
}

# Start Frida server properly
start_frida_server() {
    echo "Starting Frida server..."
    
    # Kill any existing Frida server process first
    adb shell "pkill -f frida-server" &>/dev/null
    sleep 1
    
    # Start Frida server properly in background, fully detached
    adb shell "nohup /data/local/tmp/frida-server > /dev/null 2>&1 &"
    
    # Wait a moment for server to start
    sleep 2
    
    # Check if Frida server is running
    if adb shell "ps -A | grep frida-server" &>/dev/null; then
        echo -e "${GREEN}Frida server started successfully!${NC}"
        return 0
    else
        echo -e "${RED}Failed to start Frida server${NC}"
        echo "Trying alternative method..."
        
        # Try alternative method
        adb shell "cd /data/local/tmp && ./frida-server &" &
        sleep 3
        
        if adb shell "ps -A | grep frida-server" &>/dev/null; then
            echo -e "${GREEN}Frida server started with alternative method!${NC}"
            return 0
        else
            echo -e "${RED}Could not start Frida server automatically${NC}"
            echo "You may need to start it manually later with:"
            echo "adb shell '/data/local/tmp/frida-server &'"
            return 1
        fi
    fi
}

# Install Frida
install_frida() {
    echo -e "${YELLOW}Installing Frida...${NC}"
    
    # Setup Python Virtual Environment for Frida
    echo "Setting up Python virtual environment for Frida..."
    
    # Create a virtual environment directory in the current path
    VENV_DIR="frida_venv"
    
    # Check if virtual environment already exists
    if [ -d "$VENV_DIR" ]; then
        echo "Using existing virtual environment at $VENV_DIR"
    else
        # Create a new virtual environment
        echo "Creating new virtual environment at $VENV_DIR"
        python3 -m venv "$VENV_DIR"
        
        if [ $? -ne 0 ]; then
            echo -e "${YELLOW}Failed to create virtual environment with venv, trying virtualenv...${NC}"
            
            # Check if virtualenv is installed
            if command -v pip3 &> /dev/null; then
                pip3 install --user virtualenv
                
                if [ $? -eq 0 ]; then
                    python3 -m virtualenv "$VENV_DIR"
                    
                    if [ $? -ne 0 ]; then
                        echo -e "${RED}Failed to create virtual environment${NC}"
                        echo "Attempting to install Frida using pip with --user flag..."
                        pip3 install --user frida-tools
                        
                        if [ $? -ne 0 ]; then
                            echo -e "${RED}All installation methods failed. Try installing Frida manually:${NC}"
                            echo "  pip3 install --user frida-tools"
                            echo "  or"
                            echo "  python3 -m venv frida_venv"
                            echo "  source frida_venv/bin/activate"
                            echo "  pip install frida-tools"
                            exit 1
                        else
                            # If pip install with --user worked, set FRIDA_PATH
                            FRIDA_PATH="$HOME/.local/bin"
                            export PATH="$FRIDA_PATH:$PATH"
                            echo -e "${GREEN}Frida tools installed successfully (user mode)!${NC}"
                            # Skip the rest of the virtual environment setup
                            SKIP_VENV=true
                        fi
                    fi
                else
                    echo -e "${RED}Failed to install virtualenv${NC}"
                    exit 1
                fi
            else
                echo -e "${RED}pip3 is not available${NC}"
                exit 1
            fi
        fi
    fi
    
    # Activate the virtual environment if not skipping
    if [ "$SKIP_VENV" != "true" ]; then
        # Activate virtual environment
        if [ -f "$VENV_DIR/bin/activate" ]; then
            echo "Activating virtual environment..."
            source "$VENV_DIR/bin/activate"
            
            # Install Frida tools in the virtual environment
            echo "Installing Frida tools in virtual environment..."
            pip install frida-tools
            
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}Frida tools installed successfully in virtual environment!${NC}"
                
                # Get the path to frida-server binary
                FRIDA_PATH="$PWD/$VENV_DIR/bin"
                export PATH="$FRIDA_PATH:$PATH"
                
                echo -e "${YELLOW}NOTE: To use Frida later, activate the virtual environment:${NC}"
                echo "  source $PWD/$VENV_DIR/bin/activate"
            else
                echo -e "${RED}Failed to install Frida tools in virtual environment${NC}"
                exit 1
            fi
        else
            echo -e "${RED}Failed to find virtual environment activation script${NC}"
            exit 1
        fi
    fi
    
    # Get Frida version to download the server
    frida_version=$(frida --version 2>/dev/null)
    
    if [ -z "$frida_version" ]; then
        echo -e "${YELLOW}Could not determine Frida version, attempting to get it from pip...${NC}"
        if [ "$SKIP_VENV" != "true" ]; then
            frida_version=$(pip show frida | grep Version | awk '{print $2}')
        else
            frida_version=$(pip3 show frida | grep Version | awk '{print $2}')
        fi
        
        if [ -z "$frida_version" ]; then
            echo -e "${YELLOW}Still could not determine Frida version, using latest...${NC}"
            frida_version="16.1.4"  # Use a known version as fallback
        fi
    fi
    
    echo -e "Using Frida version: ${YELLOW}$frida_version${NC}"
    
    # Install Frida server on emulator
    echo "Installing Frida server on your Android emulator..."
    
    # Get emulator architecture (emulators are usually x86 or x86_64)
    arch=$(adb shell getprop ro.product.cpu.abi)
    echo -e "Detected emulator architecture: ${YELLOW}$arch${NC}"
    
    # Map Android architecture to Frida architecture
    case $arch in
        x86)
            frida_arch="x86"
            ;;
        x86_64)
            frida_arch="x86_64"
            ;;
        armeabi-v7a)
            frida_arch="arm"
            ;;
        arm64-v8a)
            frida_arch="arm64"
            ;;
        *)
            echo -e "${RED}Unsupported architecture: $arch${NC}"
            echo "Most Android emulators use x86 or x86_64 architecture"
            exit 1
            ;;
    esac
    
    # Download Frida server
    echo "Downloading Frida server for $frida_arch..."
    curl -L -O "https://github.com/frida/frida/releases/download/$frida_version/frida-server-$frida_version-android-$frida_arch.xz"
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to download Frida server${NC}"
        exit 1
    fi
    
    # Extract Frida server
    echo "Extracting Frida server..."
    xz -d "frida-server-$frida_version-android-$frida_arch.xz"
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to extract Frida server${NC}"
        exit 1
    fi
    
    # Push Frida server to emulator
    echo "Pushing Frida server to emulator..."
    adb push "frida-server-$frida_version-android-$frida_arch" /data/local/tmp/frida-server
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to push Frida server to emulator${NC}"
        exit 1
    fi
    
    # Set up Frida server on emulator
    echo "Setting up Frida server on emulator..."
    adb shell "chmod 755 /data/local/tmp/frida-server"
    
    echo -e "${GREEN}Frida server installed successfully!${NC}"
    echo -e "${YELLOW}To start Frida server, run:${NC}"
    echo "adb shell 'nohup /data/local/tmp/frida-server > /dev/null 2>&1 &'"
    
    read -p "Do you want to start Frida server now? (y/n): " start_frida
    if [ "$start_frida" = "y" ]; then
        start_frida_server
    fi
}

# Test the setup with timeout
test_setup() {
    echo -e "${YELLOW}Testing the setup...${NC}"
    
    # Check if Frida server is running
    if ! adb shell "ps -A | grep frida-server" &>/dev/null; then
        echo -e "${YELLOW}Frida server not running. Starting it now...${NC}"
        start_frida_server
    fi
    
    # Function to run the test with timeout
    run_frida_test() {
        # Run the test with a timeout of 10 seconds
        timeout 10 frida-ps -U &>/dev/null
        return $?
    }
    
    # Try running frida-ps with a timeout
    echo "Testing connection to Frida server..."
    if run_frida_test; then
        echo -e "${GREEN}Frida is working correctly!${NC}"
        # Now run it for real to show the output
        frida-ps -U | head -n 10
        echo "..."
    else
        echo -e "${RED}Frida test failed or timed out${NC}"
        echo "Please check that:"
        echo "1. The emulator is running"
        echo "2. Frida server is running on the emulator"
        echo "3. ADB is connected to the emulator"
        echo -e "${YELLOW}Remember to activate the virtual environment:${NC}"
        echo "  source $PWD/frida_venv/bin/activate"
    fi
}

# Proxy management menu
proxy_menu() {
    echo -e "${YELLOW}Proxy Management${NC}"
    echo "1. Configure proxy settings"
    echo "2. Clear proxy settings"
    echo "3. Skip proxy configuration"
    read -p "Select an option (1-3): " proxy_choice
    
    case $proxy_choice in
        1)
            configure_proxy
            ;;
        2)
            clear_proxy
            ;;
        3)
            echo "Skipping proxy configuration"
            ;;
        *)
            echo -e "${RED}Invalid option. Skipping proxy configuration${NC}"
            ;;
    esac
}

# Main execution
main() {
    check_requirements
    check_emulator
    enable_root
    install_cert
    proxy_menu
    install_frida
    test_setup
    
    echo -e "${GREEN}Setup complete!${NC}"
    echo -e "${YELLOW}Summary:${NC}"
    echo "1. Burp certificate installed on emulator"
    echo "2. Proxy settings configured (if selected)"
    echo "3. Frida installed in a virtual environment and on emulator"
    echo ""
    echo -e "${YELLOW}Usage:${NC}"
    
    if [ "$SKIP_VENV" != "true" ] && [ -d "$VENV_DIR" ]; then
        echo -e "${YELLOW}IMPORTANT: To use Frida tools, you must first activate the virtual environment:${NC}"
        echo "  source $PWD/$VENV_DIR/bin/activate"
    fi
    
    echo "- To start Frida server: adb shell 'nohup /data/local/tmp/frida-server > /dev/null 2>&1 &'"
    echo "- To list processes: frida-ps -U"
    echo "- To attach to a process: frida -U <process_name_or_pid>"
    echo "- To use Frida script: frida -U -l your_script.js <process_name>"
    echo "- To update proxy settings: ./frida_installer.sh"
    echo ""
    echo -e "${GREEN}Happy hacking!${NC}"
}

# Check if being sourced or run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Run directly - check for specific commands
    if [[ "$1" == "proxy" ]]; then
        proxy_menu
        exit 0
    elif [[ "$1" == "clear-proxy" ]]; then
        clear_proxy
        exit 0
    else
        # Run the full script
        main
    fi
fi 