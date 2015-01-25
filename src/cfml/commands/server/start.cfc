/**
 * Start an embedded CFML server.  Run command from the web root of the server.
 * .
 * {code:bash}
 * server start
 * {code}
 **/
component extends="commandbox.system.BaseCommand" aliases="start" excludeFromHelp=false {

	// DI
	property name="serverService" 	inject="ServerService";
	property name="packageService" 	inject="packageService";

	/**
	 * @port.hint            port number
	 * @host.hint            bind to a host/ip
	 * @openbrowser.hint     open a browser after starting
	 * @directory.hint       web root for this server
	 * @name.hint            short name for this server
	 * @stopPort.hint        stop socket listener port number
	 * @force.hint           force start if status is not stopped
	 * @debug.hint           sets debug log level
	 * @webConfigDir.hint    custom location for railo web context configuration
	 * @serverConfigDir.hint custom location for railo server configuration
	 * @libDirs.hint         comma separated list of extra lib directories for the Railo server
	 * @trayIcon.hint        path to .png file for tray icon
	 * @webXml.hint          path to web.xml file used to configure the Railo server
	 * @enableHTTP.hint      enable HTTP
	 * @enableSSL.hint       enable SSL
	 * @SSLPort.hint       	 SSL port number
	 * @SSLCert.hint         SSL certificate
	 * @SSLKey.hint          SSL key (required if SSLCert specified)
	 * @SSLKeyPass.hint      SSL key passphrase (required if SSLCert specified)
	 * @rewrites.hint        enable URL rewriting (default true)
	 * @rewritesConfig.hint  optional URL rewriting config file path
	 **/
	function run(
		Numeric port            = 0,
		String	host            = "127.0.0.1",
		Boolean openbrowser     = true,
		String  directory       = "",
		String  name            = "",
		Numeric stopPort        = 0,
		Boolean force           = false,
		Boolean debug           = false,
		String  webConfigDir    = "",
		String  serverConfigDir = "",
		String  libDirs         = "",
		String  trayIcon        = "",
		String  webXml          = "",
		Boolean enableHTTP 		= true,
		Boolean enableSSL 		= false,
		Numeric SSLPort 		= 1443,
		String  SSLCert 		= "",
		String  SSLKey 			= "",
		String  SSLKeyPass 		= "",
		Boolean rewrites 		= true,
		String  rewritesConfig  = ""
	){
		// Resolve path as used locally
		var webroot = fileSystemUtil.resolvePath( arguments.directory );

		// Discover by shortname or webroot and get server info
		var serverInfo = serverService.getServerInfoByDiscovery(
			directory 	= webroot,
			name		= arguments.name
		);

		// Was it found, or new server?
		if( structIsEmpty( serverInfo ) ){
			// We need a new entry
			serverInfo = serverService.getServerInfo( webroot );
		}

		// Get package descriptor for overrides
		var boxJSON = packageService.readPackageDescriptor( webroot );

		// Update data from arguments
		serverInfo.webroot 	= webroot;
		serverInfo.debug 	= arguments.debug;
		serverInfo.name 	= arguments.name is "" ? listLast( webroot, "\/" ) : arguments.name;
		serverInfo.host 	= arguments.host;

		// we don't want to changes the ports if we're doing stuff already
		if( serverInfo.status is "stopped" || arguments.force ){
			// Box Desriptor check for port first.
			if( boxJSON.defaultPort != 0 ) {
				serverInfo.port = boxJSON.defaultPort;
			}
			// Check the arguments as the last overrides
			if( arguments.port != 0 ){
				serverInfo.port = arguments.port;
			}
			if( arguments.stopPort != 0 ){
				serverInfo.stopsocket = arguments.stopPort;
			}
		}

		// Setup serverinfo according to params
		if ( Len( Trim( arguments.webConfigDir    ) ) ) { serverInfo.webConfigDir    = arguments.webConfigDir;    }
		if ( Len( Trim( arguments.serverConfigDir ) ) ) { serverInfo.serverConfigDir = arguments.serverConfigDir; }
		if ( Len( Trim( arguments.libDirs         ) ) ) { serverInfo.libDirs         = arguments.libDirs;         }
		if ( Len( Trim( arguments.trayIcon        ) ) ) { serverInfo.trayIcon        = arguments.trayIcon;        }
		if ( Len( Trim( arguments.webXml          ) ) ) { serverInfo.webXml          = arguments.webXml;          }
		if ( Len( Trim( arguments.enableSSL       ) ) ) { serverInfo.enableSSL       = arguments.enableSSL;       }
		if ( Len( Trim( arguments.enableHTTP      ) ) ) { serverInfo.enableHTTP      = arguments.enableHTTP;      }
		if ( Len( Trim( arguments.SSLPort         ) ) ) { serverInfo.SSLPort         = arguments.SSLPort;         }
		if ( Len( Trim( arguments.SSLCert         ) ) ) { serverInfo.SSLCert         = arguments.SSLCert;         }
		if ( Len( Trim( arguments.SSLKey          ) ) ) { serverInfo.SSLKey          = arguments.SSLKey;          }
		if ( Len( Trim( arguments.SSLKeyPass      ) ) ) { serverInfo.SSLKeyPass      = arguments.SSLKeyPass;      }
		if ( Len( Trim( arguments.rewrites        ) ) ) { serverInfo.rewrites        = arguments.rewrites;        }
		if ( Len( Trim( arguments.rewritesConfig  ) ) ) { serverInfo.rewritesConfig  = arguments.rewritesConfig;  }

		// startup the service using server info struct, the start service takes care of persisting updated params
		return serverService.start(
			serverInfo 	= serverInfo,
			openBrowser = arguments.openbrowser,
			force		= arguments.force,
			debug 		= arguments.debug
		);
	}

}
