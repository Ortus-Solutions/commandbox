/**
 * Start an embedded CFML server.  Run command from the web root of the server.
 * Please also remember to look at the plethora of arguments this command has as you can start your server with SSL, rewrites and much more.
 * .
 * {code:bash}
 * server start
 * {code}
 * .
 * Start with rewrites enabled
 * {code:bash}
 * server start --rewritesEnable
 * {code}
 * .
 * Start with specifc heap size
 * {code:bash}
 * server start heapSize=768
 * {code}
 **/
component extends="commandbox.system.BaseCommand" aliases="start" excludeFromHelp=false {

	// DI
	property name="serverService" 	inject="ServerService";
	property name="packageService" 	inject="packageService";

	/**
	 * @name           	short name for this server`
	 * @name.optionsUDF	serverNameComplete
	 * @port           	port number
	 * @host           	bind to a host/ip
	 * @openbrowser    	open a browser after starting
	 * @directory      	web root for this server
	 * @stopPort       	stop socket listener port number
	 * @force          	force start if status is not stopped
	 * @debug          	sets debug log level
	 * @webConfigDir   	custom location for web context configuration
	 * @serverConfigDir	custom location for server configuration
	 * @libDirs        	comma-separated list of extra lib directories for the server
	 * @trayIcon       	path to .png file for tray icon
	 * @webXML         	path to web.xml file used to configure the server
	 * @HTTPEnable     	enable HTTP
	 * @SSLEnable      	enable SSL
	 * @SSLPort        	SSL port number
	 * @SSLCert        	SSL certificate
	 * @SSLKey         	SSL key (required if SSLCert specified)
	 * @SSLKeyPass     	SSL key passphrase (required if SSLCert specified)
	 * @rewritesEnable 	enable URL rewriting (default false)
	 * @rewritesConfig 	optional URL rewriting config file path
	 * @heapSize		The max heap size in megabytes you would like this server to start with, it defaults to 512mb
	 **/
	function run(
		String  name            = "",
		Numeric port            = 0,
		String	host            = "127.0.0.1",
		Boolean openbrowser     = true,
		String  directory       = "",
		Numeric stopPort        = 0,
		Boolean force           = false,
		Boolean debug           = false,
		String  webConfigDir    = "",
		String  serverConfigDir = "",
		String  libDirs         = "",
		String  trayIcon        = "",
		String  webXML          = "",
		Boolean HTTPEnable 		= true,
		Boolean SSLEnable,
		Numeric SSLPort 		= 1443,
		String  SSLCert 		= "",
		String  SSLKey 			= "",
		String  SSLKeyPass 		= "",
		Boolean rewritesEnable	= false,
		String  rewritesConfig  = "",
		Numeric heapSize		= 0
	){
		// Resolve path as used locally
		var webroot = fileSystemUtil.resolvePath( arguments.directory );

		// Discover by shortname or server and get server info
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
		var boxJSON = packageService.readPackageDescriptor( serverInfo.webroot );

		// Update data from arguments
		serverInfo.debug 	= arguments.debug;
		serverInfo.name 	= arguments.name is "" ? listLast( serverInfo.webroot, "\/" ) : arguments.name;
		serverInfo.host 	= arguments.host;

		// TODO: I think all these defaults should be consolodated into the ServerService.
		// We're currently defaulting a lot of this stuff twice.

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
		if( Len( Trim( arguments.webConfigDir    ) ) ) { serverInfo.webConfigDir    = arguments.webConfigDir;    }
		if( Len( Trim( arguments.serverConfigDir ) ) ) { serverInfo.serverConfigDir = arguments.serverConfigDir; }
		if( Len( Trim( arguments.libDirs         ) ) ) { serverInfo.libDirs         = arguments.libDirs;         }
		if( Len( Trim( arguments.trayIcon        ) ) ) { serverInfo.trayIcon        = arguments.trayIcon;        }
		if( Len( Trim( arguments.webXML          ) ) ) { serverInfo.webXML          = arguments.webXML;          }
		if( !isNull( arguments.SSLEnable 			) ) { serverInfo.SSLEnable 		 = arguments.SSLEnable;  	  }
		if( Len( Trim( arguments.HTTPEnable      ) ) ) { serverInfo.HTTPEnable      = arguments.HTTPEnable;      }
		if( Len( Trim( arguments.SSLPort         ) ) ) { serverInfo.SSLPort         = arguments.SSLPort;         }
		if( Len( Trim( arguments.SSLCert         ) ) ) { serverInfo.SSLCert         = arguments.SSLCert;         }
		if( Len( Trim( arguments.SSLKey          ) ) ) { serverInfo.SSLKey          = arguments.SSLKey;          }
		if( Len( Trim( arguments.SSLKeyPass      ) ) ) { serverInfo.SSLKeyPass      = arguments.SSLKeyPass;      }
		if( !isNull( arguments.rewritesEnable 		) ) { serverInfo.rewritesEnable  = arguments.rewritesEnable;  }
		if( Len( Trim( arguments.rewritesConfig  ) ) ) { serverInfo.rewritesConfig  = arguments.rewritesConfig;  }
		if( arguments.heapSize != 0 ){ serverInfo.heapSize = arguments.heapSize; }

		// startup the service using server info struct, the start service takes care of persisting updated params
		return serverService.start(
			serverInfo 	= serverInfo,
			openBrowser = arguments.openbrowser,
			force		= arguments.force,
			debug 		= arguments.debug
		);
	}
	
	/**
	* Complete server names
	*/
	function serverNameComplete() {
		return serverService.getServerNames();
	}
	
}