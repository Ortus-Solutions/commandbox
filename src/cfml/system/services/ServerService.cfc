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
	
	property name='rewritesDefaultConfig'	inject='rewritesDefaultConfig@constants';	
	property name='interceptorService'		inject='interceptorService';	
	property name='configService'			inject='ConfigService';
	property name='JSONService'				inject='JSONService';
	property name='packageService'			inject='packageService';
	property name='serverEngineService'		inject='serverEngineService';
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
	}

	function getDefaultServerJSON() {
		// pull default settings from config to mix in below.
		// The structure of server.defaults in Config settings matches the default server.json layout here.
		var d = ConfigService.getSetting( 'server.defaults', {} );
		
		return {
			name : d.name ?: '',
			openBrowser : d.openBrowser ?: true,
			stopsocket : d.stopsocket ?: 0,
			debug : d.debug ?: false,
			trayicon : d.trayicon ?: '',
			jvm : {
				heapSize : d.jvm.heapSize ?: 512,
				args : d.jvm.args ?: ''
			},
			web : {
				host : d.web.host ?: '127.0.0.1',				
				directoryBrowsing : d.web.directoryBrowsing ?: true,
				webroot : d.web.webroot ?: '',
				http : {
					port : d.web.http.port ?: 0,
					enable : d.web.http.enable ?: true
				},
				ssl : {
					enable : d.web.ssl.enable ?: false,
					port : d.web.ssl.port ?: 1443,
					cert : d.web.ssl.cert ?: '',
					key : d.web.ssl.key ?: '',
					keyPass : d.web.ssl.keyPass ?: ''
				},
				rewrites : {
					enable : d.web.rewrites.enable ?: false,
					config : d.web.rewrites.config ?: variables.rewritesDefaultConfig
				}
			},
			app : {
				logDir : d.app.logDir ?: '',
				libDirs : d.app.libDirs ?: '',
				webConfigDir : d.app.webConfigDir ?: '',
				serverConfigDir : d.app.serverConfigDir ?: variables.serverHomeDirectory,
				webXML : d.app.webXML ?: '',
				standalone : d.app.standalone ?: false,
				WARPath : d.app.WARPath ?: "",
				cfengine : d.app.cfengine ?: ""
			},
			runwar : {
				args : d.runwar.args ?: ''
			}
		};
	}

	/**
	 * Start a server instance
	 *
	 * @serverProps.hint A struct of settings to influence how to start the server
	 **/
	function start(
		Struct serverProps
	){

		if( isNull( serverProps.name ) ) {
			serverProps.name = listLast( serverProps.directory, "\/" );
		}

		// Discover by shortname or server and get server info
		var serverInfo = getServerInfoByDiscovery(
			directory 	= serverProps.directory,
			name		= serverProps.name
		);

		// Was it found, or new server?
		if( structIsEmpty( serverInfo ) ){
			// We need a new entry
			serverInfo = getServerInfo( serverProps.directory, serverProps.name );
		}

		// Get package descriptor
		var boxJSON = packageService.readPackageDescriptor( serverInfo.webroot );
		// Get server descriptor
		var serverJSON = readServerJSON( serverInfo.webroot , serverProps.name);
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
				// Only need switch cases for properties that are nested or use different name
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
				    case "cfengine":
						serverJSON[ 'app' ][ 'cfengine' ] = serverProps[ prop ];
				         break;
				    case "WARPath":
						serverJSON[ 'app' ][ 'WARPath' ] = serverProps[ prop ];
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
		serverInfo.name 			= serverProps.name;
		serverInfo.debug 			= serverProps.debug 			?: serverJSON.debug 				?: defaults.debug;
		serverInfo.openbrowser		= serverProps.openbrowser 		?: serverJSON.openbrowser			?: defaults.openbrowser;
		serverInfo.host				= serverProps.host 				?: serverJSON.web.host				?: defaults.web.host;
		serverInfo.port 			= serverProps.port 				?: serverJSON.web.http.port			?: getRandomPort( serverInfo.host );
		serverInfo.stopsocket		= serverProps.stopsocket		?: serverJSON.stopsocket 			?: getRandomPort( serverInfo.host );		
		serverInfo.webConfigDir 	= serverProps.webConfigDir 		?: serverJSON.app.webConfigDir		?: getCustomServerFolder( serverInfo );
		serverInfo.serverConfigDir 	= serverProps.serverConfigDir 	?: serverJSON.app.serverConfigDir 	?: defaults.app.serverConfigDir;
		serverInfo.libDirs			= serverProps.libDirs 			?: serverJSON.app.libDirs			?: defaults.app.libDirs;
		serverInfo.trayIcon			= serverProps.trayIcon 			?: serverJSON.trayIcon 				?: defaults.trayIcon;
		serverInfo.webXML 			= serverProps.webXML 			?: serverJSON.app.webXML 			?: defaults.app.webXML;
		serverInfo.SSLEnable 		= serverProps.SSLEnable 		?: serverJSON.web.SSL.enable		?: defaults.web.SSL.enable;
		serverInfo.HTTPEnable		= serverProps.HTTPEnable 		?: serverJSON.web.HTTP.enable		?: defaults.web.HTTP.enable;
		serverInfo.SSLPort			= serverProps.SSLPort 			?: serverJSON.web.SSL.port			?: defaults.web.SSL.port;
		serverInfo.SSLCert 			= serverProps.SSLCert 			?: serverJSON.web.SSL.cert			?: defaults.web.SSL.cert;
		serverInfo.SSLKey 			= serverProps.SSLKey 			?: serverJSON.web.SSL.key			?: defaults.web.SSL.key;
		serverInfo.SSLKeyPass 		= serverProps.SSLKeyPass 		?: serverJSON.web.SSL.keyPass		?: defaults.web.SSL.keyPass;
		serverInfo.rewritesEnable 	= serverProps.rewritesEnable	?: serverJSON.web.rewrites.enable	?: defaults.web.rewrites.enable;
		serverInfo.rewritesConfig 	= serverProps.rewritesConfig 	?: serverJSON.web.rewrites.config 	?: defaults.web.rewrites.config;
		serverInfo.heapSize 		= serverProps.heapSize 			?: serverJSON.JVM.heapSize			?: defaults.JVM.heapSize;
		serverInfo.directoryBrowsing = serverProps.directoryBrowsing ?: serverJSON.web.directoryBrowsing ?: defaults.web.directoryBrowsing;
		serverInfo.JVMargs			= serverProps.JVMargs			?: serverJSON.JVM.args				?: defaults.JVM.args;
		serverInfo.runwarArgs		= serverProps.runwarArgs		?: serverJSON.runwar.args			?: defaults.runwar.args;
		serverInfo.cfengine			= serverProps.cfengine			?: serverJSON.app.cfengine			?: defaults.app.cfengine;
		serverInfo.WARPath			= serverProps.WARPath			?: serverJSON.app.WARPath			?: defaults.app.WARPath;
		
		serverInfo.logdir			= serverInfo.webConfigDir & "/logs";
		
		if( !len( serverInfo.WARPath ) && !len( serverInfo.cfengine ) ) {
			serverInfo.cfengine = 'lucee@' & server.lucee.version;
		}
		
		if( serverInfo.cfengine.endsWith( '@' ) ) {
			serverInfo.cfengine = left( serverInfo.cfengine, len( serverInfo.cfengine ) - 1 );
		}
		
		interceptorService.announceInterception( 'onServerStart', { serverInfo=serverInfo } );
		
		var launchUtil 	= java.LaunchUtil;
				
		// Setup lib directory, add more if defined by server info
		var libDirs     = variables.libDir;
		if ( Len( Trim( serverInfo.libDirs ?: "" ) ) ) {
			libDirs = ListAppend( libDirs, serverInfo.libDirs );
		}
		
		// log directory location
		if( !directoryExists( serverInfo.logDir ) ){ directoryCreate( serverInfo.logDir ); }

    
    // Default java agent for embedded Lucee engine
    var javaagent = serverinfo.cfengine contains 'lucee' ? '-javaagent:"#libdir#/lucee-inst.jar"' : '';
    
    // Not sure what Runwar does with this, but it wants to know what CFEngine we're starting (if we know)
    var CFEngineName = '';
    CFEngineName = serverinfo.cfengine contains 'lucee' ? 'lucee' : CFEngineName;
    CFEngineName = serverinfo.cfengine contains 'railo' ? 'railo' : CFEngineName;
    CFEngineName = serverinfo.cfengine contains 'adobe' ? 'adobe' : CFEngineName;
    
    var thisVersion = '';
    	  
    // As long as there's no WAR Path, let's install the engine to use.
	if( serverInfo.WARPath == '' ){
		try {
			// This will install the engine war to start, possibly downloading it first
			var installDetails = serverEngineService.install( cfengine=serverInfo.cfengine, basedirectory=serverInfo.webConfigDir );
			thisVersion = ' ' & installDetails.version;
			serverInfo.logdir = installDetails.installDir & "/logs";
		    
		// Not sure we need this ultimatley, but errors were really ugly when getting this up and running.
		} catch (any e) {
			logger.error( '#e.message# #e.detail#' , e.stackTrace );
			consoleLogger.error("Error installing server - " & e.message);
			consoleLogger.error(e.detail.replaceAll(",","#chr(10)#"));
			return;
		}
		// If external Lucee server, set the java agent
		if( !installDetails.internal && serverInfo.cfengine contains "lucee" ) {
			javaagent = "-javaagent:""#installDetails.installDir#/WEB-INF/lib/lucee-inst.jar""";
		}
		// If external Railo server, set the java agent
		if( !installDetails.internal && serverInfo.cfengine contains "railo" ) {
			javaagent = "-javaagent:""#installDetails.installDir#/WEB-INF/lib/railo-inst.jar""";
		}
		// Using built in server that hasn't been started before
		if( installDetails.internal && !directoryExists( serverInfo.webConfigDir & '/WEB-INF' ) ) {
			serverInfo.webConfigDir = installDetails.installDir;
			serverInfo.logdir = serverInfo.webConfigDir & "/logs";
		}

		// The process native name
		var processName = ( serverInfo.name is "" ? "CommandBox" : serverInfo.name ) & ' [' & serverinfo.cfengine & thisVersion & ']';
				
		// Find the correct tray icon for this server
		if( !len( serverInfo.trayIcon ) ) {
			var iconSize = fileSystemUtil.isWindows() ? '-32px' : '';
		    if( serverInfo.cfengine contains "lucee" ) { 
		    	serverInfo.trayIcon = '/commandbox/system/config/server-icons/trayicon-lucee#iconSize#.png';
			} else if( serverInfo.cfengine contains "railo" ) {
		    	serverInfo.trayIcon = '/commandbox/system/config/server-icons/trayicon-railo#iconSize#.png';
			} else if( serverInfo.cfengine contains "adobe" ) {
				
				if( listFirst( installDetails.version, '.' ) == 9 ) {
					serverInfo.trayIcon = '/commandbox/system/config/server-icons/trayicon-cf09#iconSize#.png';
				} else if( listFirst( installDetails.version, '.' ) == 10 ) {
					serverInfo.trayIcon = '/commandbox/system/config/server-icons/trayicon-cf10#iconSize#.png';
				} else if( listFirst( installDetails.version, '.' ) == 11 ) {
					serverInfo.trayIcon = '/commandbox/system/config/server-icons/trayicon-cf11#iconSize#.png';
				} else if( listFirst( installDetails.version, '.' ) == 2016 ) {
					serverInfo.trayIcon = '/commandbox/system/config/server-icons/trayicon-cf2016#iconSize#.png';
				} else {
					serverInfo.trayIcon = '/commandbox/system/config/server-icons/trayicon-cf2016#iconSize#.png';
				}
					
			}
		}	
		
	}
		
	// Default tray icon
	serverInfo.trayIcon = ( len( serverInfo.trayIcon ) ? serverInfo.trayIcon : '#variables.libdir#/trayicon.png' ); 
	serverInfo.trayIcon = expandPath( serverInfo.trayIcon );
	
    // Guess the proper set of tray icons based on the cfengine name. 
	var trayConfigJSON = '#libdir#/traymenu-default.json';
    if( serverInfo.cfengine contains "lucee" ) { 
    	trayConfigJSON = '#libdir#/traymenu-lucee.json';
	} else if( serverInfo.cfengine contains "railo" ) {
    	trayConfigJSON = '#libdir#/traymenu-railo.json';
	} else if( serverInfo.cfengine contains "adobe" ) {
    	trayConfigJSON = '#libdir#/traymenu-adobe.json';
	}
	    
    // This is due to a bug in RunWar not creating the right directory for the logs
    directoryCreate( serverInfo.logDir, true, true );
    	

	// The java arguments to execute:  Shared server, custom web configs
	var args = " #serverInfo.JVMargs# -Xmx#serverInfo.heapSize#m -Xms#serverInfo.heapSize#m"
			& " #javaagent# -jar ""#variables.jarPath#"""
			& " --background=true --port #serverInfo.port# --host #serverInfo.host# --debug=#serverInfo.debug#"
			& " --stop-port #serverInfo.stopsocket# --processname ""#processName#"" --log-dir ""#serverInfo.logDir#"""
			& " --open-browser #serverInfo.openbrowser#"
			& " --open-url " & ( serverInfo.SSLEnable ? 'https://#serverInfo.host#:#serverInfo.SSLPort#' : 'http://#serverInfo.host#:#serverInfo.port#' )
			& ( len( CFEngineName ) ? " --cfengine-name ""#CFEngineName#""" : "" )
			& " --server-name ""#serverInfo.name#"""
			& " --tray-icon ""#serverInfo.trayIcon#"" --tray-config ""#trayConfigJSON#"""
			& " --directoryindex ""#serverInfo.directoryBrowsing#"" --cfml-web-config ""#serverInfo.webConfigDir#"""
			& " --cfml-server-config ""#serverInfo.serverConfigDir#"" #serverInfo.runwarArgs# --timeout 120";
			
	// Starting a WAR
	systemOutput( serverinfo.WARPath, true );
	if (serverInfo.WARPath != "" ) {
		args &= " -war ""#serverInfo.WARPath#""";
	// Stand alone server
	} else if( !installDetails.internal ){
		args &= " -war ""#serverInfo.webroot#"" --lib-dirs ""#installDetails.installDir#/WEB-INF/lib"" --web-xml-path ""#installDetails.installDir#/WEB-INF/web.xml""";
	// internal server
	} else {
		args &= " -war ""#serverInfo.webroot#"" --lib-dirs ""#libDirs#""";
	}
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
		
    if(serverInfo.debug) {
      consoleLogger.debug("Server start command: #javaCommand# #args#");
    }
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
				execute name=variables.javaCommand arguments=attributes.args timeout="120" variable="executeResult" errorVariable="executeError";
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
			var defaultServerJSONPath = arguments.serverInfo.webroot & '/server.json';
			var serverJSONPath = arguments.serverInfo.webroot & '/server-#arguments.serverInfo.name#.json';

			// try to delete from config first
			structDelete( servers, hash( arguments.serverInfo.webroot & arguments.serverInfo.name ) );
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
			if( fileExists( defaultServerJSONPath ) ) {
				fileDelete( defaultServerJSONPath );
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
		var webrootHash = hash( arguments.serverInfo.webroot & arguments.serverInfo.name);

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
						results[ thisKey ].id = hash( results[ thisKey ].webroot & results[ thisKey ].name );
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
			var foundServer = getServerInfoByName( arguments.name );
			if( !isNull( foundServer ) ) {
				return foundServer;
			}
		}

		var webroot = arguments.directory is "" ? shell.pwd() : arguments.directory;
		return getServerInfoByWebroot( fileSystemUtil.resolvePath( webroot ), arguments.name );
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
	struct function getServerInfoByWebroot( required webroot, name='' ){
		
		if( arguments.name == '' ) {
			arguments.name = listLast( arguments.webroot, "\/" );
		}
		
		var webrootHash = hash( arguments.webroot & arguments.name );
		var servers 	= getServers();

		return structKeyExists( servers, webrootHash ) ? servers[ webrootHash ] : {};
	}

	/**
	* Get server info for webroot, if not created, it will init a new server info entry
	* @webroot.hint root directory for served content
 	**/
	struct function getServerInfo( required webroot , required name){
		var servers 	= getServers();
		var webrootHash = hash( arguments.webroot & arguments.name);
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
	struct function readServerJSON( required string directory , string name="") {
		var defaultServerJSON = arguments.directory & '/server.json';
		var serverJSON = arguments.directory & '/server-#name#.json';
		if( fileExists( serverJSON ) ) {
			return deserializeJSON( fileRead( serverJSON ) );
		} else if(fileExists( defaultServerJSON )) {
			return deserializeJSON( fileRead( defaultServerJSON ) );
		} else {
			return {};
		}
	}

	/**
	* Save a server.json file.
	*/
	function saveServerJSON( required string directory, required struct data ) {
		var filePath = arguments.directory & '/server.json';
		if(fileExists(filePath)) {
		  var existingProps = readServerJSON(directory);
		  if(!isNull(data.name) && (isNull(existingProps.name) || existingProps.name != data.name)) {
		    filePath = arguments.directory & '/server-#data.name#.json';
		  }
		}
		fileWrite( filePath, formatterUtil.formatJSON( serializeJSON( arguments.data ) ) );
	}

  /**
  * Dynamic completion for cfengine
  */  
	function getCFEngineNames() {
    return serverEngineService.getCFEngineNames();
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
