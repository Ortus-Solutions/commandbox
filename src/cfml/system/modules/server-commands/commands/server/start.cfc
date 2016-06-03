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
 * .
 * The default CF engine is the version of Lucee Server that the CLI is running on.
 * You can also start Adobe ColdFusion engines as well as Railo Server using the "cfengine" parameter.
 * Specify an engine version after an @ sign like you would on package installation.
  * .
 * {code:bash}
 * server start cfengine=railo
 * server start cfengine=adobe
 * server start cfengine=adobe@11.0
 * {code}
 * .
 * cfengine can also be any valid Endpoint ID that points to a ForgeBox entry, HTTP URL, etc.
 * .
 * {code:bash}
 * server start cfengine=http://downloads.ortussolutions.com/adobe/coldfusion/9.0.2/cf-engine-9.0.2.zip
 * {code}
 * .
 * You can also start up a local WAR file with the WARPath parmeter.
  * .
 * {code:bash}
 * server start WARPath=/path/to/explodedWAR
 * server start WARPath=/path/to/WARArchive.war
 * {code}
 **/
component aliases="start" {

	// DI
	property name="serverService" 	inject="ServerService";
	property name="forgeBox" 		inject="ForgeBox";

	/**
	 * @name           		short name for this server or a path to the server.json file.
	 * @name.optionsUDF		serverNameComplete
	 * @port           		port number
	 * @host           		bind to a host/ip
	 * @openbrowser    		open a browser after starting
	 * @directory     	 	web root for this server
	 * @stopPort       		stop socket listener port number
	 * @force          		force start if status is not stopped
	 * @debug          		sets debug log level
	 * @webConfigDir  	 	custom location for web context configuration
	 * @serverConfigDir		custom location for server configuration
	 * @libDirs       	 	comma-separated list of extra lib directories for the server
	 * @trayIcon       		path to .png file for tray icon
	 * @webXML         		path to web.xml file used to configure the server
	 * @HTTPEnable     		enable HTTP
	 * @SSLEnable      		enable SSL
	 * @SSLPort        		SSL port number
	 * @SSLCert        		SSL certificate
	 * @SSLKey         		SSL key (required if SSLCert specified)
	 * @SSLKeyPass     		SSL key passphrase (required if SSLCert specified)
	 * @rewritesEnable 		enable URL rewriting (default false)
	 * @rewritesConfig 		optional URL rewriting config file path
	 * @heapSize			The max heap size in megabytes you would like this server to start with, it defaults to 512mb
	 * @directoryBrowsing 	Enable/Disabled directory browsing, defaults to true
	 * @JVMArgs 			Additional JVM args to use when starting the server. Use "server status --verbose" to debug
	 * @runwarArgs 			Additional Runwar options to use when starting the server. Use "server status --verbose" to debug
	 * @saveSettings 		Save start settings in server.json
	 * @cfengine        	sets the cfml engine type
	 * @cfengine.optionsUDF  cfengineNameComplete
	 * @WARPath				sets the path to an existing war to use
	 * @serverConfigFile 	The path to the server's JSON file.  Created if it doesn't exist.
	 
	 **/
	function run(
		String  name,
		Numeric port,
		String	host,
		Boolean openbrowser,
		String  directory,
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
		String  WARPath,
		String serverConfigFile
	){
		// Resolve path as used locally
		if( !isNull( arguments.directory ) ) {
			arguments.directory = fileSystemUtil.resolvePath( arguments.directory );
		} 
		if( !isNull( arguments.serverConfigFile ) ) {
			arguments.serverConfigFile = fileSystemUtil.resolvePath( arguments.serverConfigFile );
		}
		if( !isNull( arguments.WARPath ) ) {
			arguments.WARPath = fileSystemUtil.resolvePath( arguments.WARPath );
		}

		// This is a common mis spelling
		if( structKeyExists( arguments, 'rewritesEnabled' ) ) {
			print.yellowLine( 'Auto-correcting "rewritesEnabled" to "rewritesEnable".' );
			// Let's fix that up for them.
			arguments.rewritesEnable = arguments.rewritesEnabled;
			structDelete( arguments, 'rewritesEnabled' );
		}

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
	function cfengineNameComplete( string paramSoFar ) {
		
		try {
			// Get auto-complete options
			return forgebox.slugSearch( arguments.paramSoFar, 'cf-engines' );	
		} catch( forgebox var e ) {
			// Gracefully handle ForgeBox issues
			print
				.line()
				.yellowLine( e.message & chr( 10 ) & e.detail )
				.toConsole();
			// After outputting the message above on a new line, but the user back where they started.
			getShell().getReader().redrawLine();
		}
		// In case of error, break glass.
		return [];
	}

}
