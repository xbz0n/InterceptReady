# InterceptReady

<p align="center">
  <img src="https://img.shields.io/badge/Version-1.0-brightgreen" alt="Version">
  <img src="https://img.shields.io/badge/Language-Bash%2FJavaScript-blue" alt="Language">
  <img src="https://img.shields.io/badge/Platform-Android-green" alt="Platform">
  <img src="https://img.shields.io/badge/License-MIT-lightgrey" alt="License">
</p>

<p align="center">
  <b>InterceptReady</b> is an automated toolkit for configuring Android emulators with Frida and Burp Suite for mobile security testing.
</p>

<p align="center">
  <a href="https://xbz0n.sh"><img src="https://img.shields.io/badge/Blog-xbz0n.sh-red" alt="Blog"></a>
</p>

---

## Overview

InterceptReady automates the setup of Android emulators for security testing by installing Frida, configuring Burp Suite certificates, and setting up proxy settings. The script handles all the complex tasks required to prepare a fully-functional mobile testing environment.

This toolkit includes both the setup script (`frida_installer.sh`) and an enhanced SSL pinning bypass script (`ssl_pinning_bypass.js`) with intelligent handling of various SSL pinning implementations.

## Features

### Installer Features

- **Frida Integration** - Installs and configures Frida on both host and emulator
- **Certificate Installation** - Automatically installs Burp Suite CA certificate
- **Proxy Configuration** - Sets up system-wide proxy for traffic interception
- **Writable System** - Configures emulator with writable system partition
- **Root Access** - Enables root access for comprehensive testing
- **Multiple Emulator Support** - Works with any Android emulator
- **Python Environment** - Creates isolated virtual environment for Frida tools
- **Auto-detection** - Identifies SDK location and emulator architecture

### SSL Pinning Bypass Features

- **Watchdog Timer** - Detects application hanging and switches to minimal bypass
- **Staggered Execution** - Progressive implementation of bypasses to maximize stability
- **Error Recovery** - Robust error handling prevents application crashes
- **Resource Optimization** - Limits processing to prevent performance issues
- **Multiple Bypass Methods** - Targets various SSL implementation libraries:
  - OkHttp3 Certificate Pinning
  - TrustManager (Android System)
  - X509TrustManager
  - SSLContext/SSLSocket implementations
  - Conscrypt
  - JSSE Provider
  - Appcelerator Titanium
  - WebView Certificate Handlers

## System Compatibility

| OS | Compatibility | Feature Support |
|----|---------------|-----------------|
| macOS | ✅ | Full support |
| Linux | ✅ | Full support |
| Windows | ⚠️ | Limited support via WSL |

## Android Compatibility

| Android Version | Compatibility |
|-----------------|---------------|
| Android 13 (API 33) | ✅ |
| Android 12 (API 31-32) | ✅ |
| Android 11 (API 30) | ✅ |
| Android 10 (API 29) | ✅ |
| Android 9 (API 28) | ✅ |
| Android 8 (API 26-27) | ✅ |
| Android 7 (API 24-25) | ✅ |
| Android 6 (API 23) | ✅ |

## Requirements

- Android Studio with at least one emulator
- Python 3.x installed
- Burp Suite running with exported certificate

## Installation

```bash
# Clone the repository
git clone https://github.com/xbz0n/InterceptReady.git
cd InterceptReady

# Make the script executable
chmod +x frida_installer.sh

# Run the installer
./frida_installer.sh
```

## Usage

### Setup Options

```bash
# Complete setup
./frida_installer.sh

# Proxy management only
./frida_installer.sh proxy

# Clear proxy settings
./frida_installer.sh clear-proxy
```

### SSL Pinning Bypass Usage

Once setup is complete, you can use the included SSL pinning bypass script:

```bash
# With interactive mode
frida -U -l ssl_pinning_bypass.js <app_package_name>

# With spawn mode for problematic apps
frida -U -l ssl_pinning_bypass.js -f <app_package_name> --no-pause

# With V8 runtime for better stability if the app hangs
frida -U -l ssl_pinning_bypass.js <app_package_name> --runtime=v8
```

## How It Works

### Installer Script Workflow

1. Checks for required tools and dependencies
2. Detects or starts Android emulator with writable system
3. Enables root access and remounts system partition
4. Installs Burp Suite certificate in system store
5. Configures proxy settings based on local IP address
6. Creates Python virtual environment and installs Frida tools
7. Downloads and installs appropriate Frida server on emulator
8. Tests the connection between host and emulator

### SSL Bypass Script Technology

The script employs several strategies to bypass certificate validation:

1. **Android System TrustManager**: Replaces the system's X509TrustManager with a version that trusts all certificates
2. **OkHttp Client**: Targets OkHttp3's CertificatePinner class to bypass built-in pinning
3. **SSLContext Manipulation**: Modifies the SSLContext creation to use permissive TrustManagers
4. **WebView Certificate Handling**: Overrides WebView certificate verification callbacks
5. **Java Secure Socket Extension (JSSE)**: Hooks into the JSSE provider's certificate validation

Each bypass is executed in a staged manner with appropriate error handling to ensure maximum application stability.

## Detailed Functionality

| Function | Description |
|----------|-------------|
| Android SDK Detection | Automatically locates Android SDK installation |
| Emulator Management | Starts emulator with writable system and proper permissions |
| Certificate Installation | Handles certificate installation for various Android versions |
| Proxy Configuration | Sets global proxy and network properties for complete interception |
| Frida Setup | Installs appropriate Frida server version matching client tools |
| SSL Pinning Bypass | Provides enhanced SSL pinning bypass with intelligent recovery mechanisms |

## Technical Improvements

Recent enhancements to the SSL pinning bypass script include:

- **Intelligent Timeout Detection**: Watches for application hanging and switches to minimal bypass mode
- **Error Recovery**: Continues operation even if individual bypasses fail
- **Global Exception Handler**: Catches and logs unhandled exceptions
- **Resource Management**: Limits enumeration to prevent excessive CPU/memory usage
- **Enhanced Logging**: Better diagnostic information for troubleshooting

## Troubleshooting

### Installer Issues

- Ensure Android Studio is properly installed with platform tools
- Verify Burp Suite is running with the certificate exported as DER format
- Check that the emulator has internet connectivity
- Examine adb and Frida outputs for specific error messages

### SSL Bypass Issues

If the application hangs:

1. **Try V8 Runtime**: Use the `--runtime=v8` flag to run with the V8 JavaScript engine
2. **Use Spawn Mode**: Try attaching to the application at launch with `-f` flag
3. **Check Logs**: Examine the script output for specific errors
4. **Reduce Scope**: Modify the script to disable specific bypasses if they cause problems

## Limitations

- Some applications may detect Frida and implement anti-tampering mechanisms
- Applications using native (C/C++) SSL implementations may require additional bypasses
- Heavy obfuscation might require customized hooks and class name identification

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Author

- **Ivan Spiridonov (xbz0n)** - [Blog](https://xbz0n.sh) | [GitHub](https://github.com/xbz0n)

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- The [Frida](https://frida.re) project for their excellent dynamic instrumentation toolkit
- The [OWASP Mobile Security Testing Guide](https://owasp.org/www-project-mobile-security-testing-guide/) for mobile security best practices
- The mobile security testing community for inspiration and techniques 