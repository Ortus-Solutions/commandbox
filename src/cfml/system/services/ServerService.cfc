/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I manage servers
*
*/
component accessors="true" singleton{

	/**
	* Where the server libs are located
	*/
	property name="libDir";
	/**
	* Where the server configuration file is
	*/
	property name="serverConfig";
	/**
 	* Where core and custom servers are stored
 	*/
	property name="serverHomeDirectory";
	/**
	* Where custom servers are stored
	*/
	property name="customServerDirectory";
	/**
	* Where the Java Command Executable is
	*/
	property name="javaCommand";
	/**
	* Where the Run War jar path is
	*/
	property name="jarPath";
	/**
	* The default rewrites configuration file
	*/
	property name="rewritesDefaultConfig" inject="rewritesDefaultConfig@constants";

	/**
	* Constructor
	* @shell.inject shell
	* @formatter.inject Formatter
	* @fileSystem.inject FileSystem
	* @homeDir.inject HomeDir@constants
	* @consoleLogger.inject logbox:logger:console
	* @logger.inject logbox:logger:{this}
	*/
	function init(
		required shell,
		required formatter,
		required fileSystem,
		required homeDir,
		required consoleLogger,
		required logger
	){
		// DI
		variables.shell 			= arguments.shell;
		variables.formatterUtil 	= arguments.formatter;
		variables.fileSystemUtil 	= arguments.fileSystem;
		variables.consoleLogger 	= arguments.consoleLogger;
		variables.logger 			= arguments.logger;

		// java helpers
		java = {
			ServerSocket 	: createObject( "java", "java.net.ServerSocket" )
			, File 			: createObject( "java", "java.io.File" )
			, Socket 		: createObject( "java", "java.net.Socket" )
			, InetAddress 	: createObject( "java", "java.net.InetAddress" )
			, LaunchUtil 	: createObject( "java", "runwar.LaunchUtil" )
		};

		// the home directory.
		variables.homeDir = arguments.homeDir;
		// the lib dir location, populated from shell later.
		variables.libDir = arguments.homeDir & "/lib";
		// Where core server is installed
		variables.serverHomeDirectory = arguments.homeDir & "/engine/cfml/server/";
		// Where custom server configs are stored
		variables.serverConfig = arguments.homeDir & "/servers.json";
		// Where custom servers are stored
		variables.customServerDirectory = arguments.homeDir & "/server/";
		// The JRE executable command
		variables.javaCommand = arguments.fileSystem.getJREExecutable();
		// The runwar jar path
		variables.jarPath = java.File.init( java.launchUtil.class.getProtectionDomain().getCodeSource()
				.getLocation().toURI().getSchemeSpecificPart() ).getAbsolutePath();

		// Init server config if not found
		if( !fileExists( variables.serverConfig ) ){
			setServers( {} );
		}
		// Init custom server location if not exists
		if( !directoryExists( variables.customServerDirectory ) ){
			directoryCreate( variables.customServerDirectory );
		}

		return this;
	}

	/**
	 * Start a server instance
	 *
	 * @serverInfo.hint The server information struct: [ webroot, name, port, host, stopSocket, logDir, status, statusInfo, HTTPEnable, SSLEnable, RewritesEnable, RewritesConfig ]
	 * @openBrowser.hint Open a web browser or not
	 * @force.hint force start if status is not stopped
	 * @debug.hint sets debug log level
	 **/
	function start(
		Struct serverInfo,
		Boolean openBrowser,
		Boolean force=false,
		Boolean debug=false
	){
		var launchUtil 	= java.LaunchUtil;
		
		// get webroot info
		var webroot 	= arguments.serverInfo.webroot;
		var webhash 	= hash( arguments.serverInfo.webroot );
		
		// default server name, ports, options
		var name 		= arguments.serverInfo.name is "" ? listLast( webroot, "\/" ) : arguments.serverInfo.name;
		var portNumber  = arguments.serverInfo.port == 0 ? getRandomPort( arguments.serverInfo.host ) : arguments.serverInfo.port;
		var stopPort 	= arguments.serverInfo.stopsocket == 0 ? getRandomPort( arguments.serverInfo.host ) : arguments.serverInfo.stopsocket;
		var HTTPEnable 	= isNull( arguments.serverInfo.HTTPEnable ) ? true 	: arguments.serverInfo.HTTPEnable;
		var SSLEnable 	= isNull( arguments.serverInfo.SSLEnable ) 	? false : arguments.serverInfo.SSLEnable;
		var SSLPort 	= isNull( arguments.serverInfo.sslPort ) 	? 1443 	: arguments.serverInfo.sslPort;
		var SSLCert 	= isNull( arguments.serverInfo.sslCert ) 	? "" 	: arguments.serverInfo.sslCert;
		var SSLKey 		= isNull( arguments.serverInfo.sslKey ) 	? "" 	: arguments.serverInfo.sslKey;
		var SSLKeyPass 	= isNull( arguments.serverInfo.sslKeyPass ) ? "" 	: arguments.serverInfo.sslKeyPass;
		
		// setup default tray icon if empty
		var trayIcon    = len( arguments.serverInfo.trayIcon ) ? arguments.serverInfo.trayIcon : "#variables.libdir#/trayicon.png";
		
		// Setup lib directory, add more if defined by server info
		var libDirs     = variables.libDir;
		if ( Len( Trim( arguments.serverInfo.libDirs ?: "" ) ) ) {
			libDirs = ListAppend( libDirs, arguments.serverInfo.libDirs );
		}
		
		// URL rewriting
		var rewritesEnable  = isNull( arguments.serverInfo.rewritesEnable ) ? false : arguments.serverInfo.rewritesEnable;
		var rewritesConfig 	= isNull( arguments.serverInfo.rewritesConfig ) ? "" 	: arguments.serverInfo.rewritesConfig;

		// config directory locations
		var configDir       = len( arguments.serverInfo.webConfigDir ) 		? arguments.serverInfo.webConfigDir 	: getCustomServerFolder( arguments.serverInfo );
		var serverConfigDir = len( arguments.serverInfo.serverConfigDir ) 	? arguments.serverInfo.serverConfigDir 	: variables.serverHomeDirectory;

		// log directory location
		var logdir = configdir & "/log";
		if( !directoryExists( logDir ) ){ directoryCreate( logDir ); }

		// The process native name
		var processName = name is "" ? "CommandBox" : name;

		// The java arguments to execute:  Shared server, custom web configs
		var args = " -Xmx#serverInfo.heapSize#m -Xms#serverInfo.heapSize#m"
				& " -javaagent:""#libdir#/lucee-inst.jar"" -jar ""#variables.jarPath#"""
				& " -war ""#webroot#"" --background=true --port #portNumber# --host #arguments.serverInfo.host# --debug #debug#"
				& " --stop-port #stopPort# --processname ""#processName#"" --log-dir ""#logdir#"""
				& " --open-browser #openbrowser# --open-url http://#arguments.serverInfo.host#:#portNumber#"
				& " --cfengine-name lucee --server-name ""#name#"" --lib-dirs ""#libDirs#"""
				& " --tray-icon ""#trayIcon#"" --tray-config ""#libdir#/traymenu.json"""
				& " --cfml-web-config ""#configdir#"" --cfml-server-config ""#serverConfigDir#""";
		// Incorporate SSL to command
		if( SSLEnable ){
			args &= " --http-enable #HTTPEnable# --ssl-enable #SSLEnable# --ssl-port #SSLPort#";
		}
		if( SSLEnable && SSLCert != "") {
			args &= " --ssl-cert ""#SSLCert#"" --ssl-key ""#SSLKey#"" --ssl-keypass ""#SSLKeyPass#""";
		}
		// Incorporate web-xml to command
		if ( Len( Trim( arguments.serverInfo.webXml ?: "" ) ) ) {
			args &= " --web-xml-path ""#arguments.serverInfo.webXml#""";
		}
		// Incorporate rewrites to command
		args &= " --urlrewrite-enable #rewritesEnable#";
		if( !len( rewritesConfig ) ){
			rewritesConfig = variables.rewritesDefaultConfig;
		}
		if( rewritesEnable ){
			rewritesConfig = fileSystemUtil.resolvePath( rewritesConfig );
			if( !fileExists(rewritesConfig) ){
				return "URL rewrite config not found #rewritesConfig#";
			}
			args &= " --urlrewrite-file ""#rewritesConfig#""";
		}

		// add back port and log information and persist server information
		arguments.serverInfo.port 		= portNumber;
		arguments.serverInfo.stopsocket = stopPort;
		arguments.serverInfo.logdir 	= logdir;
		setServerInfo( arguments.serverInfo );

		// If server is stoped or forced, start it
		if( arguments.serverInfo.status == "stopped" || force) {
			// change status to starting + persist
			arguments.serverInfo.status = "starting";
			setServerInfo( serverInfo );
			// thread the execution
			thread name="server#webhash##createUUID()#" serverInfo=arguments.serverInfo args=args {
				try{
					// execute the server command
					var  executeResult = '';
					var  executeError = '';
					execute name=variables.javaCommand arguments=attributes.args timeout="50" variable="executeResult" errorVariable="executeError"; 
					// save server info and persist
					arguments.serverInfo.statusInfo = { command:variables.javaCommand, arguments:attributes.args, result:executeResult & ' ' & executeError };
					arguments.serverInfo.status="running";
					setServerInfo( serverInfo );
				} catch (any e) {
					logger.error( "Error starting server: #e.message# #e.detail#", arguments );
					arguments.serverInfo.statusInfo.result &= executeResult & ' ' & executeError;
					arguments.serverInfo.status="unknown";
					setServerInfo( arguments.serverInfo );
				}
			}
			return "The server for #webroot# is starting on #arguments.serverInfo.host#:#portNumber#... type 'server status' to see result";
		} else {
			return "Cannot start!  The server is currently in the #arguments.serverInfo.status# state!#chr(10)#Use force=true or the 'server forget' command ";
		}
	}

	/**
	 * Stop server
	 * @serverInfo.hint The server information struct: [ webroot, name, port, stopSocket, logDir, status, statusInfo ]
	 *
	 * @returns struct of [ error, messages ]
 	 **/
	struct function stop( required struct serverInfo ){
		var launchUtil = java.LaunchUtil;
		var stopsocket = arguments.serverInfo.stopsocket;
		var args = "-jar ""#variables.jarPath#"" -stop --stop-port #val( stopsocket )# -host #arguments.serverInfo.host# --background false";
		var results = { error = false, messages = "" };

		try{
			// Try to stop and set status back
			execute name=variables.javaCommand arguments=args timeout="50" variable="results.messages";
			serverInfo.status 		= "stopped";
			serverInfo.statusInfo 	= { command:variables.javaCommand, arguments:args, result:results.messages };
			setServerInfo( serverInfo );
			return results;
		} catch (any e) {
			serverInfo.status 		= "unknown";
			serverInfo.statusInfo 	= { command:variables.javaCommand, arguments:args, result:results.messages };
			setServerInfo( serverInfo );
			return { error=true, messages=e.message & e.detail };
		}
	}

	/**
	 * Forget server from the configurations
	 * @serverInfo.hint struct of server info (ports, etc.)
	 * @all.hint remove ALL servers
 	 **/
	function forget( required struct serverInfo, boolean all=false ){
		if( !arguments.all ){
			var servers 	= getServers();
			var serverdir 	= getCustomServerFolder( arguments.serverInfo );

			// try to delete from config first
			structDelete( servers, hash( arguments.serverInfo.webroot ) );
			setServers( servers );
			// try to delete server
			if( directoryExists( serverDir ) ){
				// Catch this to gracefully handle where the OS or another program
				// has the folder locked.
				try {
					directoryDelete( serverdir, true );
				} catch( any e ) {
					consoleLogger.error( '#e.message##chr(10)#Did you leave the server running? ' );
					logger.error( '#e.message# #e.detail#' , e.stackTrace );
				}
			}
			// return message
			return "Poof! Wiped out server " & serverInfo.name;
		} else {
			var serverNames = getServerNames();
			setServers( {} );
				// Catch this to gracefully handle where the OS or another program
				// has the folder locked.
				try {
					directoryDelete( variables.customServerDirectory, true );
					directoryCreate( variables.customServerDirectory );
				} catch( any e ) {
					consoleLogger.error( '#e.message##chr(10)#Did you leave a server running? ' );
					logger.error( '#e.message# #e.detail#' , e.stackTrace );
				}
			return "Poof! All servers (#arrayToList( serverNames )#) have been wiped.";
		}
	}

	/**
	* Get a custom server folder name according to our naming convention to avoid collisions with name
	* @serverInfo The server information
	*/
	function getCustomServerFolder( required struct serverInfo ){
		return variables.customServerDirectory & arguments.serverinfo.id & "-" & arguments.serverInfo.name;
	}

	/**
	 * Get a random port for the specified host
	 * @host.hint host to get port on, defaults 127.0.0.1
 	 **/
	function getRandomPort( host="127.0.0.1" ){
		var nextAvail  = java.ServerSocket.init( javaCast( "int", 0 ),
												 javaCast( "int", 1 ),
												 java.InetAddress.getByName( arguments.host ) );
		var portNumber = nextAvail.getLocalPort();
		nextAvail.close();
		return portNumber;
	}

	/**
	 * persist server info
	 * @serverInfo.hint struct of server info (ports, etc.)
 	 **/
	function setServerInfo( required struct serverInfo ){
		var servers 	= getServers();
		var webrootHash = hash( arguments.serverInfo.webroot );

		if( arguments.serverInfo.webroot == "" ){
			throw( "The webroot cannot be empty!" );
		}
		servers[ webrootHash ] = serverInfo;
		// persist back safely
		setServers( servers );
	}

	/**
	 * persist servers
	 * @servers.hint struct of serverInfos
 	 **/
	ServerService function setServers( required Struct servers ){
		lock name="serverservice.serverconfig" type="exclusive" throwOnTimeout="true" timeout="10"{
			fileWrite( serverConfig, formatterUtil.formatJson( serializeJSON( servers ) ) );
		}
		return this;
	}

	/**
	* get servers struct from config file on disk
 	**/
	struct function getServers() {
		if( fileExists( variables.serverConfig ) ){
			lock name="serverservice.serverconfig" type="readOnly" throwOnTimeout="true" timeout="10"{
				var results = deserializeJSON( fileRead( variables.serverConfig ) );
				var updateRequired = false;
				
				// Loop over each server for some housekeeping
				for( var thisKey in results ){
					// Backwards compat-- add in server id if it doesn't exist for older versions of CommandBox
					if( isNull( results[ thisKey ].id ) ){
						results[ thisKey ].id = hash( results[ thisKey ].webroot );
						updateRequired = true;
					}
					// Future-proof server info by guaranteeing that all properties will exist in the 
					// server object as long as they are defined in the newServerInfoStruct() method.
					results[ thisKey ].append( newServerInfoStruct(), false );
				}
			}
			// If any server didn't have an ID, go ahead and save it now
			if( updateRequired ){ setServers( results ); }
			return results;
		} else {
			return {};
		}
	}

	/**
	* Get a server information struct by name or directory
	* @directory.hint the directory to find
	* @name.hint The name to find
	*/
	struct function getServerInfoByDiscovery( required directory="", required name="" ){
		// Discover by shortname or webroot
		if( len( arguments.name ) ){
			return getServerInfoByName( arguments.name );
		}

		var webroot = arguments.directory is "" ? shell.pwd() : arguments.directory;
		return getServerInfoByWebroot( fileSystemUtil.resolvePath( webroot ) );
	}

	/**
	* Get a server information struct by name, if not found it returns an empty struct
	* @name.hint The name to find
	*/
	struct function getServerInfoByName( required name ){
		var servers = getServers();
		for( var thisServer in servers ){
			if( servers[ thisServer ].name == arguments.name ){
				return servers[ thisServer ];
			}
		}

		return {};
	}

	/**
	* Get all servers registered as an array of names
	*/
	array function getServerNames(){
		var servers = getServers();
		var results = [];

		for( var thisServer in servers ){
			arrayAppend( results, servers[ thisServer ].name );
		}

		return results;
	}

	/**
	* Get a server information struct by webrot, if not found it returns an empty struct
	* @webroot.hint The webroot to find
	*/
	struct function getServerInfoByWebroot( required webroot ){
		var webrootHash = hash( arguments.webroot );
		var servers 	= getServers();

		return structKeyExists( servers, webrootHash ) ? servers[ webrootHash ] : {};
	}

	/**
	* Get server info for webroot, if not created, it will init a new server info entry
	* @webroot.hint root directory for served content
 	**/
	struct function getServerInfo( required webroot ){
		var servers 	= getServers();
		var webrootHash = hash( arguments.webroot );
		var statusInfo 	= {};

		if( !directoryExists( arguments.webroot ) ){
			statusInfo = { result:"Webroot does not exist, cannot start :" & arguments.webroot };
		}

		if( isNull( servers[ webrootHash ] ) ){
			// prepare new server info
			var serverInfo 		= newServerInfoStruct();
			serverInfo.id 		= webrootHash;
			serverInfo.webroot 	= arguments.webroot;
			serverInfo.name 	= listLast( arguments.webroot, "\/" );
			// Store it in server struct
			servers[ webrootHash ] = serverInfo;
			// persist it
			setServers( servers );
		}

		// Return the new record
		return servers[ webrootHash ];
	}

	/**
	* Returns a new server info structure
	*/
	struct function newServerInfoStruct(){
		return {
			id 				: "",
			port			: 0,
			host			: "127.0.0.1",
			stopsocket		: 0,
			debug			: false,
			status			: "stopped",
			statusInfo		: {
				result : "",
				arguments : "",
				command : "" 
			},
			name			: "",
			logDir 			: "",
			trayicon 		: "",
			libDirs 		: "",
			webConfigDir 	: "",
			serverConfigDir : "",
			webroot			: "",
			webXML 			: "",
			HTTPEnable		: true,
			SSLEnable		: false,
			SSLPort			: 1443,
			SSLCert 		: "",
			SSLKey			: "",
			SSLKeyPass		: "",
			rewritesEnable  : false,
			rewritesConfig	: "",
			heapSize		: 512
		};
	}

}
