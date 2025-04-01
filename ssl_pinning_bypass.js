// Frida SSL Pinning Bypass Script
// Advanced comprehensive script to bypass multiple SSL pinning implementations in Android applications
// Improved version with additional pinning methods and error resilience

setTimeout(function() {
    Java.perform(function() {
        console.log("[+] Advanced SSL Pinning Bypass Script Loaded");
        
        // Helper function to create a more organized console output
        function logSuccess(message) {
            console.log("[+] SUCCESS: " + message);
        }
        
        function logError(message) {
            console.log("[-] ERROR: " + message);
        }
        
        function logInfo(message) {
            console.log("[*] INFO: " + message);
        }
        
        function logDebug(message) {
            console.log("[D] DEBUG: " + message);
        }

        // Flag to track if app is hanging
        var isHanging = false;
        
        // Simple watchdog to detect if the app is hanging
        var watchdogTimer = setTimeout(function() {
            isHanging = true;
            logError("Application appears to be hanging! Using minimal bypass set.");
            // If hanging, apply only the most essential bypasses
            essentialBypass();
        }, 5000);

        // Essential bypass for recovery in case of hanging
        function essentialBypass() {
            try {
                // Apply only the most basic and safe bypasses
                bypassJustSSLContext();
                bypassOkHttpSimple();
                logInfo("Applied minimal bypass set. App should recover now.");
            } catch (err) {
                logError("Even minimal bypass failed: " + err);
            }
        }
        
        // Simplified version of SSLContext bypass
        function bypassJustSSLContext() {
            try {
                var X509TrustManager = Java.use("javax.net.ssl.X509TrustManager");
                var SSLContext = Java.use("javax.net.ssl.SSLContext");
                
                // TrustManager with empty implementation
                var TrustManager = Java.registerClass({
                    name: "com.bypass.sslpinning.TrustManager",
                    implements: [X509TrustManager],
                    methods: {
                        checkClientTrusted: function(chain, authType) {},
                        checkServerTrusted: function(chain, authType) {},
                        getAcceptedIssuers: function() { return []; }
                    }
                });
                
                // Create a new instance of our custom TrustManager
                var TrustManagers = [TrustManager.$new()];
                
                // Get the default SSLContext
                var sslContextInit = SSLContext.init.overload(
                    "[Ljavax.net.ssl.KeyManager;", 
                    "[Ljavax.net.ssl.TrustManager;", 
                    "java.security.SecureRandom"
                );
                
                // Override the init method to use our custom TrustManager
                sslContextInit.implementation = function(keyManager, trustManager, secureRandom) {
                    logInfo("SSLContext.init() called, using custom TrustManager");
                    sslContextInit.call(this, keyManager, TrustManagers, secureRandom);
                };
                
                logSuccess("Bypassed SSLContext - essential");
            } catch (err) {
                logError("Could not bypass SSLContext: " + err);
            }
        }
        
        // Simple bypass for OkHttp
        function bypassOkHttpSimple() {
            try {
                var CertificatePinner = Java.use("okhttp3.CertificatePinner");
                if (CertificatePinner) {
                    CertificatePinner.check.overload('java.lang.String', 'java.util.List').implementation = function() {
                        logInfo("OkHTTP 3.x CertificatePinner.check bypassed");
                        return;
                    };
                    CertificatePinner.check.overload('java.lang.String', '[Ljava.security.cert.Certificate;').implementation = function() {
                        logInfo("OkHTTP 3.x CertificatePinner.check bypassed");
                        return;
                    };
                    logSuccess("OkHTTP 3.x simple bypass applied");
                }
            } catch (err) {
                logDebug("OkHttp simple bypass error: " + err);
            }
        }

        // -------------------- Android System SSL Bypass --------------------
        function bypassSystemSSL() {
            if (isHanging) return; // Skip if app is hanging
            
            logInfo("Applying Android System SSL bypass...");
            
            try {
                // Bypass TrustManagerImpl (Android > 7)
                var TrustManagerImpl = Java.use("com.android.org.conscrypt.TrustManagerImpl");
                
                if (TrustManagerImpl) {
                    // This targets recent Android versions
                    TrustManagerImpl.verifyChain.implementation = function(untrustedChain, trustAnchorChain, host, clientAuth, ocspData, tlsSctData) {
                        logInfo("TrustManagerImpl.verifyChain(" + host + ") called");
                        return untrustedChain;
                    };
                    
                    logSuccess("Bypassed TrustManagerImpl.verifyChain");
                    
                    // More granular control for Android 7+
                    if (TrustManagerImpl.checkTrustedRecursive) {
                        TrustManagerImpl.checkTrustedRecursive.implementation = function(certs, hostName, clientAuth, untrustedChain, trustAnchorChain, used) {
                            logInfo("TrustManagerImpl.checkTrustedRecursive(" + hostName + ") called");
                            return Java.use("java.util.ArrayList").$new();
                        };
                        logSuccess("Bypassed TrustManagerImpl.checkTrustedRecursive");
                    }
                }
            } catch (err) {
                logError("Could not bypass TrustManagerImpl: " + err);
            }
            
            try {
                // General bypass for different Android versions
                bypassJustSSLContext();
            } catch (err) {
                logError("Could not bypass X509TrustManager: " + err);
            }
            
            try {
                // Bypass legacy TrustManager (For older Android versions)
                var TrustManager = Java.use("javax.net.ssl.TrustManager");
                var X509TrustManager = Java.use("javax.net.ssl.X509TrustManager");
                
                // For each class that implements X509TrustManager
                // Limit to 20 classes to avoid hanging
                var classesProcessed = 0;
                Java.enumerateLoadedClasses({
                    onMatch: function(className) {
                        if (isHanging) return; // Stop if app is hanging
                        
                        if (classesProcessed > 20) return; // Limit to avoid hanging
                        
                        if (className.match(/TrustManager/i) && !className.match(/Abstract/i)) {
                            try {
                                classesProcessed++;
                                var TrustManagerClass = Java.use(className);
                                if (TrustManagerClass.checkServerTrusted) {
                                    TrustManagerClass.checkServerTrusted.implementation = function(chain, authType) {
                                        logInfo("Bypassed " + className + ".checkServerTrusted");
                                        return;
                                    };
                                    logSuccess("Added bypass for " + className);
                                }
                            } catch (err) {
                                // Not a problem if we can't match all classes
                            }
                        }
                    },
                    onComplete: function() {}
                });
            } catch (err) {
                logError("Could not enumerate and bypass TrustManagers: " + err);
            }
        }
        
        // -------------------- OkHttp Certificate Pinner Bypass --------------------
        function bypassOkHttp() {
            if (isHanging) return; // Skip if app is hanging
            
            logInfo("Applying OkHttp Certificate Pinner bypass...");
            
            try {
                // Use the simple bypass first - it's more reliable
                bypassOkHttpSimple();
                
                try {
                    // Method 2: Bypass at construction by returning empty pins
                    var CertificatePinner = Java.use("okhttp3.CertificatePinner");
                    if (CertificatePinner && !isHanging) {
                        try {
                            CertificatePinner.findMatchingPins.implementation = function() {
                                logInfo("OkHTTP 3.x: CertificatePinner.findMatchingPins bypassed");
                                return Java.use("java.util.Collections").emptyList();
                            };
                            logSuccess("OkHTTP 3.x findMatchingPins bypassed");
                        } catch (err) {
                            logDebug("OkHTTP 3.x: findMatchingPins method not found: " + err);
                        }
                    }
                } catch (err) {
                    logDebug("Additional OkHttp bypass method failed: " + err);
                }
            } catch (err) {
                logError("Could not bypass OkHTTP 3.x CertificatePinner: " + err);
            }
            
            // Only try OkHttp 2.x if the app isn't hanging
            if (!isHanging) {
                try {
                    // OkHTTP 2.x
                    var OkHttpClient = Java.use("com.squareup.okhttp.OkHttpClient");
                    if (OkHttpClient) {
                        OkHttpClient.setCertificatePinner.implementation = function(certificatePinner) {
                            logInfo("OkHTTP 2.x: OkHttpClient.setCertificatePinner bypassed");
                            return this;
                        };
                        
                        var CertificatePinner2 = Java.use("com.squareup.okhttp.CertificatePinner");
                        if (CertificatePinner2) {
                            CertificatePinner2.check.overload('java.lang.String', 'java.util.List').implementation = function(hostname, peerCertificates) {
                                logInfo("OkHTTP 2.x: CertificatePinner.check(" + hostname + ") bypassed");
                                return;
                            };
                            logSuccess("OkHTTP 2.x CertificatePinner bypassed");
                        }
                    }
                } catch (err) {
                    logDebug("Could not bypass OkHTTP 2.x CertificatePinner: " + err);
                }
            }
        }
        
        // -------------------- Trustkit Certificate Pinning Bypass --------------------
        function bypassTrustKit() {
            logInfo("Applying TrustKit bypass...");
            
            try {
                var TrustKit = Java.use("com.datatheorem.android.trustkit.pinning.TrustKit");
                if (TrustKit) {
                    TrustKit.initializeTrustKit.implementation = function(context) {
                        logInfo("TrustKit initialization bypassed");
                    };
                    
                    var PinningValidator = Java.use("com.datatheorem.android.trustkit.pinning.PinningValidator");
                    PinningValidator.validateCertificateChain.overloads.forEach(function (overload) {
                        overload.implementation = function() {
                            logInfo("TrustKit certificate validation bypassed");
                            return true;
                        };
                    });
                    
                    logSuccess("TrustKit bypassed");
                }
            } catch (err) {
                logError("Could not bypass TrustKit: " + err);
            }
        }
        
        // -------------------- Appcelerator Titanium Bypass --------------------
        function bypassTitanium() {
            logInfo("Applying Titanium bypass...");
            
            try {
                var PinningTrustManager = Java.use("appcelerator.https.PinningTrustManager");
                if (PinningTrustManager) {
                    PinningTrustManager.checkServerTrusted.implementation = function(chain, authType) {
                        logInfo("Titanium PinningTrustManager bypassed");
                        return;
                    };
                    logSuccess("Appcelerator Titanium bypassed");
                }
            } catch (err) {
                logError("Could not bypass Appcelerator Titanium: " + err);
            }
        }
        
        // -------------------- Conscrypt CertPinManager Bypass --------------------
        function bypassConscrypt() {
            logInfo("Applying Conscrypt bypass...");
            
            try {
                var CertPinManager = Java.use("com.android.org.conscrypt.CertPinManager");
                if (CertPinManager) {
                    CertPinManager.isChainValid.overload('java.lang.String', 'java.util.List').implementation = function(hostname, chain) {
                        logInfo("Conscrypt CertPinManager bypassed for " + hostname);
                        return true;
                    };
                    logSuccess("Conscrypt CertPinManager bypassed");
                }
            } catch (err) {
                logError("Could not bypass Conscrypt: " + err);
            }
        }
        
        // -------------------- Android Network Security Config Bypass --------------------
        function bypassNetworkSecurityConfig() {
            logInfo("Applying Network Security Config bypass...");
            
            try {
                var NetworkSecurityTrustManager = Java.use("android.security.net.config.NetworkSecurityTrustManager");
                if (NetworkSecurityTrustManager) {
                    NetworkSecurityTrustManager.checkPins.implementation = function(chain) {
                        logInfo("NetworkSecurityTrustManager.checkPins bypassed");
                        return;
                    };
                    logSuccess("Android Network Security Config bypassed");
                }
            } catch (err) {
                logError("Could not bypass Network Security Config: " + err);
            }
            
            // For Android 7+ we need additional bypasses as the implementation changed
            try {
                var PinningHostnameVerifier = Java.use("android.security.net.config.PinningHostnameVerifier");
                if (PinningHostnameVerifier) {
                    PinningHostnameVerifier.verify.overload('java.lang.String', 'javax.net.ssl.SSLSession').implementation = function(hostname, session) {
                        logInfo("PinningHostnameVerifier.verify bypassed for " + hostname);
                        return true;
                    };
                    logSuccess("Android PinningHostnameVerifier bypassed");
                }
            } catch (err) {
                logError("Could not bypass PinningHostnameVerifier: " + err);
            }
        }
        
        // -------------------- Bypass Apache HTTP client pinning --------------------
        function bypassApacheHTTP() {
            logInfo("Applying Apache HTTP client bypass...");
            
            try {
                var AbstractVerifier = Java.use("org.apache.http.conn.ssl.AbstractVerifier");
                if (AbstractVerifier) {
                    AbstractVerifier.verify.overload('java.lang.String', '[Ljava.lang.String', '[Ljava.lang.String', 'boolean').implementation = function() {
                        logInfo("Apache AbstractVerifier.verify bypassed");
                        return;
                    };
                    logSuccess("Apache HTTP client pinning bypassed");
                }
            } catch (err) {
                logError("Could not bypass Apache HTTP client: " + err);
            }
        }
        
        // -------------------- Bypass Phonegap/Cordova SSL Pinning --------------------
        function bypassPhonegap() {
            logInfo("Applying Phonegap/Cordova bypass...");
            
            try {
                var pluginManager = Java.use("org.apache.cordova.PluginManager");
                if (pluginManager) {
                    pluginManager.startup.implementation = function() {
                        logInfo("Phonegap PluginManager.startup modified");
                        
                        // Get original result
                        var result = this.startup();
                        
                        // After startup, disable SSL pinning plugins
                        try {
                            var sslCertificateChecker = Java.use("nl.xservices.plugins.SSLCertificateChecker");
                            sslCertificateChecker.execute.implementation = function(action, args, callbackContext) {
                                logInfo("Phonegap sslCertificateChecker.execute bypassed");
                                callbackContext.success("CONNECTION_SECURE");
                                return true;
                            };
                            logSuccess("Phonegap SSLCertificateChecker bypassed");
                        } catch (err) {
                            logDebug("Phonegap SSLCertificateChecker not found");
                        }
                        
                        return result;
                    };
                }
            } catch (err) {
                logError("Could not bypass Phonegap SSL pinning: " + err);
            }
        }
        
        // -------------------- WebView SSL Bypass --------------------
        function bypassWebViewSSL() {
            if (isHanging) return; // Skip if app is hanging
            
            logInfo("Applying WebView SSL bypass...");
            
            try {
                var WebViewClient = Java.use("android.webkit.WebViewClient");
                
                // For Android 7+
                try {
                    WebViewClient.onReceivedSslError.overload('android.webkit.WebView', 'android.webkit.SslErrorHandler', 'android.net.http.SslError').implementation = function(webView, handler, error) {
                        logInfo("WebViewClient.onReceivedSslError bypassed (proceed with SSL error)");
                        handler.proceed();
                        return;
                    };
                    logSuccess("WebViewClient SSL validation bypassed");
                } catch (err) {
                    logDebug("WebViewClient.onReceivedSslError not found: " + err);
                }
                
                // For older Android versions
                try {
                    WebViewClient.onReceivedError.overload('android.webkit.WebView', 'int', 'java.lang.String', 'java.lang.String').implementation = function(webview, errorCode, description, failingUrl) {
                        logInfo("WebViewClient.onReceivedError bypassed");
                        return;
                    };
                } catch (err) {
                    logDebug("WebViewClient.onReceivedError not found: " + err);
                }
            } catch (err) {
                logError("Could not bypass WebView SSL validation: " + err);
            }
        }
        
        // -------------------- Flutter SSL Pinning Bypass --------------------
        function bypassFlutter() {
            logInfo("Applying Flutter SSL bypass...");
            
            try {
                // First try to find the Dart-specific classes
                Java.performNow(function() {
                    try {
                        var FlutterMain = Java.use('io.flutter.embedding.engine.FlutterJNI');
                        if (FlutterMain) {
                            logInfo("Flutter detected, attempting to bypass pinning");
                            // Flutter uses native code, we'll try to bypass at the native SSL layer
                            bypassSystemSSL(); // This will handle the underlying SSL implementation
                            logSuccess("Flutter SSL pinning likely bypassed via system hooks");
                        }
                    } catch (err) {
                        logDebug("Flutter not detected: " + err);
                    }
                });
            } catch (err) {
                logError("Could not analyze Flutter: " + err);
            }
        }

        // -------------------- React Native SSL Pinning Bypass --------------------
        function bypassReactNative() {
            logInfo("Applying React Native SSL bypass...");
            
            try {
                // Check for OkHttp (commonly used in React Native)
                bypassOkHttp();
                
                // Try to find RN-specific classes
                Java.performNow(function() {
                    try {
                        var ReactInstanceManager = Java.use('com.facebook.react.ReactInstanceManager');
                        if (ReactInstanceManager) {
                            logInfo("React Native detected");
                            // React Native also uses native network modules
                            // System SSL bypass should handle this
                            logSuccess("React Native SSL pinning likely bypassed via OkHttp and system hooks");
                        }
                    } catch (err) {
                        logDebug("React Native not detected: " + err);
                    }
                });
            } catch (err) {
                logError("Could not analyze React Native: " + err);
            }
        }
        
        // -------------------- Universal Android SSL Pinning Bypass --------------------
        function universalAndroidSSLBypass() {
            if (isHanging) return; // Skip if app is hanging
            
            logInfo("Applying universal Android SSL bypass...");
            
            // HttpsURLConnection bypass (many libraries use this)
            try {
                var HttpsURLConnection = Java.use("javax.net.ssl.HttpsURLConnection");
                
                // Try with three individual overrides instead of chaining them
                try {
                    HttpsURLConnection.setDefaultHostnameVerifier.implementation = function(hostnameVerifier) {
                        logInfo("HttpsURLConnection.setDefaultHostnameVerifier bypassed");
                        return;
                    };
                } catch (err) {
                    logDebug("setDefaultHostnameVerifier bypass failed: " + err);
                }
                
                try {
                    HttpsURLConnection.setSSLSocketFactory.implementation = function(sslSocketFactory) {
                        logInfo("HttpsURLConnection.setSSLSocketFactory bypassed");
                        return;
                    };
                } catch (err) {
                    logDebug("setSSLSocketFactory bypass failed: " + err);
                }
                
                try {
                    HttpsURLConnection.setHostnameVerifier.implementation = function(hostnameVerifier) {
                        logInfo("HttpsURLConnection.setHostnameVerifier bypassed");
                        return;
                    };
                } catch (err) {
                    logDebug("setHostnameVerifier bypass failed: " + err);
                }
                
                logSuccess("HttpsURLConnection bypassed");
            } catch (err) {
                logError("Could not bypass HttpsURLConnection: " + err);
            }
            
            // Hostname verifier bypass - only do this if not hanging
            if (!isHanging) {
                try {
                    var HostnameVerifier = Java.use("javax.net.ssl.HostnameVerifier");
                    var SSLBypassHostnameVerifier = Java.registerClass({
                        name: "SSLBypassHostnameVerifier",
                        implements: [HostnameVerifier],
                        methods: {
                            verify: function(hostname, session) {
                                logInfo("AllowAllHostnameVerifier.verify bypassed for " + hostname);
                                return true;
                            }
                        }
                    });
                    
                    var hostnameVerifierInstance = SSLBypassHostnameVerifier.$new();
                    
                    var HttpsURLConnection = Java.use("javax.net.ssl.HttpsURLConnection");
                    HttpsURLConnection.setDefaultHostnameVerifier.implementation = function(hostnameVerifier) {
                        logInfo("HttpsURLConnection.setDefaultHostnameVerifier intercepted");
                        this.setDefaultHostnameVerifier(hostnameVerifierInstance);
                    };
                    
                    HttpsURLConnection.setHostnameVerifier.implementation = function(hostnameVerifier) {
                        logInfo("HttpsURLConnection.setHostnameVerifier intercepted");
                        this.setHostnameVerifier(hostnameVerifierInstance);
                    };
                    
                    logSuccess("HostnameVerifier globally bypassed");
                } catch (err) {
                    logError("Could not bypass HostnameVerifier: " + err);
                }
            }
        }
        
        // Step-by-step staggered execution to minimize risk of hanging
        function executeBypassesWithDelay() {
            // Cancel the watchdog as we're using our own timing
            clearTimeout(watchdogTimer);
            
            // Apply essential bypasses first
            bypassJustSSLContext();
            bypassOkHttpSimple();
            
            // If app hasn't crashed, continue with more complex bypasses
            setTimeout(function() {
                if (!isHanging) {
                    try {
                        universalAndroidSSLBypass();
                        bypassSystemSSL();
                    } catch (err) {
                        logError("Error in second phase bypasses: " + err);
                    }
                    
                    // If still working, add additional bypasses
                    setTimeout(function() {
                        if (!isHanging) {
                            try {
                                bypassOkHttp();
                                bypassWebViewSSL();
                            } catch (err) {
                                logError("Error in third phase bypasses: " + err);
                            }
                            
                            logSuccess("SSL Pinning Bypass Complete!");
                        }
                    }, 500);
                }
            }, 500);
        }
        
        // Start the execution with a safer approach
        executeBypassesWithDelay();
        
        // Inject a special handler to catch and report unhandled exceptions
        try {
            Java.perform(function() {
                var Thread = Java.use('java.lang.Thread');
                var ThreadGroup = Java.use('java.lang.ThreadGroup');
                
                ThreadGroup.uncaughtException.implementation = function(thread, ex) {
                    logError("Uncaught exception in thread '" + thread.getName() + "': " + ex);
                    // Call the original implementation
                    this.uncaughtException(thread, ex);
                };
                
                Thread.dispatchUncaughtException.implementation = function(e) {
                    logError("Uncaught exception dispatched: " + e);
                    // Call the original implementation
                    this.dispatchUncaughtException(e);
                };
            });
        } catch (err) {
            logDebug("Could not set exception handler: " + err);
        }
    });
}, 0);

// Usage instructions:
// 1. Activate your virtual environment: source frida_venv/bin/activate
// 2. Start Frida server on your emulator: adb shell 'nohup /data/local/tmp/frida-server > /dev/null 2>&1 &'
// 3. Find your target app: frida-ps -U | grep <app_name>
// 4. Attach to the app and load this script: frida -U -l ssl_pinning_bypass.js <app_package_name>
// 5. Or spawn the app with the script: frida -U -l ssl_pinning_bypass.js -f <app_package_name> --no-pause
//
// If the app hangs, try with the safer mode:
// frida -U -l ssl_pinning_bypass.js <app_package_name> --runtime=v8 