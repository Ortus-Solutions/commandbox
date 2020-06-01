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
	property name="javaService" 	inject="JavaService";
	property name="endpointService" inject="endpointService";
	
	/**
	 * @name           		short name for this server or a path to the server.json file.
	 * @name.optionsFileComplete true
	 * @name.optionsUDF		serverNameComplete
	 * @port           		port number
	 * @host           		bind to a host/ip
	 * @openbrowser    		open a browser after starting
	 * @directory     	 	web root for this server
	 * @stopPort       		stop socket listener port number
	 * @force          		force start if status is not stopped
	 * @debug          		Turns on debug output while starting and streams server output to console.
	 * @webConfigDir  	 	custom location for web context configuration
	 * @serverConfigDir		custom location for server configuration
	 * @libDirs       	 	comma-separated list of extra lib directories for the server to load
	 * @trayIconFile   		path to .png file for tray icon
	 * @webXML         		path to web.xml file used to configure the server
	 * @HTTPEnable     		enable HTTP
	 * @SSLEnable      		enable SSL
	 * @SSLPort        		SSL port number
	 * @SSLCertFile    		Path to SSL certificate file
	 * @SSLKeyFile     		Path to SSL key file (required if SSLCert specified)
	 * @SSLKeyPass     		SSL key passphrase
	 * @rewritesEnable 		enable URL rewriting (default false)
	 * @rewritesConfig 		optional URL rewriting config file path
	 * @heapSize			The max heap size in megabytes you would like this server to start with, it defaults to 512mb
	 * @minHeapSize			The min heap size in megabytes you would like this server to start with
	 * @directoryBrowsing 	Enable/Disabled directory browsing, defaults to false
	 * @JVMArgs 			Additional JVM args to use when starting the server. Use "server status --verbose" to debug
	 * @runwarJarPath		path to runwar jar (overrides the default runwar location in the ~/.CommandBox/lib/ folder)
	 * @runwarArgs 			Additional Runwar options to use when starting the server. Use "server status --verbose" to debug
	 * @saveSettings 		Save start settings in server.json
	 * @cfengine        	sets the cfml engine type
	 * @cfengine.optionsUDF cfengineNameComplete
	 * @WARPath				sets the path to an existing war to use
	 * @serverConfigFile 	The path to the server's JSON file.  Created if it doesn't exist.
	 * @startTimeout 		The amount of time in seconds to wait for the server to start (in the background).
	 * @console				Start this server in the forground console process and wait until Ctrl-C is pressed to stop it.
	 * @welcomeFiles		A comma-delimited list of default files to load when visiting a directory (index.cfm,index.htm,etc)
	 * @serverHomeDirectory	The folder where the CF engine WAR should be extracted
	 * @restMappings		A comma-delimited list of REST mappings in the form of /api/*,/rest/*.  Empty string to disable.
	 * @trace				Enable trace level logging
	 * @javaHomeDirectory	Path to the JRE home directory containing ./bin/java
	 * @AJPEnable			Enable AJP
	 * @AJPPort				AJP Port number
	 * @javaVersion			Any endpoint ID, such as "java:openjdk11" from the Java endpoint 
	 * @javaVersion.optionsUDF	javaVersionComplete
	 * @startScript			If you want to generate a native script to directly start the server process pass bash, cmd, or pwsh
	 * @startScript.options	bash,cmd,pwsh
	 * @startScriptFile		Optional override for the name and location of the start script. This is ignored if no startScript param is specified
	 * @dryRun				Pass true to abort actually starting the server process, but all instalation and downloading will still be performed to "warm up" the engine installation.
	 * @verbose				Activate extra server start information without enabling the debug mode in the actual server (which you wouldn't want in production)
	 **/
	function run(
		String  name,
		Numeric port,
		String	host,
		Boolean openbrowser,
		String  directory,
		Numeric stopPort,
		Boolean force=false,
		Boolean debug,
		String  webConfigDir,
		String  serverConfigDir,
		String  libDirs,
		String  trayIconFile,
		String  webXML,
		Boolean HTTPEnable,
		Boolean SSLEnable,
		Numeric SSLPort,
		String  SSLCertFile,
		String  SSLKeyFile,
		String  SSLKeyPass,
		Boolean rewritesEnable,
		String  rewritesConfig,
		Numeric heapSize,
		Numeric minHeapSize,
		Boolean directoryBrowsing,
		String  JVMArgs,
		String  runwarArgs,
		Boolean	saveSettings=true,
		String  cfengine,
		String  WARPath,
		String serverConfigFile,
		Numeric startTimeout,
		Boolean console,
		String welcomeFiles,
		String serverHomeDirectory,
		String restMappings,
		Boolean trace,
		String javaHomeDirectory,
		Boolean AJPEnable,
		Numeric AJPPort,
		String javaVersion,
		String startScript,
		String startScriptFile,
		Boolean dryRun,
		Boolean verbose
	){

		// This is a common mis spelling
		if( structKeyExists( arguments, 'rewritesEnabled' ) ) {
			print.yellowLine( 'Auto-correcting "rewritesEnabled" to "rewritesEnable".' );
			// Let's fix that up for them.
			arguments.rewritesEnable = arguments.rewritesEnabled;
			structDelete( arguments, 'rewritesEnabled' );
		}

		// changed trayIcon to trayIconFile, but let's keep them both working for backwards compat
		if( structKeyExists( arguments, 'trayIconFile' ) ) {
			arguments.trayIcon = arguments.trayIconFile;
			structDelete( arguments, 'trayIconFile' );
		}

		try {

			// startup the server
			return serverService.start( serverProps = arguments );

		// endpointException exception type is used when the endpoint has an issue that needs displayed,
		// but I don't want to "blow up" the console with a full error.
		} catch( endpointException var e ) {
			error( e.message, e.detail );
		} catch( serverException var e ) {
			error( e.message, e.detail );
		}
	}

	/**
	* Complete server names
	*/	
	function serverNameComplete() {
		return serverService
			.getServerNames()
			.map( ( i ) => {
				return { name : i, group : 'Server Names' };
			} );
	}

	/**
	* Complete cfengine names
	*/
	function cfengineNameComplete( string paramSoFar ) {
		
		var endpointName = configService.getSetting( 'endpoints.defaultForgeBoxEndpoint', 'forgebox' );
		
		try {		
			var oEndpoint = endpointService.getEndpoint( endpointName );
		} catch( EndpointNotFound var e ) {
			error( e.message, e.detail ?: '' );
		}
		
		var forgebox = oEndpoint.getForgebox();
		var APIToken = oEndpoint.getAPIToken();

		try {
			// Get auto-complete options
			return forgebox.slugSearch( arguments.paramSoFar, 'cf-engines', APIToken );
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

	/**
	* Complete java versions
	*/	
	function javaVersionComplete() {
		return javaService
			.listJavaInstalls()
			.keyArray()
			.map( ( i ) => {
				return { name : i, group : 'Java Versions' };
			} );
	}	
	
}
