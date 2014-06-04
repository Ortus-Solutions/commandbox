/**
 * Start a CFMLserver
 **/
component extends="commandbox.system.BaseCommand" aliases="start" excludeFromHelp=false {

	property name="serverService" inject="ServerService";
	
	/**
	 * @port.hint            port number
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
	 **/
	function run( 
		Numeric port            = 0,
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
		String  webXml          = ""
	){
		// prepare webroot and short name
		var webroot = arguments.directory is "" ? shell.pwd() : arguments.directory;
		var name 	= arguments.name is "" ? listLast( webroot, "\/" ) : arguments.name;
		webroot = fileSystemUtil.resolvePath( webroot );
		
		// get server info record, create one if this is the first time.
		var serverInfo = serverService.getServerInfo( webroot );
		// we don't want to changes the ports if we're doing stuff already
		if( serverInfo.status is "stopped" || arguments.force ){
			serverInfo.name = name;
			serverInfo.port = arguments.port;
			serverInfo.stopsocket = arguments.stopPort;
		}
		serverInfo.webroot 	= webroot;
		serverInfo.debug 	= arguments.debug;

		if ( Len( Trim( arguments.webConfigDir    ) ) ) { serverInfo.webConfigDir    = arguments.webConfigDir;    }
		if ( Len( Trim( arguments.serverConfigDir ) ) ) { serverInfo.serverConfigDir = arguments.serverConfigDir; }
		if ( Len( Trim( arguments.libDirs         ) ) ) { serverInfo.libDirs         = arguments.libDirs;         }
		if ( Len( Trim( arguments.trayIcon        ) ) ) { serverInfo.trayIcon        = arguments.trayIcon;        }
		if ( Len( Trim( arguments.webXml          ) ) ) { serverInfo.webXml          = arguments.webXml;          }

		// startup the service using server info struct
		return serverService.start( serverInfo, arguments.openbrowser, arguments.force, arguments.debug );
	}

}