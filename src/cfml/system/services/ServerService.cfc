/**
*********************************************************************************
* Copyright Since 2005 ColdBox Platform by Ortus Solutions, Corp
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
	* Where custom servers are stored
	*/
	property name="serverDirectory";
	/**
	* Where core railo server files are stored
	*/
	property name="railoServerDirectory";
	/**
	* Where the Java Command Executable is
	*/
	property name="javaCommand";
	/**
	* Where the Run War jar path is
	*/
	property name="jarPath";

	/**
	* Constructor
	* @shell.inject shell
	* @formatter.inject Formatter
	* @fileSystem.inject FileSystem
	*/
	function init( required shell, required formatter, required fileSystem ){
		// DI
		variables.shell 			= arguments.shell;
		variables.formatterUtil 	= arguments.formatter;
		variables.fileSystemUtil 	= arguments.fileSystem;

		// java helpers
		java = {
			ServerSocket 	: createObject( "java", "java.net.ServerSocket" )
			, File 			: createObject( "java", "java.io.File" )
			, Socket 		: createObject( "java", "java.net.Socket" )
			, InetAddress 	: createObject( "java", "java.net.InetAddress" )
			, LaunchUtil 	: createObject( "java", "runwar.LaunchUtil" )
		};

		// the lib dir location, populated from shell later.
		variables.libDir = arguments.shell.getHomeDir() & "/lib";
		// Where custom server configs are stored
		variables.serverConfig = arguments.shell.getHomeDir() & "/servers.json";
		// Where custom servers are stored
		variables.serverDirectory = arguments.shell.getHomeDir() & "/server/custom/";
		// Where core railo server files are stored
		variables.railoServerDirectory = arguments.shell.getHomeDir() & "/server/";
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
		if( !directoryExists( variables.serverDirectory ) ){
			directoryCreate( variables.serverDirectory );
		}

		return this;
	}

	/**
	 * Start a server instance
	 *
	 * @serverInfo.hint The server information struct: [ webroot, name, port, stopSocket, logDir, status, statusInfo ]
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
		// default server name, and ports
		var name 		= arguments.serverInfo.name is "" ? listLast( webroot, "\/" ) : arguments.serverInfo.name;
		var portNumber  = arguments.serverInfo.port == 0 ? getRandomPort() : arguments.serverInfo.port;
		var stopPort 	= arguments.serverInfo.stopsocket == 0 ? getRandomPort() : arguments.serverInfo.stopsocket;
		var trayIcon    = arguments.serverInfo.trayIcon ?: "#variables.libdir#/trayicon.png";
		var libDirs     = variables.libDir;

		if ( Len( Trim( arguments.serverInfo.libDirs ?: "" ) ) ) {
			libDirs = ListAppend( libDirs, arguments.serverInfo.libDirs );
		}

		// config directory location
		var configDir       = arguments.serverInfo.webConfigDir    ?: variables.serverDirectory & name;
		var serverConfigDir = arguments.serverInfo.serverConfigDir ?: variables.railoServerDirectory;

		// log directory location
		var logdir 		= configdir & "/log";
		if( !directoryExists( logDir ) ){ directoryCreate( logDir ); }
		// The process native name
		var processName = name is "" ? "CommandBox" : name;
		// The java arguments to execute: -Drailo.server.config.dir=""#configdir#/server""  Shared server, custom web configs
		var args = "-Drailo.web.config.dir=""#configdir#"" -Drailo.server.config.dir=""#serverConfigDir#"" "
				& "-javaagent:""#libdir#/railo-inst.jar"" -jar ""#variables.jarPath#"""
				& " -war ""#webroot#"" --background=true --port #portNumber# --debug #debug#"
				& " --stop-port #stopPort# --processname ""#processName#"" --log-dir ""#logdir#"""
				& " --open-browser #openbrowser# --open-url http://127.0.0.1:#portNumber#"
				& " --libdir ""#libDirs#"" --iconpath ""#trayIcon#""";

		if ( Len( Trim( arguments.serverInfo.webXml ?: "" ) ) ) {
			args &= " --webxmlpath #arguments.serverInfo.webXml#";
		}

		// add back port and log information and persist
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
					execute name=variables.javaCommand arguments=attributes.args timeout="50" variable="executeResult";
					// save server info and persiste
					arguments.serverInfo.statusInfo = { command:variables.javaCommand, arguments:attributes.args, result:executeResult };
					arguments.serverInfo.status="running";
					setServerInfo( serverInfo );
				} catch (any e) {
					logger.error( "Error starting server: #e.message# #e.detail#", arguments );
					arguments.serverInfo.statusInfo.result &= executeResult;
					arguments.serverInfo.status="unknown";
					setServerInfo( arguments.serverInfo );
				}
			}
			return "The server for #webroot# is starting on port #portNumber#... type 'server status' to see result";
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
	struct function stop( required Struct serverInfo ){
		var launchUtil = java.LaunchUtil;
		var stopsocket = arguments.serverInfo.stopsocket;
		var args = "-jar ""#variables.jarPath#"" -stop --stop-port #val( stopsocket )# --background false";
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
	function forget( required Struct serverInfo, Boolean all=false ){
		if( !all ){
			var servers 	= getServers();
			var serverdir 	= variables.serverDirectory & serverInfo.name;
			
			// try to delete from config first
			structDelete( servers, hash( arguments.serverInfo.webroot ) );
			setServers( servers );
			// try to delete server
			if( directoryExists( serverDir ) ){
				directoryDelete( serverdir, true );
			}
			// return message
			return "Poof! Wiped out server" & serverInfo.name;
		} else {
			var serverNames = getServerNames();
			setServers( {} );
			directoryDelete( variables.serverDirectory, true );
			directoryCreate( variables.serverDirectory );
			return "Poof! All servers (#arrayToList( serverNames )#) have been wiped.";
		}
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
	function setServerInfo( required Struct serverInfo ){
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
	function setServers( required Struct servers ){
		// TODO: prevent race conditions  :)
		lock name="serverservice.serverconfig" type="exclusive" throwOnTimeout="true" timeout="10"{
			fileWrite( serverConfig, formatterUtil.formatJson( serializeJSON( servers ) ) );
		}
	}

	/**
	 * get servers struct from config file
 	 **/
	function getServers() {
		if( fileExists( variables.serverConfig ) ){
			lock name="serverservice.serverconfig" type="readOnly" throwOnTimeout="true" timeout="10"{
				return deserializeJSON( fileRead( variables.serverConfig ) );
			}
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
		return getServerInfoByWebroot( fileSystemUtil.resolveDirectory( webroot ) );
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

		return structKeyExists( servers, webrootHash ) ? servers[ webrootHash ] : {}
	}

	/**
	 * Get server info for webroot, if not created, it will init a new server info entry
	 * @webroot.hint root directory for served content
 	 **/
	function getServerInfo( required webroot ){
		var servers 	= getServers();
		var webrootHash = hash( arguments.webroot );
		var statusInfo 	= {};

		if( !directoryExists( arguments.webroot ) ){
			statusInfo = { result:"Webroot does not exist, cannot start :" & arguments.webroot };
		}
		if( isNull( servers[ webrootHash ] ) ){
			servers[ webrootHash ] = {
				webroot		: arguments.webroot,
				port		: "",
				stopsocket	: 0,
				debug		: false,
				status		: "stopped",
				statusInfo	: { result : "" },
				name		: listLast( arguments.webroot, "\/" ),
				logDir 		: ""
			}
			setServers( servers );
		}
		return servers[ webrootHash ];
	}

}