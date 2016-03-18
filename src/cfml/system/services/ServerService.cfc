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
component accessors="true" singleton {

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
	* Default server settings
	*/
	property name="defaultServerJSON";	
	
	property name='rewritesDefaultConfig'	inject='rewritesDefaultConfig@constants';	
	property name='interceptorService'		inject='interceptorService';
	property name='JSONService'				inject='JSONService';
	property name='packageService'			inject='packageService';
	property name='consoleLogger'			inject='logbox:logger:console';
	property name='wirebox'					inject='wirebox';

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

	function onDIComplete() {
		
		setDefaultServerJSON( {
			name : '',
			openBrowser : true,
			stopsocket : 0,
			debug : false,
			trayicon : '#variables.libdir#/trayicon.png',
			jvm : {
				heapSize : 512,
				args : ''
			},
			web : {
				host : '127.0.0.1',				
				directoryBrowsing : true,
				webroot : '',
				http : {
					port : 0,
					enable : true
				},
				ssl : {
					enable : false,
					port : 1443,
					cert : '',
					key : '',
					keyPass : ''
				},
				rewrites : {
					enable : false,
					config : variables.rewritesDefaultConfig
				}
			},
			app : {
				logDir : '',
				libDirs : '',
				webConfigDir : '',
				serverConfigDir :variables.serverHomeDirectory,
				webXML : ''
			},
			runwar : {
				args : ''
			}
		} );
	}

	/**
	 * Start a server instance
	 *
	 * @serverProps.hint A struct of settings to influence how to start the server
	 **/
	function start(
		Struct serverProps
	){

		// Discover by shortname or server and get server info
		var serverInfo = getServerInfoByDiscovery(
			directory 	= serverProps.directory,
			name		= serverProps.name ?: ''
		);

		// Was it found, or new server?
		if( structIsEmpty( serverInfo ) ){
			// We need a new entry
			serverInfo = getServerInfo( serverProps.directory );
		}

		// Get package descriptor
		var boxJSON = packageService.readPackageDescriptor( serverInfo.webroot );
		// Get server descriptor
		var serverJSON = readServerJSON( serverInfo.webroot );
		// Get defaults
		var defaults = getDefaultServerJSON();
								
		// Backwards compat with boxJSON default port.  Remove in a future version
		// The property in box.json is deprecated. 
		if( boxJSON.defaultPort > 0 ) {
			
			// Remove defaultPort from box.json and pretend it was 
			// manually typed which will cause server.json to save it.
			serverProps.port = boxJSON.defaultPort;
			
			// Update box.json to remove defaultPort from disk
			boxJSON.delete( 'defaultPort' );
			packageService.writePackageDescriptor( boxJSON, serverInfo.webroot );
		}
		
		// Save hand-entered properties in our server.json for next time
		for( var prop in serverProps ) {
			if( !isNull( serverProps[ prop ] ) && prop != 'directory'  && prop != 'saveSettings' ) {
				switch(prop) {
				    case "port":
						serverJSON[ 'web' ][ 'http' ][ 'port' ] = serverProps[ prop ];
				         break;
				    case "host":
						serverJSON[ 'web' ][ 'host' ] = serverProps[ prop ];
				         break;
				    case "stopPort":
						serverJSON[ 'stopsocket' ] = serverProps[ prop ];
				         break;
				    case "webConfigDir":
						serverJSON[ 'app' ][ 'webConfigDir' ] = serverProps[ prop ];
				         break;
				    case "serverConfigDir":
						serverJSON[ 'app' ][ 'serverConfigDir' ] = serverProps[ prop ];
				         break;
				    case "libDirs":
						serverJSON[ 'app' ][ 'libDirs' ] = serverProps[ prop ];
				         break;
				    case "webXML":
						serverJSON[ 'app' ][ 'webXML' ] = serverProps[ prop ];
				         break;
				    case "HTTPEnable":
						serverJSON[ 'web' ][ 'HTTP' ][ 'enable' ] = serverProps[ prop ];
				         break;
				    case "SSLEnable":
						serverJSON[ 'web' ][ 'SSL' ][ 'enable' ] = serverProps[ prop ];
				         break;
				    case "SSLPort":
						serverJSON[ 'web' ][ 'SSL' ][ 'port' ] = serverProps[ prop ];
				         break;
				    case "SSLCert":
						serverJSON[ 'web' ][ 'SSL' ][ 'cert' ] = serverProps[ prop ];
				         break;
				    case "SSLKey":
						serverJSON[ 'web' ][ 'SSL' ][ 'key' ] = serverProps[ prop ];
				         break;
				    case "SSLKeyPass":
						serverJSON[ 'web' ][ 'SSL' ][ 'keyPass' ] = serverProps[ prop ];
				         break;
				    case "rewritesEnable":
						serverJSON[ 'web' ][ 'rewrites' ][ 'enable' ] = serverProps[ prop ];
				         break;
				    case "rewritesConfig":
						serverJSON[ 'web' ][ 'rewrites' ][ 'config' ] = serverProps[ prop ];
				         break;
				    case "heapSize":
						serverJSON[ 'JVM' ][ 'heapSize' ] = serverProps[ prop ];
				         break;
				    case "JVMArgs":
						serverJSON[ 'JVM' ][ 'args' ] = serverProps[ prop ];
				         break;
				    case "runwarArgs":
						serverJSON[ 'runwar' ][ 'args' ] = serverProps[ prop ];
				         break;
				    default: 
					serverJSON[ prop ] = serverProps[ prop ];
				} // end switch
			} // end if
		} // for loop
		
		if( !serverJSON.isEmpty() && serverProps.saveSettings ) {
			saveServerJSON( serverInfo.webroot, serverJSON );
		}
				 

		// Setup serverinfo according to params
		// Hand-entered values take precendence, then settings saved in server.json, and finally defaults.
		// The big servers.json is only used to keep a record of the last values the server was started with
		serverInfo.debug 			= serverProps.debug 			?: serverJSON.debug 				?: defaults.debug;
		serverInfo.openbrowser		= serverProps.openbrowser 		?: serverJSON.openbrowser			?: defaults.openbrowser;
		serverInfo.libDirs			= serverProps.libDirs 			?: serverJSON.app.libDirs			?: defaults.app.libDirs;
		serverInfo.trayIcon			= serverProps.trayIcon 			?: serverJSON.trayIcon 				?: defaults.trayIcon;
		serverInfo.webXML 			= serverProps.webXML 			?: serverJSON.app.webXML 			?: defaults.app.webXML;
		serverInfo.SSLEnable 		= serverProps.SSLEnable 		?: serverJSON.web.SSL.enable		?: defaults.web.SSL.enable;
		serverInfo.HTTPEnable		= serverProps.HTTPEnable 		?: serverJSON.web.HTTP.enable		?: defaults.web.HTTP.enable;
		serverInfo.SSLPort			= serverProps.SSLPort 			?: serverJSON.web.SSL.port			?: defaults.web.SSL.port;
		serverInfo.SSLCert 			= serverProps.SSLCert 			?: serverJSON.web.SSL.cert			?: defaults.web.SSL.cert;
		serverInfo.SSLKey 			= serverProps.SSLKey 			?: serverJSON.web.SSL.key			?: defaults.web.SSL.key;
		serverInfo.SSLKeyPass 		= serverProps.SSLKeyPass 		?: serverJSON.web.SSL.keyPass		?: defaults.web.SSL.keyPass;
		serverInfo.heapSize 		= serverProps.heapSize 			?: serverJSON.JVM.heapSize			?: defaults.JVM.heapSize;
		serverInfo.directoryBrowsing = serverProps.directoryBrowsing ?: serverJSON.web.directoryBrowsing ?: defaults.web.directoryBrowsing;
		serverInfo.JVMargs			= serverProps.JVMargs			?: serverJSON.JVM.args				?: defaults.JVM.args;
		serverInfo.runwarArgs		= serverProps.runwarArgs		?: serverJSON.runwar.args			?: defaults.runwar.args;
		
		// following setting are important, as these cannot be init with empty values
		// host	
		if(!isNull(serverJSON.web.host) && len(serverJSON.web.host) > 0)
			serverInfo.host				= serverProps.host ?: serverJSON.web.host;
		else
			serverInfo.host				= serverProps.host ?: defaults.web.host;	

		// port
		if(!isNull(serverJSON.web.http.port) && serverJSON.web.http.port > 0)
			serverInfo.port 			= serverProps.port ?: serverJSON.web.http.port;
		else	
			serverInfo.port 			= serverProps.port ?: getRandomPort( serverInfo.host );

		// stopsocket
		if(!isNull(serverJSON.stopsocket) && serverJSON.stopsocket > 0)
			serverInfo.stopsocket		= serverJSON.stopsocket;		
		else	
			serverInfo.stopsocket		= getRandomPort( serverInfo.host );

		// webConfigDir
		if(!isNull(serverJSON.app.webConfigDir) && len(serverJSON.app.webConfigDir) > 0)
			serverInfo.webConfigDir 	= serverProps.webConfigDir ?: serverJSON.app.webConfigDir;
		else	
			serverInfo.webConfigDir 	= serverProps.webConfigDir ?: getCustomServerFolder( serverInfo );

		// serverConfigDir
		if(!isNull(serverJSON.app.serverConfigDir) && len(serverJSON.app.serverConfigDir) > 0)
			serverInfo.serverConfigDir 	= serverProps.serverConfigDir ?: serverJSON.app.serverConfigDir;
		else
			serverInfo.serverConfigDir 	= serverProps.serverConfigDir ?: defaults.app.serverConfigDir;

		//	rewritesEnable
		if(!isNull(serverJSON.web.rewrites.enable) && len(serverJSON.web.rewrites.enable) > 0)
			serverInfo.rewritesEnable 	= serverProps.rewritesEnable ?: serverJSON.web.rewrites.enable;
		else
			serverInfo.rewritesEnable 	= serverProps.rewritesEnable ?: defaults.web.rewrites.enable;	
		
		// rewritesConfig
		if(!isNull(serverJSON.web.rewrites.config) && len(serverJSON.web.rewrites.config) > 0)
			serverInfo.rewritesConfig 	= serverProps.rewritesConfig ?: serverJSON.web.rewrites.config;
		else
			serverInfo.rewritesConfig 	= serverProps.rewritesConfig ?: defaults.web.rewrites.config;

		serverInfo.logdir			= serverInfo.webConfigDir & "/log";
	
		interceptorService.announceInterception( 'onServerStart', { serverInfo=serverInfo } );
		
		var launchUtil 	= java.LaunchUtil;
				
		// Setup lib directory, add more if defined by server info
		var libDirs     = variables.libDir;
		if ( Len( Trim( serverInfo.libDirs ?: "" ) ) ) {
			libDirs = ListAppend( libDirs, serverInfo.libDirs );
		}
		
		// log directory location
		if( !directoryExists( serverInfo.logDir ) ){ directoryCreate( serverInfo.logDir ); }

		// The process native name
		var processName = serverInfo.name is "" ? "CommandBox" : serverInfo.name;

		// The java arguments to execute:  Shared server, custom web configs
		var args = " #serverInfo.JVMargs# -Xmx#serverInfo.heapSize#m -Xms#serverInfo.heapSize#m"
				& " -javaagent:""#libdir#/lucee-inst.jar"" -jar ""#variables.jarPath#"""
				& " -war ""#serverInfo.webroot#"" --background=true --port #serverInfo.port# --host #serverInfo.host# --debug #serverInfo.debug#"
				& " --stop-port #serverInfo.stopsocket# --processname ""#processName#"" --log-dir ""#serverInfo.logDir#"""
				& " --open-browser #serverInfo.openbrowser# --open-url http://#serverInfo.host#:#serverInfo.port#"
				& " --cfengine-name lucee --server-name ""#serverInfo.name#"" --lib-dirs ""#libDirs#"""
				& " --tray-icon ""#serverInfo.trayIcon#"" --tray-config ""#libdir#/traymenu.json"""
				& " --directoryindex ""#serverInfo.directoryBrowsing#"" --cfml-web-config ""#serverInfo.webConfigDir#"""
				& "  --cfml-server-config ""#serverInfo.serverConfigDir#"" #serverInfo.runwarArgs# ";
		// Incorporate SSL to command
		if( serverInfo.SSLEnable ){
			args &= " --http-enable #serverInfo.HTTPEnable# --ssl-enable #serverInfo.SSLEnable# --ssl-port #serverInfo.SSLPort#";
		}
		if( serverInfo.SSLEnable && serverInfo.SSLCert != "") {
			args &= " --ssl-cert ""#serverInfo.SSLCert#"" --ssl-key ""#serverInfo.SSLKey#"" --ssl-keypass ""#serverInfo.SSLKeyPass#""";
		}
		// Incorporate web-xml to command
		if ( Len( Trim( serverInfo.webXml ?: "" ) ) ) {
			args &= " --web-xml-path ""#serverInfo.webXml#""";
		}
		// Incorporate rewrites to command
		args &= " --urlrewrite-enable #serverInfo.rewritesEnable#";
		
		if( serverInfo.rewritesEnable ){
			serverInfo.rewritesConfig = fileSystemUtil.resolvePath( serverInfo.rewritesConfig );
			if( !fileExists(serverInfo.rewritesConfig) ){
				return "URL rewrite config not found #serverInfo.rewritesConfig#";
			}
			args &= " --urlrewrite-file ""#serverInfo.rewritesConfig#""";
		}
		
		// Persist server information
		setServerInfo( serverInfo );

		// change status to starting + persist
		serverInfo.status = "starting";
		setServerInfo( serverInfo );
		// thread the execution
		var threadName = 'server#hash( serverInfo.webroot )##createUUID()#';
		thread name="#threadName#" serverInfo=serverInfo args=args {
			try{
				// execute the server command
				var  executeResult = '';
				var  executeError = '';
				// save server info and persist
				serverInfo.statusInfo = { command:variables.javaCommand, arguments:attributes.args, result:'' };
				setServerInfo( serverInfo );
				execute name=variables.javaCommand arguments=attributes.args timeout="50" variable="executeResult" errorVariable="executeError";
				serverInfo.status="running";
			} catch (any e) {
				logger.error( "Error starting server: #e.message# #e.detail#", arguments );
				serverInfo.statusInfo.result &= e.message & ' ' & e.detail;
				serverInfo.status="unknown";
			} finally {
				serverInfo.statusInfo.result = serverInfo.statusInfo.result & executeResult & ' ' & executeError;
				setServerInfo( serverInfo );				
			}
		}
		
		// She'll be coming 'round the mountain when she comes...
		consoleLogger.warn( "The server for #serverInfo.webroot# is starting on #serverInfo.host#:#serverInfo.port#... type 'server status' to see result" );
		
		// If this is a one off command, wait for the thread to finish, otherwise the JVM will shutdown before
		// the server is started and the json files get updated.
		if( shell.getShellType() == 'command' ) {
			thread action="join" name="#threadName#";
			
			// Pull latest info that was saved in the thread and output it. Since we made the 
			// user wait for the thread to finish, we might as well tell them what happened.
			wirebox.getinstance( name='CommandDSL', initArguments={ name : 'server status' } )
				.params( name = serverInfo.name )
				.run();			
		}
			
		
	}

	/**
	 * Stop server
	 * @serverInfo.hint The server information struct: [ webroot, name, port, stopSocket, logDir, status, statusInfo ]
	 *
	 * @returns struct of [ error, messages ]
 	 **/
	struct function stop( required struct serverInfo ){
		
		interceptorService.announceInterception( 'onServerStop', { serverInfo=serverInfo } );
		
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
			var serverJSONPath = arguments.serverInfo.webroot & '/server.json';

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
			
			// Delete server.json if it exists
			if( fileExists( serverJSONPath ) ) {
				fileDelete( serverJSONPath );
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
			heapSize		: 512,
			directoryBrowsing : true,
			JVMargs				: "",
			runwarArgs			: ""
		};
	}

	/**
	* Read a server.json file.  If it doesn't exist, returns an empty struct
	* This only returns properties specifically set in the file.
	*/
	struct function readServerJSON( required string directory ) {
		var filePath = arguments.directory & '/server.json';
		if( fileExists( filePath ) ) {
			return deserializeJSON( fileRead( filePath ) );
		} else {
			return {};
		}
	}

	/**
	* Save a server.json file.
	*/
	function saveServerJSON( required string directory, required struct data ) {
		var filePath = arguments.directory & '/server.json';
		fileWrite( filePath, formatterUtil.formatJSON( serializeJSON( arguments.data ) ) );
	}

	
	/**
	* Dynamic completion for property name based on contents of server.json
	* @directory.hint web root
	* @all.hint Pass false to ONLY suggest existing setting names.  True will suggest all possible settings.
	*/ 	
	function completeProperty( required directory,  all=false ) {
		// Get all config settings currently set
		var props = JSONService.addProp( [], '', '', readServerJSON( arguments.directory ) );
		
		// If we want all possible options...
		if( arguments.all ) {
			// ... Then add them in			
			props = JSONService.addProp( props, '', '', getDefaultServerJSON() );
		}
		
		return props;		
	}	
}
