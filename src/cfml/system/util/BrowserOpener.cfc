/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* CFML port of runwar.BrowserOpener
*
*/
component singleton {

	property name="logger" inject="logbox:logger:{this}";

	/**
	 * Open a URL in a browser, honoring an optional preferred browser with OS-specific fallbacks.
	 *
	 * @url The URL to open.
	 * @preferred_browser Preferred browser key (or "default").
	 */
	function openURL( required string url, string preferred_browser = "" ) {
		var osName = createObject( "java", "java.lang.System" ).getProperty( "os.name" );
		if( !len( arguments.url ) ) {
			logWarn( "ERROR: No URL specified to open the browser to!" );
			return;
		}

		if( !len( arguments.preferred_browser ) ) {
			arguments.preferred_browser = "default";
		}

		try {
			if( osName.startsWith( "Mac OS" ) ) {
				if( !arguments.preferred_browser.equalsIgnoreCase( "default" ) ) {
					try {
						openInBrowser( arguments.preferred_browser, arguments.url, 2 );
					} catch( any e ) {
						logInfo( "Launching on default browser due:", e );
						defaultMac( arguments.url );
					}
				} else {
					defaultMac( arguments.url );
				}
			} else if( osName.startsWith( "Windows" ) ) {
				if( !arguments.preferred_browser.equalsIgnoreCase( "default" ) ) {
					try {
						openInBrowser( arguments.preferred_browser, arguments.url, 1 );
					} catch( any e ) {
						logInfo( "Launching on default browser due:", e );
						createObject( "java", "java.lang.Runtime" )
							.getRuntime()
							.exec( "rundll32 url.dll,FileProtocolHandler #arguments.url#" );
					}
				} else {
					createObject( "java", "java.lang.Runtime" )
						.getRuntime()
						.exec( "rundll32 url.dll,FileProtocolHandler #arguments.url#" );
				}
			} else {
				try {
					if( !arguments.preferred_browser.equalsIgnoreCase( "default" ) ) {
						try {
							openInBrowser( arguments.preferred_browser, arguments.url, 3 );
						} catch( any e ) {
							logInfo( "Launching on default browser due:", e );
							defaultNix( arguments.url );
						}
					} else {
						defaultNix( arguments.url );
					}
				} catch( any e ) {
					logError( "Default browser launch failed.", e );
					if( isWindows() ) {
						openInBrowser( arguments.preferred_browser, arguments.url, 1 );
					} else if( isMac() ) {
						openInBrowser( arguments.preferred_browser, arguments.url, 2 );
					} else {
						openInBrowser( arguments.preferred_browser, arguments.url, 3 );
					}
				}
			}
		} catch( any e ) {
			logError( "Error attempting to launch web browser.", e );
			try {
				createObject( "java", "javax.swing.JOptionPane" )
					.showMessageDialog( javacast( "null", "" ), "Error attempting to launch web browser:#chr( 10 )##e.localizedMessage ?: e.message#" );
			} catch( any ignored ) {}
		}
	}

	/**
	 * Open a URL with the default desktop browser on Linux/Unix.
	 *
	 * @url The URL to open.
	 */
	function defaultNix( required string url ) {
		createObject( "java", "java.awt.Desktop" )
			.getDesktop()
			.browse( createObject( "java", "java.net.URI" ).init( arguments.url ) );
	}

	/**
	 * Open a URL with the default browser on macOS.
	 *
	 * @url The URL to open.
	 */
	function defaultMac( required string url ) {
		createObject( "java", "java.lang.Runtime" )
			.getRuntime()
			.exec( [ "open", arguments.url ] );
	}

	/**
	 * Open a URL in a specific browser for the provided OS code.
	 *
	 * @preferred_browser Preferred browser key (or "default").
	 * @url The URL to open.
	 * @os OS selector (1=Windows, 2=macOS, 3=*nix).
	 */
	function openInBrowser( required string preferred_browser, required string url, required numeric os ) {
		var browsers = [ "firefox", "chrome", "opera", "konqueror", "epiphany" ];

		if( !arguments.preferred_browser.equalsIgnoreCase( "default" ) ) {
			switch( arguments.os ) {
				case 1:
					openUrlInBrowserOnWindows( arguments.preferred_browser, arguments.url );
					break;
				case 2:
					openUrlInBrowserOnMacOS( arguments.preferred_browser, arguments.url );
					break;
				case 3:
					try {
						createObject( "java", "java.lang.Runtime" ).getRuntime().exec( [ arguments.preferred_browser, arguments.url ] );
					} catch( any e ) {
						logError( "Could not find preferred web browser.", e );
						searchAvailableBrowser( browsers, arguments.url );
					}
					break;
			}
		} else {
			searchAvailableBrowser( browsers, arguments.url );
		}
	}

	/**
	 * Search for the first available browser command and open the URL.
	 *
	 * @browsers Ordered browser executable names to test.
	 * @url The URL to open.
	 */
	function searchAvailableBrowser( required array browsers, required string url ) {
		var browser = "";
		var runtime = createObject( "java", "java.lang.Runtime" ).getRuntime();
		for( var thisBrowser in arguments.browsers ) {
			if( !len( browser ) && runtime.exec( [ "which", thisBrowser ] ).waitFor() == 0 ) {
				browser = thisBrowser;
			}
		}

		if( !len( browser ) ) {
			logError( "Could not find web browser." );
			throw( message = "Could not find web browser" );
		}

		runtime.exec( [ browser, arguments.url ] );
	}

	/**
	 * Open a URL on Windows using a preferred browser or the default handler.
	 *
	 * @preferredBrowser Preferred browser key (or "default").
	 * @url The URL to open.
	 */
	function openUrlInBrowserOnWindows( required string preferredBrowser, required string url ) {
		try {
			var browsers = {
				"firefox" : "firefox",
				"chrome" : "chrome",
				"edge" : "MicrosoftEdge",
				"ie" : "iexplore",
				"opera" : "opera"
			};
			var runtime = createObject( "java", "java.lang.Runtime" ).getRuntime();

			if( !arguments.preferredBrowser.equalsIgnoreCase( "default" ) && hasBrowserKey( browsers, arguments.preferredBrowser ) ) {
				runtime.exec( [ "cmd.exe", "/c", "start", browsers[ lcase( arguments.preferredBrowser ) ], arguments.url ] );
			} else {
				runtime.exec( [ "cmd.exe", "/c", "start", arguments.url ] );
			}
		} catch( any e ) {
			logError( "Error opening Browser.", e );
			rethrow;
		}
	}

	/**
	 * Open a URL on macOS using AppleScript with a preferred browser or default handler.
	 *
	 * @preferredBrowser Preferred browser key (or "default").
	 * @url The URL to open.
	 */
	function openUrlInBrowserOnMacOS( required string preferredBrowser, required string url ) {
		try {
			var browsers = {
				"firefox" : "Firefox",
				"chrome" : "Google Chrome",
				"edge" : "Microsoft Edge",
				"safari" : "Safari",
				"opera" : "Opera"
			};
			var runtime = createObject( "java", "java.lang.Runtime" ).getRuntime();

			if( !arguments.preferredBrowser.equalsIgnoreCase( "default" ) && hasBrowserKey( browsers, arguments.preferredBrowser ) ) {
				var applescriptCommand = 'tell application "#browsers[ lcase( arguments.preferredBrowser ) ]#"#chr( 10 )#'
					& '     open location "#arguments.url#"#chr( 10 )#'
					& 'end tell';
				runtime.exec( [ "osascript", "-e", applescriptCommand ] );
			} else {
				runtime.exec( [ "osascript", "-e", 'open location "#arguments.url#"' ] );
			}
		} catch( any e ) {
			logError( "Error opening Browser.", e );
			rethrow;
		}
	}

	/**
	 * Case-insensitive browser key lookup in a struct of supported browsers.
	 *
	 * @browsers Browser key/value map.
	 * @key Browser key to look up.
	 */
	private boolean function hasBrowserKey( required struct browsers, required string key ) {
		return structKeyExists( arguments.browsers, lcase( arguments.key ) );
	}

	/**
	 * Determine if the current OS is Windows.
	 */
	private boolean function isWindows() {
		return createObject( "java", "java.lang.System" ).getProperty( "os.name" ).lcase().contains( "win" );
	}

	/**
	 * Determine if the current OS is macOS.
	 */
	private boolean function isMac() {
		return createObject( "java", "java.lang.System" ).getProperty( "os.name" ).lcase().contains( "mac" );
	}

	/**
	 * Log a warning message if a logger is available.
	 *
	 * @message Message text.
	 */
	private function logWarn( required string message ) {
		if( !isObject( variables.logger ) ) {
			return;
		}
		try {
			variables.logger.warn( arguments.message );
		} catch( any ignored ) {}
	}

	/**
	 * Log an info message and optional exception if a logger is available.
	 *
	 * @message Message text.
	 * @exception Optional exception object.
	 */
	private function logInfo( required string message, any exception ) {
		if( !isObject( variables.logger ) ) {
			return;
		}
		try {
			variables.logger.info( arguments.message, arguments.exception );
		} catch( any ignored ) {}
	}

	/**
	 * Log an error message and optional exception if a logger is available.
	 *
	 * @message Message text.
	 * @exception Optional exception object.
	 */
	private function logError( required string message, any exception ) {
		if( !isObject( variables.logger ) ) {
			return;
		}
		try {
			if( structKeyExists( arguments, "exception" ) && !isNull( arguments.exception ) ) {
				variables.logger.error( arguments.message, arguments.exception );
			} else {
				variables.logger.error( arguments.message );
			}
		} catch( any ignored ) {}
	}
}