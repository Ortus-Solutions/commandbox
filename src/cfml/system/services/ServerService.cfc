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
	property name='parser'					inject='parser';
	property name='systemSettings'			inject='SystemSettings';

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
		// Where custom server configs are stored
		variables.serverConfig = arguments.homeDir & "/servers.json";
		// Where custom servers are stored
		variables.customServerDirectory = arguments.homeDir & "/server/";
		// The JRE executable command
		variables.javaCommand = arguments.fileSystem.getJREExecutable();
		// The runwar jar path
		variables.jarPath = java.File.init( java.launchUtil.getClass().getProtectionDomain().getCodeSource()
				.getLocation().toURI().getSchemeSpecificPart() ).getAbsolutePath();

		// Init server config if not found
		if( !fileExists( variables.serverConfig ) ){
			initServers();
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
			'name' : d.name ?: '',
			'openBrowser' : d.openBrowser ?: true,
			'openBrowserURL' : d.openBrowserURL ?: '',
			'startTimeout' : 240,
			'stopsocket' : d.stopsocket ?: 0,
			'debug' : d.debug ?: false,
			'trace' : d.trace ?: false,
			'console' : d.console ?: false,
			'trayicon' : d.trayicon ?: '',
			// Duplicate so onServerStart interceptors don't actually change config settings via reference.
			'trayOptions' : duplicate( d.trayOptions ?: [] ),
			'trayEnable' : d.trayEnable ?: true,
			'jvm' : {
				'heapSize' : d.jvm.heapSize ?: 512,
				'minHeapSize' : d.jvm.minHeapSize ?: 0,
				'args' : d.jvm.args ?: '',
				'javaHome' : ( isDefined( 'd.jvm.javaHome' ) ? fileSystemUtil.getJREExecutable( d.jvm.javaHome ) : variables.javaCommand )
			},
			'web' : {
				'host' : d.web.host ?: '127.0.0.1',
				'directoryBrowsing' : d.web.directoryBrowsing ?: true,
				'webroot' : d.web.webroot ?: '',
				// Duplicate so onServerStart interceptors don't actually change config settings via refernce.
				'aliases' : duplicate( d.web.aliases ?: {} ),
				// Duplicate so onServerStart interceptors don't actually change config settings via refernce.
				'errorPages' : duplicate( d.web.errorPages ?: {} ),
				'welcomeFiles' : d.web.welcomeFiles ?: '',
				'http' : {
					'port' : d.web.http.port ?: 0,
					'enable' : d.web.http.enable ?: true
				},
				'ssl' : {
					'enable' : d.web.ssl.enable ?: false,
					'port' : d.web.ssl.port ?: 1443,
					'certFile' : d.web.ssl.certFile ?: '',
					'keyFile' : d.web.ssl.keyFile ?: '',
					'keyPass' : d.web.ssl.keyPass ?: ''
				},
				'rewrites' : {
					'enable' : d.web.rewrites.enable ?: false,
					'config' : d.web.rewrites.config ?: variables.rewritesDefaultConfig,
					'statusPath' : d.web.rewrites.statusPath ?: '',
					'configReloadSeconds' : d.web.rewrites.configReloadSeconds ?: ''
				},
				'basicAuth' : {
					'enable' : d.web.basicAuth.enable ?: true,
					'users' : d.web.basicAuth.users ?: {}
				}
			},
			'app' : {
				'logDir' : d.app.logDir ?: '',
				'libDirs' : d.app.libDirs ?: '',
				'webConfigDir' : d.app.webConfigDir ?: '',
				'serverConfigDir' : d.app.serverConfigDir ?: '',
				'webXML' : d.app.webXML ?: '',
				'standalone' : d.app.standalone ?: false,
				'WARPath' : d.app.WARPath ?: '',
				'cfengine' : d.app.cfengine ?: '',
				'restMappings' : d.app.cfengine ?: '',
				'serverHomeDirectory' : d.app.serverHomeDirectory ?: ''
			},
			'runwar' : {
				'args' : d.runwar.args ?: ''
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
		if( !isNull( serverProps.serverHomeDirectory ) ) {
			serverProps.serverHomeDirectory = fileSystemUtil.resolvePath( serverProps.serverHomeDirectory );
		}
		if( !isNull( serverProps.trayIcon ) ) {
			serverProps.trayIcon = fileSystemUtil.resolvePath( serverProps.trayIcon );
		}
		if( !isNull( serverProps.rewritesConfig ) ) {
			serverProps.rewritesConfig = fileSystemUtil.resolvePath( serverProps.rewritesConfig );
		}
		if( !isNull( serverProps.webConfigDir ) ) {
			serverProps.webConfigDir = fileSystemUtil.resolvePath( serverProps.webConfigDir );
		}
		if( !isNull( serverProps.serverConfigDir ) ) {
			serverProps.serverConfigDir = fileSystemUtil.resolvePath( serverProps.serverConfigDir );
		}
		if( !isNull( serverProps.webXML ) ) {
			serverProps.webXML = fileSystemUtil.resolvePath( serverProps.webXML );
		}
		if( !isNull( serverProps.libDirs ) ) {
			// Comma-delimited list needs each item resolved
			serverProps.libDirs = serverProps.libDirs
				.map( function( thisLibDir ){
					return fileSystemUtil.resolvePath( thisLibDir );
			 	} );
		}
		if( !isNull( serverProps.SSLCertFile ) ) {
			serverProps.SSLCertFile = fileSystemUtil.resolvePath( serverProps.SSLCertFile );
		}
		if( !isNull( serverProps.SSLKeyFile ) ) {
			serverProps.SSLKeyFile = fileSystemUtil.resolvePath( serverProps.SSLKeyFile );
		}

		if( structKeyExists( serverProps, 'trace' ) && serverProps.trace ) {
			serverProps.debug = true;
		}

		// Look up the server that we're starting
		var serverDetails = resolveServerDetails( arguments.serverProps );

		interceptorService.announceInterception( 'preServerStart', { serverDetails=serverDetails, serverProps=serverProps } );

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
		var boxJSON = packageService.readPackageDescriptorRaw( defaultwebroot );			// *
		// Get defaults																		// *
		var defaults = getDefaultServerJSON();												// *
																							// *
		// Backwards compat with boxJSON default port.  Remove in a future version			// *
		// The property in box.json is deprecated. 											// *
		if( (boxJSON.defaultPort ?: 0) > 0 ) {												// *
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
			if( isNull( serverProps[ prop ] ) || listFindNoCase( 'saveSettings,serverConfigFile,debug,force,console,trace', prop ) ) {
				continue;
			}
	    	var configPath = replace( fileSystemUtil.resolvePath( defaultServerConfigFileDirectory ), '\', '/', 'all' ) & '/';
			// Only need switch cases for properties that are nested or use different name
			switch(prop) {
			    case "port":
					serverJSON[ 'web' ][ 'http' ][ 'port' ] = serverProps[ prop ];
			         break;
			    case "host":
					serverJSON[ 'web' ][ 'host' ] = serverProps[ prop ];
			         break;
			    case "directory":
			    	// This path is canonical already.
			    	var thisDirectory = replace( serverProps[ 'directory' ], '\', '/', 'all' ) & '/';
			    	// If the web root is south of the server's JSON, make it relative for better portability.
			    	if( thisDirectory contains configPath ) {
			    		thisDirectory = replaceNoCase( thisDirectory, configPath, '' );
			    	}
					serverJSON[ 'web' ][ 'webroot' ] = thisDirectory;
			         break;
			    case "trayIcon":
			    	// This path is canonical already.
			    	var thisFile = replace( serverProps[ 'trayIcon' ], '\', '/', 'all' );
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
			    	// This path is canonical already.
			    	var thisDirectory = replace( serverProps[ 'webConfigDir' ], '\', '/', 'all' ) & '/';
			    	// If the webConfigDir is south of the server's JSON, make it relative for better portability.
			    	if( thisDirectory contains configPath ) {
			    		thisDirectory = replaceNoCase( thisDirectory, configPath, '' );
			    	}
					serverJSON[ 'app' ][ 'webConfigDir' ] = thisDirectory;
			        break;
			    case "serverConfigDir":
			    	// This path is canonical already.
			    	var thisDirectory = replace( serverProps[ 'serverConfigDir' ], '\', '/', 'all' ) & '/';
			    	// If the webConfigDir is south of the server's JSON, make it relative for better portability.
			    	if( thisDirectory contains configPath ) {
			    		thisDirectory = replaceNoCase( thisDirectory, configPath, '' );
			    	}
					serverJSON[ 'app' ][ 'serverConfigDir' ] = thisDirectory;
			         break;
			    case "webXML":
			    	// This path is canonical already.
			    	var thisFile = replace( serverProps[ 'webXML' ], '\', '/', 'all' );
			    	// If the webXML is south of the server's JSON, make it relative for better portability.
			    	if( thisFile contains configPath ) {
			    		thisFile = replaceNoCase( thisFile, configPath, '' );
			    	}
					serverJSON[ 'app' ][ 'webXML' ] = thisFile;
			         break;
			    case "libDirs":
					serverJSON[ 'app' ][ 'libDirs' ] = serverProps[ 'libDirs' ]
						.listMap( function( thisLibDir ) {
							// This path is canonical already.
					    	var thisLibDir = replace( thisLibDir, '\', '/', 'all' );
					    	// If the libDir is south of the server's JSON, make it relative for better portability.
					    	if( thisLibDir contains configPath ) {
					    		return replaceNoCase( thisLibDir, configPath, '' );
					    	} else {
					    		return thisLibDir;
					    	}
						} );

			         break;
			    case "cfengine":
					serverJSON[ 'app' ][ 'cfengine' ] = serverProps[ prop ];
			         break;
			    case "restMappings":
					serverJSON[ 'app' ][ 'restMappings' ] = serverProps[ prop ];
			         break;
			    case "WARPath":
			    	// This path is canonical already.
			    	var thisFile = replace( serverProps[ 'WARPath' ], '\', '/', 'all' );
			    	// If the trayIcon is south of the server's JSON, make it relative for better portability.
			    	if( thisFile contains configPath ) {
			    		thisFile = replaceNoCase( thisFile, configPath, '' );
			    	}
					serverJSON[ 'app' ][ 'WARPath' ] = thisFile;
			         break;
			    case "serverHomeDirectory":
			    	// This path is canonical already.
			    	var thisDirectory = replace( serverProps[ 'serverHomeDirectory' ], '\', '/', 'all' ) & '/';
			    	// If the webConfigDir is south of the server's JSON, make it relative for better portability.
			    	if( thisDirectory contains configPath ) {
			    		thisDirectory = replaceNoCase( thisDirectory, configPath, '' );
			    	}
					serverJSON[ 'app' ][ 'serverHomeDirectory' ] = thisDirectory;
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
			    case "SSLCertFile":
					serverJSON[ 'web' ][ 'SSL' ][ 'certFile' ] = serverProps[ prop ];
			         break;
			    case "SSLKeyFile":
					serverJSON[ 'web' ][ 'SSL' ][ 'keyFile' ] = serverProps[ prop ];
			         break;
			    case "SSLKeyPass":
					serverJSON[ 'web' ][ 'SSL' ][ 'keyPass' ] = serverProps[ prop ];
			         break;
			    case "welcomeFiles":
					serverJSON[ 'web' ][ 'welcomeFiles' ] = serverProps[ prop ];
			         break;
			    case "rewritesEnable":
					serverJSON[ 'web' ][ 'rewrites' ][ 'enable' ] = serverProps[ prop ];
			         break;
			    case "rewritesConfig":
			    	// This path is canonical already.
			    	var thisFile = replace( serverProps[ 'rewritesConfig' ], '\', '/', 'all' );
			    	// If the trayIcon is south of the server's JSON, make it relative for better portability.
			    	if( thisFile contains configPath ) {
			    		thisFile = replaceNoCase( thisFile, configPath, '' );
			    	}
					serverJSON[ 'web' ][ 'rewrites' ][ 'config' ] = thisFile;
			         break;
			    case "heapSize":
					serverJSON[ 'JVM' ][ 'heapSize' ] = serverProps[ prop ];
			         break;
			    case "minHeapSize":
					serverJSON[ 'JVM' ][ 'minHeapSize' ] = serverProps[ prop ];
			         break;
			    case "JVMArgs":
					serverJSON[ 'JVM' ][ 'args' ] = serverProps[ prop ];
			         break;
			    case "javaHomeDirectory":
					serverJSON[ 'JVM' ][ 'javaHome' ] = serverProps[ prop ];
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

		systemSettings.expandDeepSystemSettings( serverJSON );
		systemSettings.expandDeepSystemSettings( defaults );

		// Setup serverinfo according to params
		// Hand-entered values take precendence, then settings saved in server.json, and finally defaults.
		// The big servers.json is only used to keep a record of the last values the server was started with
		serverInfo.trace 			= serverProps.trace 			?: serverJSON.trace 				?: defaults.trace;
		serverInfo.debug 			= serverProps.debug 			?: serverJSON.debug 				?: defaults.debug;
		serverInfo.console 			= serverProps.console 			?: serverJSON.console 				?: defaults.console;
		serverInfo.openbrowser		= serverProps.openbrowser 		?: serverJSON.openbrowser			?: defaults.openbrowser;
		serverInfo.openbrowserURL	= serverProps.openbrowserURL	?: serverJSON.openbrowserURL		?: defaults.openbrowserURL;


		serverInfo.host				= serverProps.host 				?: serverJSON.web.host				?: defaults.web.host;
		// If the last port we used is taken, remove it from consideration.
		if( serverInfo.port == 0 || !isPortAvailable( serverInfo.host, serverInfo.port ) ) { serverInfo.delete( 'port' ); }
		// Port is the only setting that automatically carries over without being specified since it's random.
		serverInfo.port 			= serverProps.port 				?: serverJSON.web.http.port			?: serverInfo.port	?: defaults.web.http.port;
		// Server default is 0 not null.
		if( serverInfo.port == 0 ) {
			serverInfo.port = getRandomPort( serverInfo.host );
		}

		// Double check that the port in the user params or server.json isn't in use
		if( !isPortAvailable( serverInfo.host, serverInfo.port ) ) {
			consoleLogger.error( "." );
			var badPortlocation = 'config';
			if( serverProps.keyExists( 'port' ) ) {
				badPortlocation = 'start params';
			} else if ( len( defaults.web.http.port ?: '' ) ) {
				badPortlocation = 'server.json';
			} else {
				badPortlocation = 'config server defaults';
			}
			consoleLogger.error( "You asked for port [#( serverProps.port ?: serverJSON.web.http.port ?: defaults.web.http.port ?: '?' )#] in your #badPortlocation# but it's already in use so I'm ignoring it and choosing a random one for you." );
			consoleLogger.error( "." );
			serverInfo.port = getRandomPort( serverInfo.host );
		}

		// If there's no open URL, let's create a complete one
		if( !serverInfo.openbrowserURL.len() ) {
			serverInfo.openbrowserURL = serverInfo.SSLEnable ? 'https://#serverInfo.host#:#serverInfo.SSLPort#' : 'http://#serverInfo.host#:#serverInfo.port#';
		// Partial URL like /admin/login.cm
		} else if ( left( serverInfo.openbrowserURL, 4 ) != 'http' ) {
			if( !serverInfo.openbrowserURL.startsWith( '/' ) ) {
				serverInfo.openbrowserURL = '/' & serverInfo.openbrowserURL;
			}
			serverInfo.openbrowserURL = ( serverInfo.SSLEnable ? 'https://#serverInfo.host#:#serverInfo.SSLPort#' : 'http://#serverInfo.host#:#serverInfo.port#' ) & serverInfo.openbrowserURL;
		}

		serverInfo.stopsocket		= serverProps.stopsocket		?: serverJSON.stopsocket 			?: getRandomPort( serverInfo.host );

		// relative trayIcon in server.json is resolved relative to the server.json
		if( serverJSON.keyExists( 'app' ) && serverJSON.app.keyExists( 'webConfigDir' ) ) { serverJSON.app.webConfigDir = fileSystemUtil.resolvePath( serverJSON.app.webConfigDir, defaultServerConfigFileDirectory ); }
		// relative trayIcon in config setting server defaults is resolved relative to the web root
		if( len( defaults.app.webConfigDir ?: '' ) ) { defaults.app.webConfigDir = fileSystemUtil.resolvePath( defaults.app.webConfigDir, defaultwebroot ); }
		serverInfo.webConfigDir 	= serverProps.webConfigDir 		?: serverJSON.app.webConfigDir 		?: defaults.app.webConfigDir;

		// relative trayIcon in server.json is resolved relative to the server.json
		if( serverJSON.keyExists( 'app' ) && serverJSON.app.keyExists( 'serverConfigDir' ) ) { serverJSON.app.serverConfigDir = fileSystemUtil.resolvePath( serverJSON.app.serverConfigDir, defaultServerConfigFileDirectory ); }
		// relative trayIcon in config setting server defaults is resolved relative to the web root
		if( len( defaults.app.serverConfigDir ?: '' ) ) { defaults.app.serverConfigDir = fileSystemUtil.resolvePath( defaults.app.serverConfigDir, defaultwebroot ); }
		serverInfo.serverConfigDir 	= serverProps.serverConfigDir 	?: serverJSON.app.serverConfigDir 	?: defaults.app.serverConfigDir;

		// relative trayIcon in server.json is resolved relative to the server.json
		if( serverJSON.keyExists( 'app' ) && serverJSON.app.keyExists( 'webXML' ) ) { serverJSON.app.webXML = fileSystemUtil.resolvePath( serverJSON.app.webXML, defaultServerConfigFileDirectory ); }
		// relative trayIcon in config setting server defaults is resolved relative to the web root
		if( len( defaults.app.webXML ?: '' ) ) { defaults.app.webXML = fileSystemUtil.resolvePath( defaults.app.webXML, defaultwebroot ); }
		serverInfo.webXML 			= serverProps.webXML 			?: serverJSON.app.webXML 			?: defaults.app.webXML;

		// relative trayIcon in server.json is resolved relative to the server.json
		if( serverJSON.keyExists( 'trayIcon' ) ) { serverJSON.trayIcon = fileSystemUtil.resolvePath( serverJSON.trayIcon, defaultServerConfigFileDirectory ); }
		// relative trayIcon in config setting server defaults is resolved relative to the web root
		if( defaults.keyExists( 'trayIcon' ) && len( defaults.trayIcon ) ) { defaults.trayIcon = fileSystemUtil.resolvePath( defaults.trayIcon, defaultwebroot ); }
		serverInfo.trayIcon			= serverProps.trayIcon 			?: serverJSON.trayIcon 				?: defaults.trayIcon;

		serverInfo.SSLEnable 		= serverProps.SSLEnable 		?: serverJSON.web.SSL.enable			?: defaults.web.SSL.enable;
		serverInfo.HTTPEnable		= serverProps.HTTPEnable 		?: serverJSON.web.HTTP.enable			?: defaults.web.HTTP.enable;
		serverInfo.SSLPort			= serverProps.SSLPort 			?: serverJSON.web.SSL.port				?: defaults.web.SSL.port;
		
		// relative certFile in server.json is resolved relative to the server.json
		if( isDefined( 'serverJSON.web.SSL.certFile' ) ) { serverJSON.web.SSL.certFile = fileSystemUtil.resolvePath( serverJSON.web.SSL.certFile, defaultServerConfigFileDirectory ); }
		// relative certFile in config setting server defaults is resolved relative to the web root
		if( len( defaults.web.SSL.certFile ?: '' ) ) { defaults.web.SSL.certFile = fileSystemUtil.resolvePath( defaults.web.SSL.certFile, defaultwebroot ); }
		serverInfo.SSLCertFile 		= serverProps.SSLCertFile 		?: serverJSON.web.SSL.certFile			?: defaults.web.SSL.certFile;
		
		// relative keyFile in server.json is resolved relative to the server.json
		if( isDefined( 'serverJSON.web.SSL.keyFile' ) ) { serverJSON.web.SSL.keyFile = fileSystemUtil.resolvePath( serverJSON.web.SSL.keyFile, defaultServerConfigFileDirectory ); }
		// relative trayIcon in config setting server defaults is resolved relative to the web root
		if( len( defaults.web.SSL.keyFile ?: '' ) ) { defaults.web.SSL.keyFile = fileSystemUtil.resolvePath( defaults.web.SSL.keyFile, defaultwebroot ); }
		serverInfo.SSLKeyFile 		= serverProps.SSLKeyFile 		?: serverJSON.web.SSL.keyFile			?: defaults.web.SSL.keyFile;
		
		serverInfo.SSLKeyPass 		= serverProps.SSLKeyPass 		?: serverJSON.web.SSL.keyPass			?: defaults.web.SSL.keyPass;
		serverInfo.rewritesEnable 	= serverProps.rewritesEnable	?: serverJSON.web.rewrites.enable		?: defaults.web.rewrites.enable;
		serverInfo.rewritesStatusPath = 							   serverJSON.web.rewrites.statusPath	?: defaults.web.rewrites.statusPath;
		serverInfo.rewritesConfigReloadSeconds =					   serverJSON.web.rewrites.configReloadSeconds ?: defaults.web.rewrites.configReloadSeconds;
		serverInfo.basicAuthEnable 	= 								   serverJSON.web.basicAuth.enable		?: defaults.web.basicAuth.enable;
		serverInfo.basicAuthUsers 	= 								   serverJSON.web.basicAuth.users		?: defaults.web.basicAuth.users;
		serverInfo.welcomeFiles 	= serverProps.welcomeFiles		?: serverJSON.web.welcomeFiles			?: defaults.web.welcomeFiles;

		serverInfo.trayEnable	 	= serverJSON.trayEnable			?: defaults.trayEnable;


		// Clean up spaces in welcome file list
		serverInfo.welcomeFiles = serverInfo.welcomeFiles.listMap( function( i ){ return trim( i ); } );


		// relative rewrite config path in server.json is resolved relative to the server.json
		if( isDefined( 'serverJSON.web.rewrites.config' ) ) { serverJSON.web.rewrites.config = fileSystemUtil.resolvePath( serverJSON.web.rewrites.config, defaultServerConfigFileDirectory ); }
		// relative rewrite config path in config setting server defaults is resolved relative to the web root
		if( isDefined( 'defaults.web.rewrites.config' ) ) { defaults.web.rewrites.config = fileSystemUtil.resolvePath( defaults.web.rewrites.config, defaultwebroot ); }
		serverInfo.rewritesConfig 	= serverProps.rewritesConfig 	?: serverJSON.web.rewrites.config 	?: defaults.web.rewrites.config;

		serverInfo.heapSize 		= serverProps.heapSize 			?: serverJSON.JVM.heapSize			?: defaults.JVM.heapSize;
		serverInfo.minHeapSize 		= serverProps.minHeapSize		?: serverJSON.JVM.minHeapSize		?: defaults.JVM.minHeapSize;

		if( isDefined( 'serverProps.javaHomeDirectory' ) ) {
			serverInfo.javaHome = fileSystemUtil.getJREExecutable( serverProps.javaHomeDirectory );
		} else if( isDefined( 'serverJSON.JVM.javaHome' ) ) {
			serverInfo.javaHome = fileSystemUtil.getJREExecutable( serverJSON.JVM.javaHome );
		} else {
			serverInfo.javaHome = defaults.JVM.javaHome;
		}

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

		// Server startup timeout
		serverInfo.startTimeout		= serverProps.startTimeout 			?: serverJSON.startTimeout 	?: defaults.startTimeout;

		// relative lib dirs in server.json are resolved relative to the server.json
		if( serverJSON.keyExists( 'app' ) && serverJSON.app.keyExists( 'libDirs' ) ) {
			serverJSON.app.libDirs = serverJSON.app.libDirs.listMap( function( thisLibDir ){
				return fileSystemUtil.resolvePath( thisLibDir, defaultServerConfigFileDirectory );
			});
		}
		// relative lib dirs in config setting server defaults are resolved relative to the web root
		if( defaults.keyExists( 'app' ) && defaults.app.keyExists( 'libDirs' ) && len( defaults.app.libDirs ) ) {
			// For each lib dir in the list, resolve the path, but only keep it if the folder actually exists.
			// This allows for "optional" global lib dirs.
			// listReduce starts with an initial value of "" and aggregates the new list, onluy appending the items it wants to keep
			defaults.app.libDirs = defaults.app.libDirs.listReduce( function( thisLibDirs, thisLibDir ){
				thisLibDir = fileSystemUtil.resolvePath( thisLibDir, defaultwebroot );
				if( directoryExists( thisLibDir ) ) {
					thisLibDirs.listAppend( thisLibDir );
				} else if( serverInfo.debug ) {
					consoleLogger.info( "Ignoring non-existant global lib dir: " & thisLibDir );
				}
				return thisLibDirs;
			}, '' );
		}
		// Global defauls are always added on top of whatever is specified by the user or server.json
		serverInfo.libDirs		= ( serverProps.libDirs		?: serverJSON.app.libDirs ?: '' ).listAppend( defaults.app.libDirs );

		serverInfo.cfengine			= serverProps.cfengine			?: serverJSON.app.cfengine			?: defaults.app.cfengine;

		serverInfo.restMappings		= serverProps.restMappings		?: serverJSON.app.restMappings		?: defaults.app.restMappings;
		// relative rewrite config path in server.json is resolved relative to the server.json
		if( isDefined( 'serverJSON.app.WARPath' ) && len( serverJSON.app.WARPath ) ) { serverJSON.app.WARPath = fileSystemUtil.resolvePath( serverJSON.app.WARPath, defaultServerConfigFileDirectory ); }
		if( isDefined( 'defaults.app.WARPath' ) && len( defaults.app.WARPath )  ) { defaults.app.WARPath = fileSystemUtil.resolvePath( defaults.app.WARPath, defaultwebroot ); }
		serverInfo.WARPath			= serverProps.WARPath			?: serverJSON.app.WARPath			?: defaults.app.WARPath;

		// relative rewrite config path in server.json is resolved relative to the server.json
		if( isDefined( 'serverJSON.app.serverHomeDirectory' ) && len( serverJSON.app.serverHomeDirectory ) ) { serverJSON.app.serverHomeDirectory = fileSystemUtil.resolvePath( serverJSON.app.serverHomeDirectory, defaultServerConfigFileDirectory ); }
		if( isDefined( 'defaults.app.serverHomeDirectory' ) && len( defaults.app.serverHomeDirectory )  ) { defaults.app.serverHomeDirectory = fileSystemUtil.resolvePath( defaults.app.serverHomeDirectory, defaultwebroot ); }
		serverInfo.serverHomeDirectory			= serverProps.serverHomeDirectory			?: serverJSON.app.serverHomeDirectory			?: defaults.app.serverHomeDirectory;

		// These are already hammered out above, so no need to go through all the defaults.
		serverInfo.serverConfigFile	= defaultServerConfigFile;
		serverInfo.name 			= defaultName;
		serverInfo.webroot 			= defaultwebroot;

		if( serverInfo.debug ) {
			consoleLogger.info( "start server in - " & serverInfo.webroot );
			consoleLogger.info( "server name - " & serverInfo.name );
			consoleLogger.info( "server config file - " & defaultServerConfigFile );
		}

		if( !len( serverInfo.WARPath ) && !len( serverInfo.cfengine ) ) {
			// Turn 1.2.3.4 into 1.2.3+4
			serverInfo.cfengine = 'lucee@' & reReplace( server.lucee.version, '([0-9]*.[0-9]*.[0-9]*)(.)([0-9]*)', '\1+\3' );
		}

		if( serverInfo.cfengine.endsWith( '@' ) ) {
			serverInfo.cfengine = left( serverInfo.cfengine, len( serverInfo.cfengine ) - 1 );
		}

		var launchUtil 	= java.LaunchUtil;

	    // Default java agent for embedded Lucee engine
	    var javaagent = serverinfo.cfengine contains 'lucee' ? '-javaagent:#libdir#/lucee-inst.jar' : '';

	    // Regardless of a custom server home, this is still used for various temp files and logs
	    serverinfo.customServerFolder = getCustomServerFolder( serverInfo );
	    directoryCreate( serverinfo.customServerFolder, true, true );

	    // Not sure what Runwar does with this, but it wants to know what CFEngine we're starting (if we know)
	    var CFEngineName = '';
	    CFEngineName = serverinfo.cfengine contains 'lucee' ? 'lucee' : CFEngineName;
	    CFEngineName = serverinfo.cfengine contains 'railo' ? 'railo' : CFEngineName;
	    CFEngineName = serverinfo.cfengine contains 'adobe' ? 'adobe' : CFEngineName;
	    CFEngineName = serverinfo.warPath contains 'adobe' ? 'adobe' : CFEngineName;

		var processName = ( serverInfo.name is "" ? "CommandBox" : serverInfo.name );

	    // As long as there's no WAR Path, let's install the engine to use.
		if( serverInfo.WARPath == '' ){

			// This will install the engine war to start, possibly downloading it first
			var installDetails = serverEngineService.install( cfengine=serverInfo.cfengine, basedirectory=serverinfo.customServerFolder, serverInfo=serverInfo, serverHomeDirectory=serverInfo.serverHomeDirectory );
			serverInfo.serverHomeDirectory = installDetails.installDir;
			// TODO: As of 3.5 "serverHome" is for backwards compat.  Remove in later version in favor of serverHomeDirectory above
			serverInfo.serverHome = installDetails.installDir;
			serverInfo.logdir = serverInfo.serverHomeDirectory & "/logs";
			serverInfo.consolelogPath	= serverInfo.logdir & '/server.out.txt';
			serverInfo.engineName = installDetails.engineName;
			serverInfo.engineVersion = installDetails.version;

			// This is for one-time setup tasks on first install
			if( installDetails.initialInstall ) {
				// Make current settings available to package scripts
				setServerInfo( serverInfo );

				// This interception point can be used for additional configuration of the engine before it actually starts.
				interceptorService.announceInterception( 'onServerInstall', { serverInfo=serverInfo, installDetails=installDetails } );
			}

			// If Lucee server, set the java agent
			if( serverInfo.cfengine contains "lucee" ) {
				// Detect Lucee 4.x
				if( installDetails.version.listFirst( '.' ) < 5 ) {
					javaagent = '-javaagent:#serverInfo.serverHomeDirectory#/WEB-INF/lib/lucee-inst.jar';
				} else {
					// Lucee 5+ doesn't need the Java agent
					javaagent = '';
				}
			}
			// If external Railo server, set the java agent
			if( serverInfo.cfengine contains "railo" ) {
				javaagent = '-javaagent:#serverInfo.serverHomeDirectory#/WEB-INF/lib/railo-inst.jar';
			}

			// Add in "/cf_scripts" alias for 2016+ servers if the /cf_scripts folder exists in the war we're starting and there isn't already an alias
			// for this.  I'm specifically not checking the engine name and version so this will work on regular Adobe wars and be future proof.
			if( directoryExists( serverInfo.serverHomeDirectory & '/cf_scripts' ) && !serverInfo.aliases.keyExists( '/cf_scripts' )  ) {
				serverInfo.aliases[ '/cf_scripts' ]	= serverInfo.serverHomeDirectory & '/cf_scripts';
			}

			// The process native name
			var processName = ( serverInfo.name is "" ? "CommandBox" : serverInfo.name ) & ' [' & listFirst( serverinfo.cfengine, '@' ) & ' ' & installDetails.version & ']';
			var displayServerName = ( serverInfo.name is "" ? "CommandBox" : serverInfo.name );
			var displayEngineName = listFirst( serverinfo.cfengine, '@' ) & ' ' & installDetails.version;

		// This is a WAR
		} else {
			// If WAR is a file
			if( fileExists( serverInfo.WARPath ) ){
				// It will be extracted into a folder named after the file
				serverInfo.serverHomeDirectory = reReplaceNoCase( serverInfo.WARPath, '(.*)(\.zip|\.war)', '\1' );

				// Expand the war if it doesn't exist or we're forcing
				if( !directoryExists( serverInfo.serverHomeDirectory ) || ( serverProps.force ?: false ) ) {
					consoleLogger.info( "Exploding WAR archive...");
					directoryCreate( serverInfo.serverHomeDirectory, true, true );
					zip action="unzip" file="#serverInfo.WARPath#" destination="#serverInfo.serverHomeDirectory#" overwrite="true";
				}

			// If WAR is a folder
			} else {
				// Just use it
				serverInfo.serverHomeDirectory = serverInfo.WARPath;
			}
			// Create a custom server folder to house the logs
			serverInfo.logdir = serverinfo.customServerFolder & "/logs";
			serverInfo.consolelogPath	= serverInfo.logdir & '/server.out.txt';
		}

		// Find the correct tray icon for this server
		if( !len( serverInfo.trayIcon ) ) {
			var iconSize = fileSystemUtil.isWindows() ? '-32px' : '';
		    if( CFEngineName contains "lucee" ) {
		    	serverInfo.trayIcon = '/commandbox/system/config/server-icons/trayicon-lucee#iconSize#.png';
			} else if( CFEngineName contains "railo" ) {
		    	serverInfo.trayIcon = '/commandbox/system/config/server-icons/trayicon-railo#iconSize#.png';
			} else if( CFEngineName contains "adobe" ) {

				if( listFirst( serverInfo.engineVersion, '.' ) == 9 ) {
					serverInfo.trayIcon = '/commandbox/system/config/server-icons/trayicon-cf09#iconSize#.png';
				} else if( listFirst( serverInfo.engineVersion, '.' ) == 10 ) {
					serverInfo.trayIcon = '/commandbox/system/config/server-icons/trayicon-cf10#iconSize#.png';
				} else if( listFirst( serverInfo.engineVersion, '.' ) == 11 ) {
					serverInfo.trayIcon = '/commandbox/system/config/server-icons/trayicon-cf11#iconSize#.png';
				} else if( listFirst( serverInfo.engineVersion, '.' ) == 2016 ) {
					serverInfo.trayIcon = '/commandbox/system/config/server-icons/trayicon-cf2016#iconSize#.png';
				} else {
					serverInfo.trayIcon = '/commandbox/system/config/server-icons/trayicon-cf2016#iconSize#.png';
				}

			}
		}

		// Default tray icon
		serverInfo.trayIcon = ( len( serverInfo.trayIcon ) ? serverInfo.trayIcon : '/commandbox/system/config/server-icons/trayicon.png' );
		serverInfo.trayIcon = expandPath( serverInfo.trayIcon );

		// Set default options for all servers
		// TODO: Don't overwrite existing options with the same label.

	/*	serverInfo.trayOptions.prepend(
			{
				"label":"Advanced",
				"items": [
					{ "label" : "Browse File System", "hotkey" : "B", "action" : "openfilesystem", "path" : "", "image" : expandPath('/commandbox/system/config/server-icons/info.png' ) },
					{ "label" : displayEngineName, "disabled" : true, 'checkbox': true, "image" : expandPath('/commandbox/system/config/server-icons/info.png' )  },
					{ "label" : "PID: ${runwar.PID}", "disabled" : true, 'checkbox': true, "image" : expandPath('/commandbox/system/config/server-icons/info.png' )  }
				]
			} );*/

	    if( CFEngineName contains "lucee" ) {
			serverInfo.trayOptions.prepend( { 'label':'Open Web Admin', 'action':'openbrowser', 'url':'http://${runwar.host}:${runwar.port}/lucee/admin/web.cfm', 'image' : expandPath('/commandbox/system/config/server-icons/web_settings.png' ) } );
			serverInfo.trayOptions.prepend( { 'label':'Open Server Admin', 'action':'openbrowser', 'url':'http://${runwar.host}:${runwar.port}/lucee/admin/server.cfm', 'image' : expandPath('/commandbox/system/config/server-icons/server_settings.png' ) } );
		} else if( CFEngineName contains "railo" ) {
			serverInfo.trayOptions.prepend( { 'label':'Open Web Admin', 'action':'openbrowser', 'url':'http://${runwar.host}:${runwar.port}/railo-context/admin/web.cfm', 'image' : expandPath('/commandbox/system/config/server-icons/web_settings.png' ) } );
			serverInfo.trayOptions.prepend( { 'label':'Open Server Admin', 'action':'openbrowser', 'url':'http://${runwar.host}:${runwar.port}/railo-context/admin/server.cfm', 'image' : expandPath('/commandbox/system/config/server-icons/server_settings.png' ) } );
		} else if( CFEngineName contains "adobe" ) {
			serverInfo.trayOptions.prepend( { 'label':'Open Server Admin', 'action':'openbrowser', 'url':'http://${runwar.host}:${runwar.port}/CFIDE/administrator/enter.cfm', 'image' : expandPath('/commandbox/system/config/server-icons/server_settings.png' ) } );
		}

		serverInfo.trayOptions.prepend( { 'label':'Open Browser', 'action':'openbrowser', 'url': serverInfo.openbrowserURL, 'image' : expandPath('/commandbox/system/config/server-icons/home.png' ) } );
	/*	serverInfo.trayOptions.prepend( { 'label' : 'Restart Server', 'hotkey':'R', 'action' : 'restartserver', 'image': expandPath('/commandbox/system/config/server-icons/home.png' ) } );
	*/
		serverInfo.trayOptions.prepend( { 'label':'Stop Server', 'action':'stopserver', 'image' : expandPath('/commandbox/system/config/server-icons/stop.png' ) } );
		//serverInfo.trayOptions.prepend( { 'label': displayServerName, 'disabled':true, 'image' : expandPath('/commandbox/system/config/server-icons/info.png' ) } );

	    // This is due to a bug in RunWar not creating the right directory for the logs
	    directoryCreate( serverInfo.logDir, true, true );

		// Make current settings available to package scripts
		setServerInfo( serverInfo );
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

		// Serialize tray options and write to temp file
		var trayOptionsPath = serverinfo.customServerFolder & '/trayOptions.json';
		var trayJSON = {
			//'title' : displayServerName,
			'title' : processName,
			'tooltip' : processName,
			'items' : serverInfo.trayOptions
		};
		fileWrite( trayOptionsPath,  serializeJSON( trayJSON ) );
		var background = !(serverInfo.console ?: false);
		// The java arguments to execute:  Shared server, custom web configs

		// This is an array of tokens to send to the process builder
		var args = [];

		// "borrow" the CommandBox commandline parser to tokenize the JVM args. Not perfect, but close. Handles quoted values with spaces.
		var argTokens = parser.tokenizeInput( serverInfo.JVMargs )
			.map( function( i ){
				// Clean up a couple escapes the parser does that we don't need
				return parser.unwrapQuotes( i.replace( '\=', '=', 'all' ).replace( '\\', '\', 'all' ) )	;
			});
		// Add in heap size and java agent
		argTokens.append( '-Xmx#serverInfo.heapSize#m' );

		if( val( serverInfo.minHeapSize ) ) {
			if( serverInfo.minHeapSize > serverInfo.heapSize ) {
				consoleLogger.warn( 'Your JVM min heap size [#serverInfo.minHeapSize#] is set larger than your max size [#serverInfo.heapSize#]! Reducing the Min to prevent errors.' );
			}
			argTokens.append( '-Xms#min( serverInfo.minHeapSize, serverInfo.heapSize )#m' );
		}

		if( len( trim( javaAgent ) ) ) { argTokens.append( javaagent ); }

		 args
		 	.append( '-jar' ).append( variables.jarPath )
		 	.append( '--background=#background#' )
		 	.append( '--port' ).append( serverInfo.port )
		 	.append( '--host' ).append( serverInfo.host )
		 	.append( '--stop-port' ).append( serverInfo.stopsocket )
		 	.append( '--processname' ).append( processName )
		 	.append( '--log-dir' ).append( serverInfo.logDir )
		 	.append( '--open-browser' ).append( serverInfo.openbrowser )
		 	.append( '--open-url' ).append( serverInfo.openbrowserURL )
		 	.append( '--server-name' ).append( serverInfo.name )
		 	.append( '--tray-icon' ).append( serverInfo.trayIcon )
		 	.append( '--tray-config' ).append( trayOptionsPath )
		 	.append( '--tray-enable' ).append( serverInfo.trayEnable )
		 	.append( '--directoryindex' ).append( serverInfo.directoryBrowsing )
		 	.append( '--timeout' ).append( serverInfo.startTimeout )
		 	.append( '--proxy-peeraddress' ).append( 'true' )
		 	.append( serverInfo.runwarArgs.listToArray( ' ' ), true );

		 	if( serverInfo.debug ) {
		 		// Debug is getting turned on any time I include the --debug flag regardless of whether it's true or false.
		 		args.append( '--debug' ).append( serverInfo.debug );
		 	}

		// Runwar will blow up if there isn't a parameter supplied, so I can't pass an empty string.
		if( len( serverInfo.restMappings ) ) {
			args.append( '--servlet-rest-mappings' ).append( serverInfo.restMappings );
		} else {
			// This effectively disables it (assuming there's not a real directory or route called "___disabled___") but it's janky
			args.append( '--servlet-rest-mappings' ).append( '___DISABLED___' );
		}

		if( serverInfo.trace ) {
			args.append( '--log-level' ).append( 'TRACE' );
		}

		if( len( errorPages ) ) {
			args.append( '--error-pages' ).append( errorPages );
		}
	 	if( len( CFEngineName ) ) {
	 		 args.append( '--cfengine-name' ).append( CFEngineName );
	 	}
	 	if( len( serverInfo.welcomeFiles ) ) {
	 		 args.append( '--welcome-files' ).append( serverInfo.welcomeFiles );
	 	}
	 	if( len( CLIAliases ) ) {
	 		 args.append( '--dirs' ).append( CLIAliases );
	 	}


		// If background, wrap up JVM args to pass through to background servers.  "Real" JVM args must come before Runwar args
		if( background ) {
			var argString = argTokens.toList( ';' );
			if( len( argString ) ) {
				args.append( '--jvm-args=#trim( argString )#' );
			}
		// If foreground, just stick them in.
		} else {
			argTokens.each( function(i) { args.prepend( i ); } );
		}

		args.append( '-war' );

		// Starting a WAR
		if (serverInfo.WARPath != "" ) {
			args.append( serverInfo.WARPath );
		// Stand alone server
		} else {
			args.append( serverInfo.webroot );
		}

		// Custom web.xml (doesn't work right now)
		if ( Len( Trim( serverInfo.webXml ) ) && false ) {
			args.append( '--web-xml-path' ).append( serverInfo.webXml );
		// Default is in WAR home
		} else {
			args.append( '--web-xml-path' ).append( '#serverInfo.serverHomeDirectory#/WEB-INF/web.xml' );
		}

		if( len( serverInfo.libDirs ) ) {
			// Have to get rid of empty list elements
			args.append( '--lib-dirs' ).append( serverInfo.libDirs.listChangeDelims( ',', ',' ) );
		}

		// Incorporate SSL to command
		if( serverInfo.SSLEnable ){
			args
				.append( '--http-enable' ).append( serverInfo.HTTPEnable )
				.append( '--ssl-enable' ).append( serverInfo.SSLEnable )
				.append( '--ssl-port' ).append( serverInfo.SSLPort );
		}
		if( serverInfo.SSLEnable && serverInfo.SSLCertFile.len() ) {
			args
				.append( '--ssl-cert' ).append( serverInfo.SSLCertFile )
				.append( '--ssl-key' ).append( serverInfo.SSLKeyFile );
			// Not all certs require a password
			if( serverInfo.SSLKeyPass.len() ) {
				args.append( '--ssl-keypass' ).append( serverInfo.SSLKeyPass );
			}
		}

		// Incorporate rewrites to command
		args.append( '--urlrewrite-enable' ).append( serverInfo.rewritesEnable );
		if( len( serverInfo.rewritesStatusPath ) ) {
			args.append( '--urlrewrite-statuspath' ).append( serverInfo.rewritesStatusPath );
		}
		// A setting of 0 reloads on every request
		if( len( serverInfo.rewritesConfigReloadSeconds ) ) {
			args.append( '--urlrewrite-check' ).append( serverInfo.rewritesConfigReloadSeconds );
		}

		// Basic auth
		if( serverInfo.basicAuthEnable && serverInfo.basicAuthUsers.count() ) {
			// Escape commas and equals with backslash
			var sanitizeBA = function( i ) { return i.replace( ',', '\,', 'all' ).replace( '=', '\=', 'all' ); };
			var thisBasicAuthUsers = '';
			serverInfo.basicAuthUsers.each( function( i ) {
				thisBasicAuthUsers = thisBasicAuthUsers.listAppend( '#sanitizeBA( i )#=#sanitizeBA( serverInfo.basicAuthUsers[ i ] )#' );
			} );
			// user=pass,user2=pass2
			args.append( '--basicauth-users' ).append( thisBasicAuthUsers );
		}

		if( serverInfo.rewritesEnable ){
			if( !fileExists(serverInfo.rewritesConfig) ){
				consoleLogger.error( '.' );
				consoleLogger.error( 'URL rewrite config not found [#serverInfo.rewritesConfig#]' );
				consoleLogger.error( '.' );
				return;
			}
			args.append( '--urlrewrite-file' ).append( serverInfo.rewritesConfig );
		}
		// change status to starting + persist
		serverInfo.dateLastStarted = now();
		serverInfo.status = "starting";
		setServerInfo( serverInfo );

	    if( serverInfo.debug ) {
			var cleanedArgs = cr & '    ' & trim( reReplaceNoCase( args.toList( ' ' ), ' (-|"-)', cr & '    \1', 'all' ) );
			consoleLogger.debug("Server start command: #serverInfo.javaHome# #cleanedargs#");
	    }

	    // needs to be unique in each run to avoid errors
		var threadName = 'server#hash( serverInfo.webroot )##createUUID()#';
		// Construct a new process object
	    var processBuilder = createObject( "java", "java.lang.ProcessBuilder" );
	    // Pass array of tokens comprised of command plus arguments
	    args.prepend( serverInfo.javaHome );
	    processBuilder.init( args );
	    // Conjoin standard error and output for convenience.
	    processBuilder.redirectErrorStream( true );
	    // Kick off actual process
	    variables.process = processBuilder.start();

		// She'll be coming 'round the mountain when she comes...
		consoleLogger.warn( "The server for #serverInfo.webroot# is starting on #serverInfo.host#:#serverInfo.port#..." );

		// If the user is running a one-off command to start a server or specified the debug flag, stream the output and wait until it's finished starting.
		var interactiveStart = ( shell.getShellType() == 'command' || serverInfo.debug || !background );

		// Spin up a thread to capture the standard out and error from the server
		thread name="#threadName#" interactiveStart=interactiveStart serverInfo=serverInfo args=args startTimeout=serverInfo.startTimeout  {
			try{

				// save server info and persist
				serverInfo.statusInfo = { command:serverInfo.javaHome, arguments:attributes.args.toList( ' ' ), result:'' };
				serverInfo.status="starting";
				setServerInfo( serverInfo );

				var startOutput = createObject( 'java', 'java.lang.StringBuilder' ).init();
	    		var inputStream = process.getInputStream();
	    		var inputStreamReader = createObject( 'java', 'java.io.InputStreamReader' ).init( inputStream );
	    		var bufferedReader = createObject( 'java', 'java.io.BufferedReader' ).init( inputStreamReader );
				var print = wirebox.getInstance( "PrintBuffer" );

				var line = bufferedReader.readLine();
				while( !isNull( line ) ){
					// Clean log4j cruft from line
					line = reReplaceNoCase( line, '^.* (INFO|DEBUG|ERROR|WARN) RunwarLogger - processoutput: ', '' );
					line = reReplaceNoCase( line, '^.* (INFO|DEBUG|ERROR|WARN) RunwarLogger lib: ', 'Runwar: ' );
					line = reReplaceNoCase( line, '^.* (INFO|DEBUG|ERROR|WARN) RunwarLogger - ', 'Runwar: ' );

					// Build up our output
					startOutput.append( line & chr( 13 ) & chr( 10 ) );

					// output it if we're being interactive
					if( attributes.interactiveStart ) {
						print
							.line( line )
							.toConsole();
					}
					line = bufferedReader.readLine();
				} // End of inputStream

				// When we require Java 8 for CommandBox, we can pass a timeout to waitFor().
				var exitCode = process.waitFor();

				if( exitCode == 0 ) {
					serverInfo.status="running";
				} else {
					serverInfo.status="unknown";
				}

			} catch( any e ) {
				logger.error( e.message & ' ' & e.detail, e.stacktrace );
				serverInfo.status="unknown";
			} finally {
				// Make sure we always close the file or the process will never quit!
				if( isDefined( 'bufferedReader' ) ) {
					bufferedReader.close();
				}
				serverInfo.statusInfo.result = startOutput.toString();
				setServerInfo( serverInfo );
			}
		}

		// Block until the process ends and the streaming output thread above is done.
		if( interactiveStart ) {

			if( !background ) {
				try {

					while( true ) {
						// Wipe out prompt so it doesn't redraw if the user hits enter
						shell.getReader().setPrompt( '' );

						// Detect user pressing Ctrl-C
						// Any other characters captured will be ignored
						var line = shell.getReader().readLine();
						if( line == 'q' ) {
							break;
						} else {
							consoleLogger.error( 'To exit press Ctrl-C or "q" followed the enter key.' );
						}
					}

				// user wants to exit, they've pressed Ctrl-C
				} catch ( jline.console.UserInterruptException e ) {
				// Something bad happened
				} catch ( Any e ) {
					logger.error( '#e.message# #e.detail#' , e.stackTrace );
					consoleLogger.error( '#e.message##chr(10)##e.detail#' );
				// Either way, this server is done like dinner
				} finally {
					consoleLogger.error( 'Stopping server...' );
					shell.setPrompt();
					process.destroy();
				}
			}

			thread action="join" name="#threadName#";
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
	* - defaultwebroot
	* - defaultServerConfigFile
	* - serverJSON
	* - serverInfo
	* - serverIsNew
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

				// Don't overlap an existing server name
				var originalName = defaultName;
				var nameCounter = 1;
				while( structCount( getServerInfoByName( defaultName ) ) ) {
					defaultName = originalName & ++nameCounter;
				}

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
	function forget( required struct serverInfo ){
		var servers 	= getServers();
		var serverdir 	= getCustomServerFolder( arguments.serverInfo );

		interceptorService.announceInterception( 'preServerForget', { serverInfo=serverInfo } );

		// Catch this to gracefully handle where the OS or another program
		// has the folder locked.
		try {

			// try to delete interal server dir server
			if( directoryExists( serverDir ) ){
				directoryDelete( serverdir, true );
			}

			// Server home may be custom, so delete it as well
			if( len( serverInfo.serverHomeDirectory ) && directoryExists( serverInfo.serverHomeDirectory ) ){
				directoryDelete( serverInfo.serverHomeDirectory, true );
			}


		} catch( any e ) {
			consoleLogger.error( '#e.message##chr(10)#Did you leave the server running? ' );
			logger.error( '#e.message# #e.detail#' , e.stackTrace );
			return serverInfo.name & ' not deleted.';
		}

		// Remove from config
		structDelete( servers, arguments.serverInfo.id );
		setServers( servers );

		interceptorService.announceInterception( 'postServerForget', { serverInfo=serverInfo } );

		// return message
		return "Poof! Wiped out server " & serverInfo.name;
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
		} catch( java.net.UnknownHostException var e ) {
			// In this case, the host name doesn't exist, so we really don't know about the port, but we'll say it's available
			// otherwise, old, stopped servers who's host entries no longer exist will show up as running.
			return true;
		} catch( java.net.BindException var e ) {
			// Same as above-- the IP address/host isn't bound to any local adapters.  Probably a host file entry went missing.
			if( e.message contains 'Cannot assign requested address' ) {
				return true;
			}
			// We're assuming that any other error means the address was in use.
			// Java doesn't provide a specific message or exception type for this unfortunately.
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
		var normalizedWebroot = normalizeWebroot( arguments.serverInfo.webroot );
		var webrootHash = hash( normalizedWebroot & ucase( arguments.serverInfo.name ) );
		arguments.serverInfo.id = webrootHash;

		if( arguments.serverInfo.webroot == "" ){
			throw( "The webroot cannot be empty!" );
		}
		servers[ webrootHash ] = serverInfo;
		// persist back safely

		setServers( servers );

	}

	function normalizeWebroot( required string webroot ) {
		if( webroot contains '/' && !webroot.endsWith( '/' ) ) {
			return webroot & '/';
		}
		if( webroot contains '\' && !webroot.endsWith( '\' ) ) {
			return webroot & '\';
		}
		return webroot;
	}

	/**
	 * Create initial server JSON
 	 **/
	function initServers(){
		lock name="serverservice.serverconfig" type="exclusive" throwOnTimeout="true" timeout="10"{
			fileWrite( serverConfig, '{}' );
		}
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
				var serverKeys = results.keyArray();

				// Loop over each server for some housekeeping
				for( var thisKey in serverKeys ){
					// This server may have gotten deleted already based on the cleanup below.
					if( !results.keyExists( thisKey ) ) {
						continue;
					}
					var thisServer = results[ thisKey ];
					// Backwards compat-- add in server id if it doesn't exist for older versions of CommandBox
					if( isNull( thisServer.id ) ){
						var normalizedWebroot = normalizeWebroot( thisServer.webroot );
						thisServer.id = hash( normalizedWebroot & ucase( thisServer.name ) );
						updateRequired = true;
					}

					// Try and clean up orphaned server names that were missing the slash on the path and
					// ended up with a different hash.
					// I really have no idea how this happens. I can't repro it on-demand.
					for( var orphanKey in results ){
						var orphan = results[ orphanKey ];
						// If this is another server with the same name and the same webroot but without a trailing slash...
						if( orphan.id != thisServer.id
							&& orphan.name == thisServer.name
							&& ( thisServer.webroot.endsWith( '\' ) || thisServer.webroot.endsWith( '/' ) )
							&& ( !orphan.webroot.endsWith( '\' ) || !orphan.webroot.endsWith( '/' ) )
							&& ( orphan.webroot & '\' == thisServer.webroot || orphan.webroot & '/' == thisServer.webroot ) ) {
								// ...kill it dead.
								results.delete( orphanKey );
								updateRequired = true;
							}
					}

					// Future-proof server info by guaranteeing that all properties will exist in the
					// server object as long as they are defined in the newServerInfoStruct() method.
					thisServer.append( newServerInfoStruct(), false );
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
	* Get server info for webroot
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

			// Don't overlap an existing server name
			var originalName = serverInfo.name;
			var nameCounter = 1;
			while( structCount( getServerInfoByName( serverInfo.name ) ) ) {
				serverInfo.name = originalName & ++nameCounter;
			}

			// Store it in server struct
			servers[ webrootHash ] = serverInfo;
		}

		// Return the new record
		return servers[ webrootHash ];
	}

	/**
	* Returns a new server info structure
	*/
	struct function newServerInfoStruct(){
		return {
			'id' 				: "",
			'port'				: 0,
			'host'				: "127.0.0.1",
			'stopSocket'		: 0,
			'debug'				: false,
			'status'			: "stopped",
			'statusInfo'		: {
				'result' 	: "",
				'arguments' : "",
				'command' 	: ""
			},
			'name'				: "",
			'logDir' 			: "",
			'consolelogPath'	: "",
			'trayicon' 			: "",
			'libDirs' 			: "",
			'webConfigDir' 		: "",
			'serverConfigDir' 	: "",
			'serverHomeDirectory' : "",
			'webroot'			: "",
			'webXML' 			: "",
			'HTTPEnable'		: true,
			'SSLEnable'			: false,
			'SSLPort'			: 1443,
			'SSLCertFile'		: "",
			'SSLKeyFile'		: "",
			'SSLKeyPass'		: "",
			'rewritesEnable'	: false,
			'rewritesConfig'	: "",
			'basicAuthEnable'	: true,
			'basicAuthUsers'	: {},
			'heapSize'			: 512,
			'minHeapSize'		: 0,
			'javaHome'			: '',
			'directoryBrowsing' : true,
			'JVMargs'			: "",
			'runwarArgs'		: "",
			'cfengine'			: "",
			'restMappings'		: "",
			'engineName'		: "",
			'engineVersion'		: "",
			'WARPath'			: "",
			'serverConfigFile'	: "",
			'aliases'			: {},
			'errorPages'		: {},
			'trayOptions'		: {},
			'trayEnable'		: true,
			'dateLastStarted'	: '',
			'openBrowser'		: true,
			'openBrowserURL'	: ''
		};
	}

	/**
	* Read a server.json file.  If it doesn't exist, returns an empty struct
	* This only returns properties specifically set in the file.
	*/
	struct function readServerJSON( required string path ) {
		if( fileExists( path ) ) {
			var fileContents = fileRead( path );
			if( isJSON( fileContents ) ) {
				return deserializeJSON( fileContents );
			} else {
				consoleLogger.warn( 'Warning: File is not valid JSON. [#path#]' );
				return {};
			}
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
	    	directoryCreate( getDirectoryFromPath( arguments.configFilePath ), true, true );
			fileWrite( arguments.configFilePath, newJSON );
		}
	}

	/**
	* Dynamic completion for property name based on contents of server.json
	* @directory web root
	* @all Pass false to ONLY suggest existing setting names.  True will suggest all possible settings.
	* @asSet Pass true to add = to the end of the options
	*/
	function completeProperty( required directory,  all=false, asSet=false ) {
		// Get all config settings currently set
		var props = JSONService.addProp( [], '', '', readServerJSON( arguments.directory & '/server.json' ) );

		// If we want all possible options...
		if( arguments.all ) {
			// ... Then add them in
			props = JSONService.addProp( props, '', '', getDefaultServerJSON() );
			// Suggest a couple optional web error pages
			props = JSONService.addProp( props, '', '', {
				'web' : {
					'errorPages' : {
						'404' : '',
						'500' : '',
						'default' : ''
					}
				}
			} );
		}
		if( asSet ) {
			props = props.map( function( i ){ return i &= '='; } );
		}

		return props;
	}
}
