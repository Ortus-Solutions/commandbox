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
component aliases="start" {

	// DI
	property name="serverService" 	inject="ServerService";

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
	 * @directoryBrowsing Enable/Disabled directory browsing, defaults to true
	 * @JVMArgs 		Additional JVM args to use when starting the server. Use "server status --verbose" to debug
	 * @runwarArgs 		Additional Runwar options to use when starting the server. Use "server status --verbose" to debug
	 * @saveSettings 	Save start settings in server.json
	 * @cfengine        sets the cfml engine type
	 * @cfengine.optionsUDF  cfengineNameComplete
	 * @WARPath			sets the path to an existing war to use
	 **/
	function run(
		String  name,
		Numeric port,
		String	host,
		Boolean openbrowser,
		String  directory = "",
		Numeric stopPort,
		Boolean force,
		Boolean debug,
		String  webConfigDir,
		String  serverConfigDir,
		String  libDirs,
		String  trayIcon,
		String  webXML,
		Boolean HTTPEnable,
		Boolean SSLEnable,
		Numeric SSLPort,
		String  SSLCert,
		String  SSLKey,
		String  SSLKeyPass,
		Boolean rewritesEnable,
		String  rewritesConfig,
		Numeric heapSize,
		boolean directoryBrowsing,
		String  JVMArgs,
		String  runwarArgs,
		boolean	saveSettings=true,
		String  cfengine,
		String  WARPath
	){
		// Resolve path as used locally
		arguments.directory = fileSystemUtil.resolvePath( arguments.directory );

		// startup the server
		return serverService.start( serverProps = arguments );
	}
	
	/**
	* Complete server names
	*/
	function serverNameComplete() {
		return serverService.getServerNames();
	}
	
	/**
	* Complete cfengine names
	*/
	function cfengineNameComplete() {
		return serverService.getCFEngineNames();
	}

}
