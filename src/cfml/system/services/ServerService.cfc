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
	property name='CR'						inject='CR@constants';

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
			// Duplicate so onServerStart interceptors don't actually change config settings via refernce.
			trayOptions : duplicate( d.trayOptions ?: [] ),
			jvm : {
				heapSize : d.jvm.heapSize ?: 512,
				args : d.jvm.args ?: ''
			},
			web : {
				host : d.web.host ?: '127.0.0.1',				
				directoryBrowsing : d.web.directoryBrowsing ?: true,
				webroot : d.web.webroot ?: '',
				// Duplicate so onServerStart interceptors don't actually change config settings via refernce.
				aliases : duplicate( d.web.aliases ?: {} ),
				// Duplicate so onServerStart interceptors don't actually change config settings via refernce.
				errorPages : duplicate( d.web.errorPages ?: {} ),
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
	 * @serverProps.hint A struct of settings to influence how to start the server. Params not provided by the user are null.
	 **/
	function start(
		Struct serverProps
	){
				
		// Resolve path as used locally
		if( !isNull( serverProps.directory ) ) {
			serverProps.directory = fileSystemUtil.resolvePath( serverProps.directory );
		} 
		if( !isNull( serverProps.serverConfigFile ) ) {
			serverProps.serverConfigFile = fileSystemUtil.resolvePath( serverProps.serverConfigFile );
		}
		if( !isNull( serverProps.WARPath ) ) {
			serverProps.WARPath = fileSystemUtil.resolvePath( serverProps.WARPath );
		}
		if( !isNull( serverProps.trayIcon ) ) {
			serverProps.trayIcon = fileSystemUtil.resolvePath( serverProps.trayIcon );
		}
		if( !isNull( serverProps.rewritesConfig ) ) {
			serverProps.rewritesConfig = fileSystemUtil.resolvePath( serverProps.rewritesConfig );
		}

		// Look up the server that we're starting
		var serverDetails = resolveServerDetails( arguments.serverProps );
				
		var defaultName = serverDetails.defaultName;
		var defaultwebroot = serverDetails.defaultwebroot;
		var defaultServerConfigFile = serverDetails.defaultServerConfigFile;
		var defaultServerConfigFileDirectory = getDirectoryFromPath( defaultServerConfigFile );
		var serverJSON = serverDetails.serverJSON;
		var serverInfo = serverDetails.serverinfo;

		// If the server is already running, make sure the user really wants to do this.
		if( isServerRunning( serverInfo ) && !(serverProps.force ?: false ) ) {
			consoleLogger.error( '.' );
			consoleLogger.error( 'Server "#serverInfo.name#" (#serverInfo.webroot#) is already running!' );
			consoleLogger.error( 'Overwriting a running server means you won''t be able to use the "stop" command to stop the original one.' );
			consoleLogger.warn( 'Use the --force parameter to skip this check.' );
			consoleLogger.error( '.' );
			// Collect a new name
			var newName = shell.ask( 'Provide a unique "name" for this server (leave blank to keep starting as-is): ' );
			// If a name is provided, start over.  Otherwise, just keep starting.
			// The recursive call here will subject their answer to the same check until they provide a name that hasn't been used for this folder.
			if( len( newName ) ) {
				serverProps.name = newName;
				//copy the orig server's server.json file to the new file so it starts with the same properties as the original. lots of alternative ways to do this but the file copy works and is simple
				file action='copy' source="#defaultServerConfigFile#" destination=fileSystemUtil.resolvePath( serverProps.directory ?: '' ) & "/server-#serverProps.name#.json" mode ='777';  		
				return start( serverProps );
			}
		}

		// *************************************************************************************
		// Backwards compat for default port in box.json. Remove this eventually...			// *
																							// *
		// Get package descriptor															// *
		var boxJSON = packageService.readPackageDescriptor( defaultwebroot );				// *
		// Get defaults																		// *
		var defaults = getDefaultServerJSON();												// *
																							// *
		// Backwards compat with boxJSON default port.  Remove in a future version			// *
		// The property in box.json is deprecated. 											// *
		if( boxJSON.defaultPort > 0 ) {														// *
																							// *
			// Remove defaultPort from box.json and pretend it was 							// *
			// manually typed which will cause server.json to save it.						// *
			serverProps.port = boxJSON.defaultPort;											// *
																							// *
			// Update box.json to remove defaultPort from disk								// *
			boxJSON.delete( 'defaultPort' );												// *
			packageService.writePackageDescriptor( boxJSON, defaultwebroot );				// *
		}																					// *
																							// *
		// End backwards compat for default port in box.json.								// *
		// *************************************************************************************
		
		// Save hand-entered properties in our server.json for next time
		for( var prop in serverProps ) {
			// Ignore null props or ones that shouldn't be saved
			if( isNull( serverProps[ prop ] ) || listFindNoCase( 'saveSettings,serverConfigFile,debug,force', prop ) ) {
				continue;
			}
			// Only need switch cases for properties that are nested or use different name
			switch(prop) {
			    case "port":
					serverJSON[ 'web' ][ 'http' ][ 'port' ] = serverProps[ prop ];
			         break;
			    case "host":
					serverJSON[ 'web' ][ 'host' ] = serverProps[ prop ];
			         break;
			    case "directory":
			    	// Both of these are canonical already.
			    	var thisDirectory = replace( serverProps[ 'directory' ], '\', '/', 'all' ) & '/';
			    	var configPath = replace( fileSystemUtil.resolvePath( defaultServerConfigFileDirectory ), '\', '/', 'all' ) & '/';
			    	// If the web root is south of the server's JSON, make it relative for better portability.
			    	if( thisDirectory contains configPath ) {
			    		thisDirectory = replaceNoCase( thisDirectory, configPath, '' );
			    	}
					serverJSON[ 'web' ][ 'webroot' ] = thisDirectory;
			         break;
			    case "trayIcon":
			    	// Both of these are canonical already.
			    	var thisFile = replace( serverProps[ 'trayIcon' ], '\', '/', 'all' );
			    	var configPath = replace( fileSystemUtil.resolvePath( defaultServerConfigFileDirectory ), '\', '/', 'all' ) & '/';
			    	// If the trayIcon is south of the server's JSON, make it relative for better portability.
			    	if( thisFile contains configPath ) {
			    		thisFile = replaceNoCase( thisFile, configPath, '' );
			    	}
					serverJSON[ 'trayIcon' ] = thisFile;
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
			    	// Both of these are canonical already.
			    	var thisFile = replace( serverProps[ 'WARPath' ], '\', '/', 'all' );
			    	var configPath = replace( fileSystemUtil.resolvePath( defaultServerConfigFileDirectory ), '\', '/', 'all' ) & '/';
			    	// If the trayIcon is south of the server's JSON, make it relative for better portability.
			    	if( thisFile contains configPath ) {
			    		thisFile = replaceNoCase( thisFile, configPath, '' );
			    	}
					serverJSON[ 'app' ][ 'WARPath' ] = thisFile;
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
			    	// Both of these are canonical already.
			    	var thisFile = replace( serverProps[ 'rewritesConfig' ], '\', '/', 'all' );
			    	var configPath = replace( fileSystemUtil.resolvePath( defaultServerConfigFileDirectory ), '\', '/', 'all' ) & '/';
			    	// If the trayIcon is south of the server's JSON, make it relative for better portability.
			    	if( thisFile contains configPath ) {
			    		thisFile = replaceNoCase( thisFile, configPath, '' );
			    	}
					serverJSON[ 'web' ][ 'rewrites' ][ 'config' ] = thisFile;
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
		} // for loop
		
		if( !serverJSON.isEmpty() && serverProps.saveSettings ) {
			saveServerJSON( defaultServerConfigFile, serverJSON );
		}
		
		// Setup serverinfo according to params
		// Hand-entered values take precendence, then settings saved in server.json, and finally defaults.
		// The big servers.json is only used to keep a record of the last values the server was started with
		serverInfo.debug 			= serverProps.debug 			?: serverJSON.debug 				?: defaults.debug;
		serverInfo.openbrowser		= serverProps.openbrowser 		?: serverJSON.openbrowser			?: defaults.openbrowser;
		serverInfo.host				= serverProps.host 				?: serverJSON.web.host				?: defaults.web.host;
		// If the last port we used is taken, remove it from consideration.
		if( serverInfo.port == 0 || !isPortAvailable( serverInfo.host, serverInfo.port ) ) { serverInfo.delete( 'port' ); }
		// Port is the only setting that automatically carries over without being specified since it's random.
		serverInfo.port 			= serverProps.port 				?: serverJSON.web.http.port			?: serverInfo.port 							?: getRandomPort( serverInfo.host );
		
		// Double check that the port in the user params or server.json isn't in use
		if( !isPortAvailable( serverInfo.host, serverInfo.port ) ) {
			consoleLogger.error( "." );
			consoleLogger.error( "You asked for port [#( serverProps.port ?: serverJSON.web.http.port ?: '?' )#] in your #( serverProps.keyExists( 'port' ) ? 'start params' : 'server.json' )# but it's already in use so I'm ignoring it and choosing a random one for you." );
			consoleLogger.error( "." );
			serverInfo.port = getRandomPort( serverInfo.host );
		}
		
		serverInfo.stopsocket		= serverProps.stopsocket		?: serverJSON.stopsocket 			?: getRandomPort( serverInfo.host );		
		serverInfo.webConfigDir 	= serverProps.webConfigDir 		?: serverJSON.app.webConfigDir 		?: defaults.app.webConfigDir;
		if( !len( serverInfo.webConfigDir ) ) { serverInfo.webConfigDir =  getCustomServerFolder( serverInfo ); }
		serverInfo.serverConfigDir 	= serverProps.serverConfigDir 	?: serverJSON.app.serverConfigDir 	?: defaults.app.serverConfigDir;
		serverInfo.libDirs			= serverProps.libDirs 			?: serverJSON.app.libDirs			?: defaults.app.libDirs;
		if( serverJSON.keyExists( 'trayIcon' ) ) { serverJSON.trayIcon = fileSystemUtil.resolvePath( serverJSON.trayIcon, defaultServerConfigFileDirectory ); }
		if( defaults.keyExists( 'trayIcon' ) && len( defaults.trayIcon ) ) { defaults.trayIcon = fileSystemUtil.resolvePath( defaults.trayIcon, defaultwebroot ); }
		serverInfo.trayIcon			= serverProps.trayIcon 			?: serverJSON.trayIcon 				?: defaults.trayIcon;
		serverInfo.webXML 			= serverProps.webXML 			?: serverJSON.app.webXML 			?: defaults.app.webXML;
		serverInfo.SSLEnable 		= serverProps.SSLEnable 		?: serverJSON.web.SSL.enable		?: defaults.web.SSL.enable;
		serverInfo.HTTPEnable		= serverProps.HTTPEnable 		?: serverJSON.web.HTTP.enable		?: defaults.web.HTTP.enable;
		serverInfo.SSLPort			= serverProps.SSLPort 			?: serverJSON.web.SSL.port			?: defaults.web.SSL.port;
		serverInfo.SSLCert 			= serverProps.SSLCert 			?: serverJSON.web.SSL.cert			?: defaults.web.SSL.cert;
		serverInfo.SSLKey 			= serverProps.SSLKey 			?: serverJSON.web.SSL.key			?: defaults.web.SSL.key;
		serverInfo.SSLKeyPass 		= serverProps.SSLKeyPass 		?: serverJSON.web.SSL.keyPass		?: defaults.web.SSL.keyPass;
		serverInfo.rewritesEnable 	= serverProps.rewritesEnable	?: serverJSON.web.rewrites.enable	?: defaults.web.rewrites.enable;
		if( isDefined( 'serverJSON.web.rewrites.config' ) ) { serverJSON.web.rewrites.config = fileSystemUtil.resolvePath( serverJSON.web.rewrites.config, defaultServerConfigFileDirectory ); }
		if( isDefined( 'defaults.web.rewrites.config' ) ) { defaults.web.rewrites.config = fileSystemUtil.resolvePath( defaults.web.rewrites.config, defaultwebroot ); }
		serverInfo.rewritesConfig 	= serverProps.rewritesConfig 	?: serverJSON.web.rewrites.config 	?: defaults.web.rewrites.config;
		serverInfo.heapSize 		= serverProps.heapSize 			?: serverJSON.JVM.heapSize			?: defaults.JVM.heapSize;
		serverInfo.directoryBrowsing = serverProps.directoryBrowsing ?: serverJSON.web.directoryBrowsing ?: defaults.web.directoryBrowsing;
		
		// Global aliases are always added on top of server.json (but don't overwrite)
		// Aliases aren't accepted via command params due to no clean way to provide them
		serverInfo.aliases 			= defaults.web.aliases;
		serverInfo.aliases.append( serverJSON.web.aliases ?: {} );
				
		// Global errorPages are always added on top of server.json (but don't overwrite the full struct)
		// Aliases aren't accepted via command params
		serverInfo.errorPages		= defaults.web.errorPages;
		serverInfo.errorPages.append( serverJSON.web.errorPages ?: {} );
		
		
		// Global trayOptions are always added on top of server.json (but don't overwrite)
		// trayOptions aren't accepted via command params due to no clean way to provide them
		serverInfo.trayOptions 			= defaults.trayOptions;
		serverInfo.trayOptions.append( serverJSON.trayOptions ?: [], true );
		
		// Global defauls are always added on top of whatever is specified by the user or server.json
		serverInfo.JVMargs			= ( serverProps.JVMargs			?: serverJSON.JVM.args ?: '' ) & ' ' & defaults.JVM.args;
		
		// Global defauls are always added on top of whatever is specified by the user or server.json
		serverInfo.runwarArgs		= ( serverProps.runwarArgs		?: serverJSON.runwar.args ?: '' ) & ' ' & defaults.runwar.args;
				
		// Global defauls are always added on top of whatever is specified by the user or server.json
		serverInfo.libDirs		= ( serverProps.libDirs		?: serverJSON.app.libDirs ?: '' ).listAppend( defaults.app.libDirs );
				
		serverInfo.cfengine			= serverProps.cfengine			?: serverJSON.app.cfengine			?: defaults.app.cfengine;
		
		serverInfo.WARPath			= serverProps.WARPath			?: serverJSON.app.WARPath			?: defaults.app.WARPath;
		
		// These are already hammered out above, so no need to go through all the defaults.
		serverInfo.serverConfigFile	= defaultServerConfigFile;
		serverInfo.name 			= defaultName;
		serverInfo.webroot 			= defaultwebroot;
		
		serverInfo.logdir			= serverInfo.webConfigDir & "/logs";
		
		if( serverInfo.debug ) {
			consoleLogger.info( "start server in - " & serverInfo.webroot );
			consoleLogger.info( "server name - " & serverInfo.name );
			consoleLogger.info( "server config file - " & defaultServerConfigFile );	
		}	
		
		if( !len( serverInfo.WARPath ) && !len( serverInfo.cfengine ) ) {
			serverInfo.cfengine = 'lucee@' & server.lucee.version;
		}
		
		if( serverInfo.cfengine.endsWith( '@' ) ) {
			serverInfo.cfengine = left( serverInfo.cfengine, len( serverInfo.cfengine ) - 1 );
		}
					
		var launchUtil 	= java.LaunchUtil;
		
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
	var processName = ( serverInfo.name is "" ? "CommandBox" : serverInfo.name );
    	  
    // As long as there's no WAR Path, let's install the engine to use.
	if( serverInfo.WARPath == '' ){
	
		// This will install the engine war to start, possibly downloading it first
		var installDetails = serverEngineService.install( cfengine=serverInfo.cfengine, basedirectory=serverInfo.webConfigDir );
		// This interception point can be used for additional configuration of the engine before it actually starts.
		interceptorService.announceInterception( 'onServerInstall', { serverInfo=serverInfo, installDetails=installDetails } );
		thisVersion = ' ' & installDetails.version;
		serverInfo.serverHome = installDetails.installDir;
		serverInfo.logdir = installDetails.installDir & "/logs";
			
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
		var processName = ( serverInfo.name is "" ? "CommandBox" : serverInfo.name ) & ' [' & listFirst( serverinfo.cfengine, '@' ) & thisVersion & ']';
				
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
	
	// This is a WAR
	} else {
		serverInfo.serverHome = getDirectoryFromPath( serverInfo.WARPath );
	}
		
	// Default tray icon
	serverInfo.trayIcon = ( len( serverInfo.trayIcon ) ? serverInfo.trayIcon : '#variables.libdir#/trayicon.png' ); 
	serverInfo.trayIcon = expandPath( serverInfo.trayIcon );
	
	// Set default options for all servers
	// TODO: Don't overwrite existing options with the same label.
	
    if( serverInfo.cfengine contains "lucee" ) {
		serverInfo.trayOptions.prepend( { 'label':'Open Web Admin', 'action':'openbrowser', 'url':'http://${runwar.host}:${runwar.port}/lucee/admin/web.cfm', 'image' : expandPath('/commandbox/system/config/server-icons/web_settings.png' ) } );
		serverInfo.trayOptions.prepend( { 'label':'Open Server Admin', 'action':'openbrowser', 'url':'http://${runwar.host}:${runwar.port}/lucee/admin/server.cfm', 'image' : expandPath('/commandbox/system/config/server-icons/server_settings.png' ) } );
	} else if( serverInfo.cfengine contains "railo" ) {
		serverInfo.trayOptions.prepend( { 'label':'Open Web Admin', 'action':'openbrowser', 'url':'http://${runwar.host}:${runwar.port}/railo-context/admin/web.cfm', 'image' : expandPath('/commandbox/system/config/server-icons/web_settings.png' ) } );
		serverInfo.trayOptions.prepend( { 'label':'Open Server Admin', 'action':'openbrowser', 'url':'http://${runwar.host}:${runwar.port}/railo-context/admin/server.cfm', 'image' : expandPath('/commandbox/system/config/server-icons/server_settings.png' ) } );
	} else if( serverInfo.cfengine contains "adobe" ) {
		serverInfo.trayOptions.prepend( { 'label':'Open Server Admin', 'action':'openbrowser', 'url':'http://${runwar.host}:${runwar.port}/CFIDE/administrator/enter.cfm', 'image' : expandPath('/commandbox/system/config/server-icons/server_settings.png' ) } );
	}
	
	serverInfo.trayOptions.prepend( { 'label':'Open Browser', 'action':'openbrowser', 'url':'http://${runwar.host}:${runwar.port}/', 'image' : expandPath('/commandbox/system/config/server-icons/home.png' ) } );
	serverInfo.trayOptions.prepend( { 'label':'Stop Server', 'action':'stopserver', 'image' : expandPath('/commandbox/system/config/server-icons/stop.png' ) } );
	serverInfo.trayOptions.prepend( { 'label': processName, 'disabled':true, 'image' : expandPath('/commandbox/system/config/server-icons/info.png' ) } );
	
    // This is due to a bug in RunWar not creating the right directory for the logs
    directoryCreate( serverInfo.logDir, true, true );
      
	interceptorService.announceInterception( 'onServerStart', { serverInfo=serverInfo } );
						
	// Turn struct of aliases into a comma-delimited list, plus resolve relative paths.
	// "/foo=C:\path,/bar=C:\another/path"
	var CLIAliases = '';
	for( var thisAlias in serverInfo.aliases ) {
		CLIAliases = CLIAliases.listAppend( thisAlias & '=' & fileSystemUtil.resolvePath( serverInfo.aliases[ thisAlias ], serverInfo.webroot ) );
	}
	
	// Turn struct of errorPages into a comma-delimited list.
	// --error-pages="404=/path/to/404.html,500=/path/to/500.html,1=/path/to/default.html"
	var errorPages = '';
	for( var thisErrorPage in serverInfo.errorPages ) {
		// "default" turns into "1"
		var tmp = thisErrorPage == 'default' ? 1 : thisErrorPage;
		tmp &= '=';
		// normalize slashes
		var thisPath = replace( serverInfo.errorPages[ thisErrorPage ], '\', '/', 'all' );
		// Add leading slash if it doesn't exist.
		tmp &= thisPath.startsWith( '/' ) ? thisPath : '/' & thisPath;
		errorPages = errorPages.listAppend( tmp );
	}
	// Bug in runwar requires me to completley omit this param unless it's populated
	// https://github.com/cfmlprojects/runwar/issues/33
	if( len( errorPages ) ) {
		errorPages = '--error-pages="#errorPages#"';
	}
	
	// Serialize tray options and write to temp file
	var trayOptionsPath = serverInfo.serverHome & '/trayOptions.json';
	var trayJSON = {
		'title' : processName,
		'tooltip' : processName,
		'items' : serverInfo.trayOptions
	};
	fileWrite( trayOptionsPath,  serializeJSON( trayJSON ) );


	var startupTimeout = 120;
	// Increase our startup allowance for Adobe engines, since a number of files are generated on the first request
	if( CFEngineName == 'adobe' ){
		startupTimeout=240;
	}
							
	// The java arguments to execute:  Shared server, custom web configs
	var args = ' #serverInfo.JVMargs# -Xmx#serverInfo.heapSize#m -Xms#serverInfo.heapSize#m'
			& ' #javaagent# -jar "#variables.jarPath#"'
			& ' --background=true --port #serverInfo.port# --host #serverInfo.host# --debug=#serverInfo.debug#'
			& ' --stop-port #serverInfo.stopsocket# --processname "#processName#" --log-dir "#serverInfo.logDir#"'
			& ' --open-browser #serverInfo.openbrowser#'
			& ' --open-url ' & ( serverInfo.SSLEnable ? 'https://#serverInfo.host#:#serverInfo.SSLPort#' : 'http://#serverInfo.host#:#serverInfo.port#' )
			& ( len( CFEngineName ) ? ' --cfengine-name "#CFEngineName#"' : '' )
			& ' --server-name "#serverInfo.name#" #errorPages# --welcome-files "index.cfm,index.cfml,default.cfm,index.html,index.htm,default.html,default.htm"'
			& ' --tray-icon "#serverInfo.trayIcon#" --tray-config "#trayOptionsPath#"'
			& ' --directoryindex "#serverInfo.directoryBrowsing#" --cfml-web-config "#serverInfo.webConfigDir#"'
			& ( len( CLIAliases ) ? ' --dirs "#CLIAliases#"' : '' )
			& ' --cfml-server-config "#serverInfo.serverConfigDir#" #serverInfo.runwarArgs# --timeout #startupTimeout#';
			
	// Starting a WAR
	if (serverInfo.WARPath != "" ) {
		args &= " -war ""#serverInfo.WARPath#""";
	// Stand alone server
	} else if( !installDetails.internal ){
		args &= " -war ""#serverInfo.webroot#"" --lib-dirs ""#installDetails.installDir#/WEB-INF/lib"" --web-xml-path ""#installDetails.installDir#/WEB-INF/web.xml""";
	// internal server
	} else {
		// The internal server borrows the CommandBox lib directory
		serverInfo.libDirs = serverInfo.libDirs.listAppend( variables.libDir );
		args &= " -war ""#serverInfo.webroot#"" --lib-dirs ""#serverInfo.libDirs#""";
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
		if( !fileExists(serverInfo.rewritesConfig) ){
			consoleLogger.error( '.' );
			consoleLogger.error( 'URL rewrite config not found [#serverInfo.rewritesConfig#]' );
			consoleLogger.error( '.' );
			return;
		}
		args &= " --urlrewrite-file ""#serverInfo.rewritesConfig#""";
	}
	// change status to starting + persist
	serverInfo.status = "starting";
	setServerInfo( serverInfo );
		
    if( serverInfo.debug ) {
		var cleanedArgs = cr & '    ' & trim( replaceNoCase( args, ' -', cr & '    -', 'all' ) );					
		consoleLogger.debug("Server start command: #javaCommand# #cleanedArgs#");
    }
    
		// thread the execution
		var threadName = 'server#hash( serverInfo.webroot )##createUUID()#';
		thread name="#threadName#" serverInfo=serverInfo args=args startupTimeout=startupTimeout {
			try{
				// execute the server command
				var  executeResult = '';
				var  executeError = '';
				// save server info and persist
				serverInfo.statusInfo = { command:variables.javaCommand, arguments:attributes.args, result:'' };
				setServerInfo( serverInfo );
				// Note this timeout is purposefully longer than the Runwar timeout so if the server takes too long, we get to capture the console info
				execute name=variables.javaCommand arguments=attributes.args timeout="#startupTimeout+20#" variable="executeResult" errorVariable="executeError";
				serverInfo.status="running";
			} catch (any e) {
				logger.error( "Error starting server: #e.message# #e.detail#", arguments );
				serverInfo.statusInfo.result &= e.message & ' ' & e.detail;
				serverInfo.status="unknown";
			} finally {
				// make sure these don't come back as nulls
				param name='local.executeResult' default='';
				param name='local.executeError' default='';
				serverInfo.statusInfo.result = serverInfo.statusInfo.result & executeResult & ' ' & executeError;
				setServerInfo( serverInfo );				
			}
		}
		
		
		// She'll be coming 'round the mountain when she comes...
		consoleLogger.warn( "The server for #serverInfo.webroot# is starting on #serverInfo.host#:#serverInfo.port#... type 'server status' to see result" );
		
		// If this is a one off command, wait for the thread to finish, otherwise the JVM will shutdown before
		// the server is started and the json files get updated.
		if( shell.getShellType() == 'command' || serverInfo.debug ) {
			thread action="join" name="#threadName#";
			
			// Pull latest info that was saved in the thread and output it. Since we made the 
			// user wait for the thread to finish, we might as well tell them what happened.
			wirebox.getinstance( name='CommandDSL', initArguments={ name : 'server status' } )
				.params( name = serverInfo.name )
				.run();			
		}
			
		
	}

	/**
	* Unified logic to resolve a server given an optional name, directory, and server.json path.
	* Returns resolved name, webroot, serverConfigFile, serverInfo from the last start and serverJSON
	* Use this for all 'server' commands that let a user specify the server they want by convention (CWD),
	* name, directory, or server.json path.  
	* 
	* @serverProps A struct that can contains name, directory, and/or serverConfigFile
	*
	* @returns a struct containing 
	* - defaultName
	* - defaults
	* - defaultServerConfigFile
	* - serverJSON
	* - serverInfo 
	*/
	function resolveServerDetails(
		required struct serverProps
	) {
		var locDebug = serverProps.debug ?: false;
		
		// As a convenient shorcut, allow the serverConfigFile to be passed via the name parameter.
		var tmpName = serverProps.name ?: '';
		var tmpNameResolved = fileSystemUtil.resolvePath( tmpName );
		// Check if there was no config file specified, but the name was specified and happens to exist as a file on disk
		if( !len( serverProps.serverConfigFile ?: '' ) && len( tmpName ) && fileExists( tmpNameResolved ) ) {
			// If so, swap the name into the server config param.
			serverProps.serverConfigFile = tmpNameResolved;
			structDelete( serverProps, 'name' );
		}
		
		// If a specific server.json file path was passed, use it.
		if( len( serverProps.serverConfigFile ?: '' ) ) {
			var defaultServerConfigFile = serverProps.serverConfigFile;
		// Otherwise, if there was a specific name passed, default a named server.json file for them
		} else if( len( serverProps.name ?: '' ) ) {
			var defaultServerConfigFile = fileSystemUtil.resolvePath( serverProps.directory ?: '' ) & "/server-#serverProps.name#.json";
		// Otherwise, the default is called "server.json" in the web root.
		} else {
			var defaultServerConfigFile = fileSystemUtil.resolvePath( serverProps.directory ?: '' ) & "/server.json";
		}

		// Get server descriptor from default location.
		// If starting by name and we guessed the server.json file name, this serverJSON maybe replaced later by another saved file.
	    if( locDebug ) { consoleLogger.debug("Looking for server JSON file by convention: #defaultServerConfigFile#"); }
		var serverJSON = readServerJSON( defaultServerConfigFile );
		
		// Get the web root out of the server.json, if specified and make it relative to the actual server.json file.
		// If user gave us a webroot, we use it first.
		if( len( arguments.serverProps.directory ?: '' ) ) {
			var defaultwebroot = arguments.serverProps.directory;
		    if( locDebug ) { consoleLogger.debug("webroot specified by user: #defaultwebroot#"); }
		// Get the web root out of the server.json, if specified and make it relative to the actual server.json file.
		} else if( len( serverJSON.web.webroot ?: '' ) ) {
			var defaultwebroot = fileSystemUtil.resolvePath( serverJSON.web.webroot, getDirectoryFromPath( defaultServerConfigFile ) );
		    if( locDebug ) { consoleLogger.debug("webroot pulled from server's JSON: #defaultwebroot#"); }
		// Otherwise default to the directory the server's JSON file lives in (which defaults to the CWD)
		} else {
			var defaultwebroot = fileSystemUtil.resolvePath( getDirectoryFromPath( defaultServerConfigFile ) );
		    if( locDebug ) { consoleLogger.debug("webroot defaulted to location of server's JSON file: #defaultwebroot#"); }
		}

		// If user types a name, use that above all else
		if( len( serverProps.name ?: '' ) ) {
			var defaultName = serverProps.name;
		} else if( len( serverJSON.name ?: '' ) ) {
			// otherwise use the name in the server config file if it's specified
			var defaultName = serverJSON.name;
		} else {
			// Don't do a final guess at the name yet so we don't affect the server discovery below.
			var defaultName = '';
		}		
		
		// Discover by shortname or server and get server info
		var serverInfo = getServerInfoByDiscovery(
			directory			= defaultwebroot,
			name				= defaultName,
			serverConfigFile	= serverProps.serverConfigFile ?: '' //  Since this takes precendence, I only want to use it if it was actually specified
		);
		
		// If we found a server, set our name.
		if( len( serverInfo.name ?: '' ) ) {
			defaultName = serverInfo.name;
		}		

		var serverIsNew = false;
		//  If it wasn't found, create new server info using defaults
		if( structIsEmpty( serverInfo ) ){
			
			if( !len( defaultName ) ) {
				// If there is still no name, default to the current directory
				// TODO: I don't care for this because it creates conflicts since many servers could have the name "webroot" on one machine.
				defaultName = replace( listLast( defaultwebroot, "\/" ), ':', '');				
			}
			
			// We need a new entry
			serverIsNew = true;
			serverInfo = getServerInfo( defaultwebroot, defaultName );
		}
				
		// If the user didn't provide an explicit config file and it turns out last time we started a server by this name, we used a different
		// config, let's re-read out that config JSON file to use instead of the default above.
		if( !len( serverProps.serverConfigFile ?: '' ) 
			&& len( serverInfo.serverConfigFile ?: '' ) 
			&& serverInfo.serverConfigFile != defaultServerConfigFile ) {
				
			// Get server descriptor again
		    if( locDebug ) { consoleLogger.debug("Switching to the last-used server JSON file for this server: #serverInfo.serverConfigFile#"); }
			serverJSON = readServerJSON( serverInfo.serverConfigFile );
			defaultServerConfigFile = serverInfo.serverConfigFile;
			
			// Now that we changed server JSONs, we need to recalculate the webroot.
		    if( locDebug ) { consoleLogger.debug("Recalculating web root based on new server JSON file."); }
			// If user gave us a webroot, we use it first.
			if( len( arguments.serverProps.directory ?: '' ) ) {
				var defaultwebroot = arguments.serverProps.directory;
			    if( locDebug ) { consoleLogger.debug("webroot specified by user: #defaultwebroot#"); }
			// Get the web root out of the server.json, if specified and make it relative to the actual server.json file.
			} else if( len( serverJSON.web.webroot ?: '' ) ) {
				var defaultwebroot = fileSystemUtil.resolvePath( serverJSON.web.webroot, getDirectoryFromPath( serverInfo.serverConfigFile ) );
			    if( locDebug ) { consoleLogger.debug("webroot pulled from server's JSON: #defaultwebroot#"); }
			// Otherwise default to the directory the server's JSON file lives in (which defaults to the CWD)
			} else {
				var defaultwebroot = fileSystemUtil.resolvePath( getDirectoryFromPath( serverInfo.serverConfigFile ) );
			    if( locDebug ) { consoleLogger.debug("webroot defaulted to location of server's JSON file: #defaultwebroot#"); }
			}
			 
		}
		
		// By now we've figured out the name, webroot, and serverConfigFile for this server.
		// Also return the serverInfo of the last values the server was started with (if ever)
		// and the serverJSON setting for the server, if they exist.
		return {
			defaultName : defaultName,
			defaultwebroot : defaultwebroot,
			defaultServerConfigFile : defaultServerConfigFile,
			serverJSON : serverJSON,
			serverInfo : serverInfo,
			serverIsNew : serverIsNew
		};
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
			structDelete( servers, arguments.serverInfo.id );
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
				// return now so we don't wipe out the original server.json file too in the next 
				// if statement! (because this was a "server-#name#.json" file) 
				return "Poof! Wiped out server " & serverInfo.name;
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
	 * Find out if a given host/port is already bound
	 * @host.hint host to test port on, defaults 127.0.0.1
 	 **/
	function isPortAvailable( host="127.0.0.1", required port ){
		try {
			var serverSocket = java.ServerSocket.init( javaCast( "int", arguments.port ),
													 javaCast( "int", 1 ),
													 java.InetAddress.getByName( arguments.host ) );
			serverSocket.close();
			return true;
		} catch( any var e ) {
			return false;
		}
	}


	/**
	 * Logic to tell if a server is running
	 * @serverInfo.hint Struct of server information
 	 **/
	function isServerRunning( required struct serverInfo ){
		return !isPortAvailable( serverInfo.host, serverInfo.stopSocket );
	}

	/**
	 * persist server info
	 * @serverInfo.hint struct of server info (ports, etc.)
 	 **/
	function setServerInfo( required struct serverInfo ){
		
		var servers 	= getServers();
		var webrootHash = hash( arguments.serverInfo.webroot & ucase( arguments.serverInfo.name ) );
		arguments.serverInfo.id = webrootHash;
		
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
						results[ thisKey ].id = hash( results[ thisKey ].webroot & ucase( results[ thisKey ].name ) );
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
	* Get a server information struct by name or directory.  
	* Returns empty struct if not found.
	* @directory.hint the directory to find
	* @name.hint The name to find
	*/
	struct function getServerInfoByDiscovery( required directory="", required name="", serverConfigFile="" ){
		
		if( len( arguments.serverConfigFile ) ){
			var foundServer = getServerInfoByServerConfigFile( arguments.serverConfigFile );
			if( structCount( foundServer ) ) {
				return foundServer;
			}
			return {};
		}
		
		if( len( arguments.name ) ){
			var foundServer = getServerInfoByName( arguments.name );
			if( structCount( foundServer ) ) {
				return foundServer;
			}
			return {};
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
	* Get a server information struct by serverConfigFile if not found it returns an empty struct
	* @name.serverConfigFile The serverConfigFile to find
	*/
	struct function getServerInfoByServerConfigFile( required serverConfigFile ){
		arguments.serverConfigFile = fileSystemUtil.resolvePath( arguments.serverConfigFile );
		var servers = getServers();
		for( var thisServer in servers ){
			if( fileSystemUtil.resolvePath( servers[ thisServer ].serverConfigFile ) == arguments.serverConfigFile ){
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
		arguments.webroot = fileSystemUtil.resolvePath( arguments.webroot );
		var servers = getServers();
		for( var thisServer in servers ){
			if( fileSystemUtil.resolvePath( servers[ thisServer ].webroot ) == arguments.webroot ){
				return servers[ thisServer ];
			}
		}

		return {};
	}

	/**
	* Get server info for webroot, if not created, it will init a new server info entry
	* @webroot.hint root directory for served content
 	**/
	struct function getServerInfo( required webroot , required name){
		var servers 	= getServers();
		var webrootHash = hash( arguments.webroot & ucase( arguments.name ) );
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
			JVMargs			: "",
			runwarArgs		: "",
			cfengine		: "",
			WARPath			: "",
			serverConfigFile : ""
		};
	}

	/**
	* Read a server.json file.  If it doesn't exist, returns an empty struct
	* This only returns properties specifically set in the file.
	*/
	struct function readServerJSON( required string path ) {
		if( fileExists( path ) ) {
			return deserializeJSON( fileRead( path ) );
		} else {
			return {};
		}
	}

	/**
	* Save a server.json file.
	*/
	function saveServerJSON( required string configFilePath, required struct data ) {
		var oldJSON = '';
		if( fileExists( arguments.configFilePath ) ) {
			oldJSON = fileRead( arguments.configFilePath );			
		}
		var newJSON = formatterUtil.formatJSON( serializeJSON( arguments.data ) );
		// Try to prevent bunping the date modified for no reason
		if( oldJSON != newJSON ) {
			fileWrite( arguments.configFilePath, newJSON );			
		}
	}
	
	/**
	* Dynamic completion for property name based on contents of server.json
	* @directory.hint web root
	* @all.hint Pass false to ONLY suggest existing setting names.  True will suggest all possible settings.
	*/ 	
	function completeProperty( required directory,  all=false ) {
		// Get all config settings currently set
		var props = JSONService.addProp( [], '', '', readServerJSON( arguments.directory & '/server.json' ) );
		
		// If we want all possible options...
		if( arguments.all ) {
			// ... Then add them in
			props = JSONService.addProp( props, '', '', getDefaultServerJSON() );
			// Suggest a couple optional web error pages
			props = JSONService.addProp( props, '', '', {
				web : {
					errorPages : {
						404 : '',
						500 : '',
						default : ''
					}
				}
			} );
		}
		
		return props;		
	}	
}
