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
	property name='javaService'				inject='provider:javaService';
	property name='ansiFormater'			inject='AnsiFormater';
	property name="printUtil"				inject="print";

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

		variables.system = createObject( 'java', 'java.lang.System' );

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
			'verbose' : d.verbose ?: false,
			'trace' : d.trace ?: false,
			'console' : d.console ?: false,
			'trayicon' : d.trayicon ?: '',
			// Duplicate so onServerStart interceptors don't actually change config settings via reference.
			'trayOptions' : duplicate( d.trayOptions ?: [] ),
			'trayEnable' : d.trayEnable ?: true,
			'dockEnable' : d.dockEnable ?: true,
			'profile'	: d.profile ?: '',
			'jvm' : {
				'heapSize' : d.jvm.heapSize ?: '',
				'minHeapSize' : d.jvm.minHeapSize ?: '',
				'args' : d.jvm.args ?: '',
				'javaHome' : d.jvm.javaHome ?: '',
				'javaVersion' : d.jvm.javaVersion ?: ''
			},
			'web' : {
				'host' : d.web.host ?: '127.0.0.1',
				'directoryBrowsing' : d.web.directoryBrowsing ?: '',
				'webroot' : d.web.webroot ?: '',
				// Duplicate so onServerStart interceptors don't actually change config settings via reference.
				'aliases' : duplicate( d.web.aliases ?: {} ),
				// Duplicate so onServerStart interceptors don't actually change config settings via reference.
				'errorPages' : duplicate( d.web.errorPages ?: {} ),
				'accessLogEnable' : d.web.accessLogEnable ?: false,
				'GZIPEnable' : d.web.GZIPEnable ?: true,
				'gzipPredicate' : d.web.gzipPredicate ?: '',
				'welcomeFiles' : d.web.welcomeFiles ?: '',
				'maxRequests' : d.web.maxRequests ?: '',
				'HTTP' : {
					'port' : d.web.http.port ?: 0,
					'enable' : d.web.http.enable ?: true
				},
				'SSL' : {
					'enable' : d.web.ssl.enable ?: false,
					'port' : d.web.ssl.port ?: 1443,
					'certFile' : d.web.ssl.certFile ?: '',
					'keyFile' : d.web.ssl.keyFile ?: '',
					'keyPass' : d.web.ssl.keyPass ?: ''
				},
				'AJP' : {
					'enable' : d.web.ajp.enable ?: false,
					'port' : d.web.ajp.port ?: 8009
				},
				'rewrites' : {
					'enable' : d.web.rewrites.enable ?: false,
					'logEnable' : d.web.rewrites.logEnable ?: false,
					'config' : d.web.rewrites.config ?: variables.rewritesDefaultConfig,
					'statusPath' : d.web.rewrites.statusPath ?: '',
					'configReloadSeconds' : d.web.rewrites.configReloadSeconds ?: ''
				},
				'basicAuth' : {
					'enable' : d.web.basicAuth.enable ?: true,
					'users' : d.web.basicAuth.users ?: {}
				},
				'rules' : duplicate( d.web.rules ?: [] ),
				'rulesFile' : duplicate( d.web.rulesFile ?: [] ),
				'blockCFAdmin' : d.web.blockCFAdmin ?: '',
				'blockSensitivePaths' :  d.web.blockSensitivePaths ?: '',
				'blockFlashRemoting' :  d.web.blockFlashRemoting ?: '',
				'allowedExt' : d.web.allowedExt ?: ''
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
				'serverHomeDirectory' : d.app.serverHomeDirectory ?: '',
				'sessionCookieSecure' : d.app.sessionCookieSecure ?: false,
				'sessionCookieHTTPOnly' : d.app.sessionCookieHTTPOnly ?: false
			},
			'runwar' : {
				'jarPath' : d.runwar.jarPath ?: variables.jarPath,
				'args' : d.runwar.args ?: '',
				// Duplicate so onServerStart interceptors don't actually change config settings via reference.
				'XNIOOptions' : duplicate( d.runwar.XNIOOptions ?: {} ),
				// Duplicate so onServerStart interceptors don't actually change config settings via reference.
				'undertowOptions' : duplicate( d.runwar.undertowOptions ?: {} )
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

		var job = wirebox.getInstance( 'interactiveJob' );
		job.start( 'Starting Server', 10 );

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
		if( !isNull( serverProps.javaHomeDirectory ) ) {
			serverProps.javaHomeDirectory = fileSystemUtil.resolvePath( serverProps.javaHomeDirectory );
		}
		if( !isNull( serverProps.runwarJarPath ) ) {
			serverProps.runwarJarPath = fileSystemUtil.resolvePath( serverProps.runwarJarPath );
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
		if( isServerRunning( serverInfo ) && !(serverProps.force ?: false ) && !(serverProps.dryRun ?: false ) ) {
			job.addErrorLog( 'Server "#serverInfo.name#" (#serverInfo.webroot#) is already running @ #serverInfo.openbrowserURL#!' );
			job.addErrorLog( 'Overwriting a running server means you won''t be able to use the "stop" command to stop the original one.' );
			job.addWarnLog( 'Use the --force parameter to skip this check.' );
			// Ask the user what they want to do
			var action = wirebox.getInstance( 'multiselect' )
				.setQuestion( 'What would you like to do? ' )
				.setOptions( [
					{ display : 'Provide a new name for this server (recommended)', value : 'newName', accessKey='N', selected=true },
					{ display : 'Open currently running server in browser @ #serverInfo.openbrowserURL#', value : 'openinbrowser', accessKey='B'},
					{ display : 'Just keep starting this new server and overwrite the old, running one.', value : 'overwrite', accessKey='o' },
					{ display : 'Cancel and do not start a server right now.', value : 'stop', accessKey='s' }
				] )
				.setRequired( true )
				.ask();

			if( action == 'stop' ) {
				job.error( 'Aborting...' );
				return;
			} else if( action == 'openinbrowser' ) {
				job.addLog( "Opening...#serverInfo.openbrowserURL#" );
				shell.callCommand( 'browse #serverInfo.openbrowserURL#', false);
				return;
			} else if( action == 'newname' ) {
				job.clear();
				// Collect a new name
				var newName = shell.ask( 'Provide a new unique "name" for this server: ' );
				job.draw();
				// If a name is provided, start over.  Otherwise, just keep starting.
				// The recursive call here will subject their answer to the same check until they provide a name that hasn't been used for this folder.
				if( len( newName ) ) {
					job.error( 'Server name [#serverInfo.name#] in use, trying a new one.' );
					serverProps.name = newName;
					var newServerJSONFile = fileSystemUtil.resolvePath( serverProps.directory ?: '' ) & "/server-#serverProps.name#.json";
					// copy the orig server's server.json file to the new file so it starts with the same properties as the original. lots of alternative ways to do this but the file copy works and is simple
					if( fileExists( defaultServerConfigFile ) && newServerJSONFile != defaultServerConfigFile ) {
						file action='copy' source="#defaultServerConfigFile#" destination="#newServerJSONFile#" mode ='777';
					}
					return start( serverProps );
				}

			} else {
				job.addWarnLog( 'Overwriting previous server [#serverInfo.name#].' );
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
			if( isNull( serverProps[ prop ] ) || listFindNoCase( 'saveSettings,serverConfigFile,debug,verbose,force,console,trace,startScript,startScriptFile,dryRun', prop ) ) {
				continue;
			}
	    	var configPath = replace( fileSystemUtil.resolvePath( defaultServerConfigFileDirectory ), '\', '/', 'all' );
	    	// Ensure trailing slash
	    	if( !configPath.endsWith( '/' ) ) {
	    		configPath &= '/';
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
			    	// This path is canonical already.
			    	var thisDirectory = replace( serverProps[ 'directory' ], '\', '/', 'all' ) & '/';
			    	// If the web root is south of the server's JSON, make it relative for better portability.
			    	if( thisDirectory contains configPath ) {
			    		thisDirectory = replaceNoCase( thisDirectory, configPath, '' );
			    	}
					serverJSON[ 'web' ][ 'webroot' ] = thisDirectory;
			         break;
			    case "trayEnable":
					serverJSON[ 'trayEnable' ] = serverProps[ prop ];
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
			    case "AJPEnable":
					serverJSON[ 'web' ][ 'AJP' ][ 'enable' ] = serverProps[ prop ];
			         break;
			    case "AJPPort":
					serverJSON[ 'web' ][ 'AJP' ][ 'port' ] = serverProps[ prop ];
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
			    case "blockCFAdmin":
					serverJSON[ 'web' ][ 'blockCFAdmin' ] = serverProps[ prop ];
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
			    case "javaVersion":
					serverJSON[ 'JVM' ][ 'javaVersion' ] = serverProps[ prop ];
			         break;
				case "runwarJarPath":
					serverJSON[ 'runwar' ][ 'jarPath' ] = serverProps[ prop ];
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
		// Mix in environment variable overrides like BOX_SERVER_PROFILE
		loadOverrides( serverJSON, serverInfo );

		// Setup serverinfo according to params
		// Hand-entered values take precedence, then settings saved in server.json, and finally defaults.
		// The big servers.json is only used to keep a record of the last values the server was started with
		serverInfo.trace 			= serverProps.trace 			?: serverJSON.trace 				?: defaults.trace;
		serverInfo.debug 			= serverProps.debug 			?: serverJSON.debug 				?: defaults.debug;
		serverInfo.verbose 			= serverProps.verbose 			?: serverJSON.verbose 				?: defaults.verbose;
		serverInfo.console 			= serverProps.console 			?: serverJSON.console 				?: defaults.console;
		serverInfo.openbrowser		= serverProps.openbrowser 		?: serverJSON.openbrowser			?: defaults.openbrowser;

		serverInfo.openbrowserURL	= serverProps.openbrowserURL	?: serverJSON.openbrowserURL		?: defaults.openbrowserURL;

		// Trace assumes debug
		serverInfo.debug = serverInfo.trace || serverInfo.debug;
		// Debug assumes verbose
		serverInfo.verbose = serverInfo.debug || serverInfo.verbose;

		if( serverInfo.verbose ) {
			job.setDumpLog( serverInfo.verbose );
		}

		serverInfo.host				= serverProps.host 				?: serverJSON.web.host				?: defaults.web.host;
		// If the last port we used is taken, remove it from consideration.
		if( serverInfo.port == 0 || !isPortAvailable( serverInfo.host, serverInfo.port ) ) { serverInfo.delete( 'port' ); }
		// Port is the only setting that automatically carries over without being specified since it's random.
		serverInfo.port 			= serverProps.port 				?: serverJSON.web.http.port			?: serverInfo.port	?: defaults.web.http.port;
		// Server default is 0 not null.
		if( serverInfo.port == 0 ) {
			serverInfo.port = getRandomPort( serverInfo.host );
		}

		var profileReason = 'config setting server defaults';
		// Try to set a smart profile if there's not one set
		if( !trim( defaults.profile ).len() ) {
			var thisIP = '';
			// Try and get the IP we're binding to
			try{
				thisIP = java.InetAddress.getByName( serverInfo.host ).getHostAddress();
			} catch( any var e ) {}

			// Look for a env var called "environment"
			var envVarEnvironment = systemSettings.getSystemSetting( 'environment', '' );

			// Env var takes precedence.
			if( len( envVarEnvironment ) ) {
				profileReason = '"environment" env var';
				defaults.profile = envVarEnvironment;
			// Otherwise see if we're bound to localhost.
			} else if( listFirst( thisIP, '.' ) == '127' ) {
				profileReason = 'server bound to localhost';
				defaults.profile = 'development';
			} else {
				profileReason = 'secure by default';
				defaults.profile = 'production';
			}
		}

		if( !isNull( serverJSON.profile ) ) {
			if( serverInfo.envVarHasProfile ?: false ) {
				profileReason = 'profile property in in "box_server_profile" env var';
			} else {
				profileReason = 'profile property in server.json';	
			}
		}
		if( !isNull( serverProps.profile ) ) {
			profileReason = 'profile argument to server start command';
		}
		serverInfo.profile			= serverProps.profile	 		?: serverJSON.profile				?: defaults.profile;

		if( !trim( defaults.web.blockCFAdmin ).len() ) {
			if( serverInfo.profile == 'development' || serverInfo.profile == 'none' ) {
				defaults.web.blockCFAdmin = 'false';
			} else {
				defaults.web.blockCFAdmin = 'external';
			}
		}

		if( !trim( defaults.web.blockSensitivePaths ).len() ) {
			if( serverInfo.profile == 'none' ) {
				defaults.web.blockSensitivePaths = false;
			} else {
				defaults.web.blockSensitivePaths = true;
			}
		}

		if( !trim( defaults.web.blockFlashRemoting ).len() ) {
			if( serverInfo.profile == 'none' ) {
				defaults.web.blockFlashRemoting = false;
			} else {
				defaults.web.blockFlashRemoting = true;
			}
		}

		serverInfo.blockCFAdmin		= serverProps.blockCFAdmin			?: serverJSON.web.blockCFAdmin		?: defaults.web.blockCFAdmin;
		serverInfo.blockSensitivePaths									 = serverJSON.web.blockSensitivePaths	?: defaults.web.blockSensitivePaths;
		serverInfo.blockFlashRemoting									 = serverJSON.web.blockFlashRemoting	?: defaults.web.blockFlashRemoting;
		serverInfo.allowedExt											 = serverJSON.web.allowedExt		?: defaults.web.allowedExt;

		// If there isn't a default for this already
		if( !isBoolean( defaults.web.directoryBrowsing ) ) {
			// Default it according to the profile
			if( serverInfo.profile == 'development' ) {
				defaults.web.directoryBrowsing = true;
			} else {
				// secure by default even if profile is none or custom
				defaults.web.directoryBrowsing = false;
			}
		}
		serverInfo.directoryBrowsing = serverProps.directoryBrowsing ?: serverJSON.web.directoryBrowsing ?: defaults.web.directoryBrowsing;

		job.start( 'Setting Server Profile to [#serverInfo.profile#]' );
			job.addLog( 'Profile set from #profileReason#' );
			if( serverInfo.blockCFAdmin == 'external' ) {
				job.addSuccessLog( 'Block CF Admin external' );
			} else if( serverInfo.blockCFAdmin == 'true' ) {
				job.addSuccessLog( 'Block CF Admin enabled' );
			} else {
				job.addErrorLog( 'Block CF Admin disabled' );
			}
			job[ 'add#( serverInfo.blockSensitivePaths ? 'Success' : 'Error' )#Log' ]( 'Block Sensitive Paths #( serverInfo.blockSensitivePaths ? 'en' : 'dis' )#abled' );
			job[ 'add#( serverInfo.blockFlashRemoting ? 'Success' : 'Error' )#Log' ]( 'Block Flash Remoting #( serverInfo.blockFlashRemoting ? 'en' : 'dis' )#abled' );
			if( len( serverInfo.allowedExt ) ) {
				job.addLog( 'Allowed Extensions: [#serverInfo.allowedExt#]' );
			}
			job[ 'add#( !serverInfo.directoryBrowsing ? 'Success' : 'Error' )#Log' ]( 'Directory Browsing #( serverInfo.directoryBrowsing ? 'en' : 'dis' )#abled' );
		job.complete( serverInfo.verbose );

		// Double check that the port in the user params or server.json isn't in use
		if( !isPortAvailable( serverInfo.host, serverInfo.port ) ) {
			job.addErrorLog( "" );
			var badPortlocation = 'config';
			if( serverProps.keyExists( 'port' ) ) {
				badPortlocation = 'start params';
			} else if ( len( defaults.web.http.port ?: '' ) ) {
				badPortlocation = 'server.json';
			} else {
				badPortlocation = 'config server defaults';
			}
			throw( message="You asked for port [#( serverProps.port ?: serverJSON.web.http.port ?: defaults.web.http.port ?: '?' )#] in your #badPortlocation# but it's already in use.", detail="Please choose another or use netstat to find out what process is using the port already.", type="commandException" );
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

		serverInfo.AJPEnable 		= serverProps.AJPEnable 		?: serverJSON.web.AJP.enable			?: defaults.web.AJP.enable;
		serverInfo.AJPPort			= serverProps.AJPPort 			?: serverJSON.web.AJP.port				?: defaults.web.AJP.port;

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
		serverInfo.maxRequests		= 								   serverJSON.web.maxRequests			?: defaults.web.maxRequests;

		serverInfo.trayEnable	 	= serverProps.trayEnable		?: serverJSON.trayEnable			?: defaults.trayEnable;
		serverInfo.dockEnable	 	= serverJSON.dockEnable			?: defaults.dockEnable;
		serverInfo.defaultBaseURL = serverInfo.SSLEnable ? 'https://#serverInfo.host#:#serverInfo.SSLPort#' : 'http://#serverInfo.host#:#serverInfo.port#';

		// If there's no open URL, let's create a complete one
		if( !serverInfo.openbrowserURL.len() ) {
			serverInfo.openbrowserURL = serverInfo.defaultBaseURL;
		// Partial URL like /admin/login.cm
		} else if ( left( serverInfo.openbrowserURL, 4 ) != 'http' ) {
			if( !serverInfo.openbrowserURL.startsWith( '/' ) ) {
				serverInfo.openbrowserURL = '/' & serverInfo.openbrowserURL;
			}
			serverInfo.openbrowserURL = serverInfo.defaultBaseURL & serverInfo.openbrowserURL;
		}

		// Clean up spaces in welcome file list
		serverInfo.welcomeFiles = serverInfo.welcomeFiles.listMap( function( i ){ return trim( i ); } );


		// relative rewrite config path in server.json is resolved relative to the server.json
		if( isDefined( 'serverJSON.web.rewrites.config' ) ) { serverJSON.web.rewrites.config = fileSystemUtil.resolvePath( serverJSON.web.rewrites.config, defaultServerConfigFileDirectory ); }
		// relative rewrite config path in config setting server defaults is resolved relative to the web root
		if( isDefined( 'defaults.web.rewrites.config' ) ) { defaults.web.rewrites.config = fileSystemUtil.resolvePath( defaults.web.rewrites.config, defaultwebroot ); }
		serverInfo.rewritesConfig 	= serverProps.rewritesConfig 	?: serverJSON.web.rewrites.config 	?: defaults.web.rewrites.config;

		serverInfo.heapSize 		= serverProps.heapSize 			?: serverJSON.JVM.heapSize			?: defaults.JVM.heapSize;
		serverInfo.minHeapSize 		= serverProps.minHeapSize		?: serverJSON.JVM.minHeapSize		?: defaults.JVM.minHeapSize;

		serverInfo.javaVersion = '';
		serverInfo.javaHome = '';

		// First, take start command home dir
		if( isDefined( 'serverProps.javaHomeDirectory' ) ) {
			serverInfo.javaHome = serverProps.javaHomeDirectory;
		// Then start command java version
		} else if( isDefined( 'serverProps.javaVersion' ) ) {
			serverInfo.javaVersion = serverProps.javaVersion;
		// Then server.json java home dir
		} else if( isDefined( 'serverJSON.JVM.javaHome' ) ) {
			serverInfo.javaHome = fileSystemUtil.resolvePath( serverJSON.JVM.javaHome, defaultServerConfigFileDirectory );
		// Then server.json java version
		} else if( isDefined( 'serverJSON.JVM.javaVersion' ) ) {
			serverInfo.javaVersion = serverJSON.JVM.javaVersion;
		// Then server defaults java home dir
		} else if( defaults.JVM.javaHome.len() ) {
			serverInfo.javaHome = fileSystemUtil.resolvePath( defaults.JVM.javaHome, defaultwebroot );
		// Then server defaults java versiom
		} else if( defaults.JVM.javaVersion.len() ) {
			serverInfo.javaVersion = defaults.JVM.javaVersion;
		}

		// There was no java home at any level, but there was a java version, use it
		if( !serverInfo.javaHome.len() && serverInfo.javaVersion.len() ) {
			serverInfo.javaHome = javaService.getJavaInstallPath( serverInfo.javaVersion );
		}

		// There is still no java home, use the same JRE as the CLI
		if( serverInfo.javaHome.len() ) {
			serverInfo.javaHome = fileSystemUtil.getJREExecutable( serverInfo.javaHome );
		} else {
			serverInfo.javaHome = variables.javaCommand;
		}

		// Global aliases are always added on top of server.json (but don't overwrite)
		// Aliases aren't accepted via command params due to no clean way to provide them
		serverInfo.aliases 			= defaults.web.aliases;
		serverInfo.aliases.append( serverJSON.web.aliases ?: {} );

		// Global errorPages are always added on top of server.json (but don't overwrite the full struct)
		// Aliases aren't accepted via command params
		serverInfo.errorPages		= defaults.web.errorPages;
		serverInfo.errorPages.append( serverJSON.web.errorPages ?: {} );

		serverInfo.accessLogEnable	= serverJSON.web.accessLogEnable	?: defaults.web.accessLogEnable;
		serverInfo.GZIPEnable		= serverJSON.web.GZIPEnable 		?: defaults.web.GZIPEnable;
		serverInfo.gzipPredicate	= serverJSON.web.gzipPredicate		?: defaults.web.gzipPredicate;

		serverInfo.rewriteslogEnable = serverJSON.web.rewrites.logEnable ?: defaults.web.rewrites.logEnable;

		// Global defaults are always added on top of whatever is specified by the user or server.json
		serverInfo.JVMargs			= ( serverProps.JVMargs			?: serverJSON.JVM.args ?: '' ) & ' ' & defaults.JVM.args;

		// Global defaults are always added on top of whatever is specified by the user or server.json
		serverInfo.runwarJarPath	= serverProps.runwarJarPath		?: serverJSON.runwar.jarPath	?: defaults.runwar.jarPath;

		// Global defaults are always added on top of whatever is specified by the user or server.json
		serverInfo.runwarArgs		= ( serverProps.runwarArgs		?: serverJSON.runwar.args ?: '' ) & ' ' & defaults.runwar.args;

		// Global defaults are always added on top of whatever is specified by the user or server.json
		serverInfo.runwarXNIOOptions	= ( serverJSON.runwar.XNIOOptions ?: {} ).append( defaults.runwar.XNIOOptions, true );

		// Global defaults are always added on top of whatever is specified by the user or server.json
		serverInfo.runwarUndertowOptions	= ( serverJSON.runwar.UndertowOptions ?: {} ).append( defaults.runwar.UndertowOptions, true );

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
				} else if( serverInfo.verbose ) {
					job.addLog( "Ignoring non-existent global lib dir: " & thisLibDir );
				}
				return thisLibDirs;
			}, '' );
		}
		// Global defaults are always added on top of whatever is specified by the user or server.json
		serverInfo.libDirs		= ( serverProps.libDirs		?: serverJSON.app.libDirs ?: '' ).listAppend( defaults.app.libDirs );

		serverInfo.webRules = [];
		if( serverJSON.keyExists( 'web' ) && serverJSON.web.keyExists( 'rules' ) ) {
			if( !isArray( serverJSON.web.rules ) ) {
				throw( message="'rules' key in your box.json must be an array of strings.", type="commandException" );
			}
			serverInfo.webRules.append( serverJSON.web.rules, true);
		}
		if( serverJSON.keyExists( 'web' ) && serverJSON.web.keyExists( 'rulesFile' ) ) {
			if( isSimpleValue( serverJSON.web.rulesFile ) ) {
				serverJSON.web.rulesFile = serverJSON.web.rulesFile.listToArray();
			}
			serverInfo.webRules.append( serverJSON.web.rulesFile.map((fg)=>{
				fg = fileSystemUtil.resolvePath( fg, defaultServerConfigFileDirectory );
				return wirebox.getInstance( 'Globber' ).setPattern( fg ).matches().reduce( (predicates,file)=>{
						if( lCase( file ).endsWith( '.json' ) ) {
							return predicates & CR & deserializeJSON( fileRead( file ) ).toList( CR )
						} else {
							return predicates & CR & fileRead( file )
						}
					}, '' );
			}), true);
		}
		if( defaults.keyExists( 'web' ) && defaults.web.keyExists( 'rules' ) ) {
			serverInfo.webRules.append( defaults.web.rules, true);
		}

		if( defaults.keyExists( 'web' ) && defaults.web.keyExists( 'rulesFile' ) ) {
			var defaultsRulesFile = defaults.web.rulesFile;
			if( isSimpleValue( defaultsRulesFile ) ) {
				defaultsRulesFile = defaultsRulesFile.listToArray();
			}
			serverInfo.webRules.append( defaultsRulesFile.map((fg)=>{
				fg = fileSystemUtil.resolvePath( fg, defaultwebroot );
				return wirebox.getInstance( 'Globber' ).setPattern( fg ).matches().reduce( (predicates,file)=>{
						if( lCase( file ).endsWith( '.json' ) ) {
							return predicates & CR & deserializeJSON( fileRead( file ) ).toList( CR )
						} else {
							return predicates & CR & fileRead( file )
						}
					}, '' );
			}), true);
		}

		// Default CommandBox rules.
		if( serverInfo.blockSensitivePaths ) {
			serverInfo.webRules.append( [
				// track and trace verbs can leak data in XSS attacks
				"disallowed-methods( methods={trace,track} )",
				// Common config files and sensitive paths that should never be accessed, even on development
				"regex( pattern='.*/(box.json|server.json|web.config|urlrewrite.xml|package.json|package-lock.json|Gulpfile.js)', case-sensitive=false ) -> { set-error(404); done }",
				// Any file or folder starting with a period
				"regex('/\.') -> { set-error( 404 ); done }",
				// Additional serlvlet mappings in Adobe CF's web.xml
				"path-prefix( { '/JSDebugServlet','/securityanalyzer','/WSRPProducer' } ) -> { set-error( 404 ); done }",
				// java web service (Axis) files
				"regex( pattern='\.jws$', case-sensitive=false ) -> { set-error( 404 ); done }"
			], true );

			if( serverInfo.profile == 'production' ) {
				serverInfo.webRules.append( [
					// Common config files and sensitive paths in ACF and TestBox that may be ok for dev, but not for production
					"regex( pattern='.*/(CFIDE/multiservermonitor-access-policy.xml|CFIDE/probe.cfm|CFIDE/main/ide.cfm|tests/runner.cfm|testbox/system/runners/HTMLRunner.cfm)', case-sensitive=false ) -> { set-error(404); done }",
				], true );
			}

		}

		if( serverInfo.blockFlashRemoting ) {
			serverInfo.webRules.append( [
				// These all map to web.xml servlet mappings for ACF
				"path-prefix( { '/flex2gateway','/flex-internal','/flashservices/gateway','/cfform-internal','/CFFormGateway', '/openamf/gateway', '/messagebroker' } ) -> { set-error( 404 ); done }",
				// Files used for flash remoting
				"regex( pattern='\.(mxml|cfswf)$', case-sensitive=false ) -> { set-error( 404 ); done }"
			], true );
		}

		// Administrators
		if( serverInfo.blockCFAdmin == 'external' ) {
			serverInfo.webRules.append(
				"cf-admin() -> block-external()"
			 );
		} else if( serverInfo.blockCFAdmin == 'true' ) {
			serverInfo.webRules.append(
				"block-cf-admin()"
			 );
		}

		serverInfo.cfengine			= serverProps.cfengine			?: serverJSON.app.cfengine			?: defaults.app.cfengine;

		serverInfo.restMappings		= serverProps.restMappings		?: serverJSON.app.restMappings		?: defaults.app.restMappings;
		// relative rewrite config path in server.json is resolved relative to the server.json
		if( isDefined( 'serverJSON.app.WARPath' ) ) { serverJSON.app.WARPath = fileSystemUtil.resolvePath( serverJSON.app.WARPath, defaultServerConfigFileDirectory ); }
		if( isDefined( 'defaults.app.WARPath' ) && len( defaults.app.WARPath )  ) { defaults.app.WARPath = fileSystemUtil.resolvePath( defaults.app.WARPath, defaultwebroot ); }
		serverInfo.WARPath			= serverProps.WARPath			?: serverJSON.app.WARPath			?: defaults.app.WARPath;

		// relative rewrite config path in server.json is resolved relative to the server.json
		if( isDefined( 'serverJSON.app.serverHomeDirectory' ) && len( serverJSON.app.serverHomeDirectory ) ) { serverJSON.app.serverHomeDirectory = fileSystemUtil.resolvePath( serverJSON.app.serverHomeDirectory, defaultServerConfigFileDirectory ); }
		if( isDefined( 'defaults.app.serverHomeDirectory' ) && len( defaults.app.serverHomeDirectory )  ) { defaults.app.serverHomeDirectory = fileSystemUtil.resolvePath( defaults.app.serverHomeDirectory, defaultwebroot ); }
		serverInfo.serverHomeDirectory			= serverProps.serverHomeDirectory			?: serverJSON.app.serverHomeDirectory			?: defaults.app.serverHomeDirectory;

		serverInfo.sessionCookieSecure			= serverJSON.app.sessionCookieSecure			?: defaults.app.sessionCookieSecure;
		serverInfo.sessionCookieHTTPOnly			= serverJSON.app.sessionCookieHTTPOnly			?: defaults.app.sessionCookieHTTPOnly;

		// These are already hammered out above, so no need to go through all the defaults.
		serverInfo.serverConfigFile	= defaultServerConfigFile;
		serverInfo.name 			= defaultName;
		serverInfo.webroot 			= normalizeWebroot( defaultwebroot );

		if( serverInfo.verbose ) {
			job.addLog( "start server in - " & serverInfo.webroot );
			job.addLog( "server name - " & serverInfo.name );
			job.addLog( "server config file - " & defaultServerConfigFile );
		}

		if( !len( serverInfo.WARPath ) && !len( serverInfo.cfengine ) ) {
			// Turn 1.2.3.4 into 1.2.3+4
			serverInfo.cfengine =  serverEngineService.getCLIEngineName() & '@' & reReplace( server.lucee.version, '([0-9]*.[0-9]*.[0-9]*)(.)([0-9]*)', '\1+\3' );
		}

		if( serverInfo.cfengine.endsWith( '@' ) ) {
			serverInfo.cfengine = left( serverInfo.cfengine, len( serverInfo.cfengine ) - 1 );
		}

		var launchUtil 	= java.LaunchUtil;

	    // Default java agent
	    var javaagent = '';

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

			// If we couldn't guess the engine type above, give it another go.  Perhaps the box.json in the CF Engine gave us a clue.
			// This happens then starting like so
			// start cfengine=http://hostname/rest/update/provider/forgebox/5.3.4.54-rc
			// Because the cfengine value doesn't actually contain "lucee" but the box.json in the download will tell us
			if( !len( CFEngineName ) ) {
			    CFEngineName = installDetails.engineName contains 'lucee' ? 'lucee' : CFEngineName;
			    CFEngineName = installDetails.engineName contains 'railo' ? 'railo' : CFEngineName;
			    CFEngineName = installDetails.engineName contains 'adobe' ? 'adobe' : CFEngineName;
			}

			serverInfo.serverHomeDirectory = installDetails.installDir;
			// TODO: As of 3.5 "serverHome" is for backwards compat.  Remove in later version in favor of serverHomeDirectory above
			serverInfo[ 'serverHome' ] = installDetails.installDir;
			serverInfo.logdir = serverInfo.serverHomeDirectory & "/logs";
			serverInfo.engineName = installDetails.engineName;
			serverInfo.engineVersion = installDetails.version;
			serverInfo.appFileSystemPath = serverInfo.webroot;

			// Make current settings available to package scripts
			setServerInfo( serverInfo );
			// This interception point can be used for additional configuration of the engine before it actually starts.
			interceptorService.announceInterception( 'onServerInstall', { serverInfo=serverInfo, installDetails=installDetails, serverJSON=serverJSON } );

			// If Lucee server, set the java agent
			if( serverInfo.cfengine contains "lucee" ) {
				// Detect Lucee 4.x
				if( installDetails.version.listFirst( '.' ) < 5 && fileExists( '#serverInfo.serverHomeDirectory#/WEB-INF/lib/lucee-inst.jar' ) ) {
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
			var displayEngineName = serverInfo.engineName & ' ' & installDetails.version;

		// This is a WAR
		} else {
			// If WAR is a file
			if( fileExists( serverInfo.WARPath ) ){
				// It will be extracted into a folder named after the file
				serverInfo.serverHomeDirectory = reReplaceNoCase( serverInfo.WARPath, '(.*)(\.zip|\.war)', '\1' );

				// Expand the war if it doesn't exist or we're forcing
				if( !directoryExists( serverInfo.serverHomeDirectory ) || ( serverProps.force ?: false ) ) {
					job.addLog( "Exploding WAR archive...");
					directoryCreate( serverInfo.serverHomeDirectory, true, true );
					zip action="unzip" file="#serverInfo.WARPath#" destination="#serverInfo.serverHomeDirectory#" overwrite="true";
				}

			// If WAR is a folder
			} else {
				// Just use it
				serverInfo.serverHomeDirectory = serverInfo.WARPath;
			}
			serverInfo.appFileSystemPath = serverInfo.serverHomeDirectory;
			// Create a custom server folder to house the logs
			serverInfo.logdir = serverinfo.customServerFolder & "/logs";
			var displayServerName = processName;
			var displayEngineName = 'WAR';
		}

		// Doing this check here instead of the ServerEngineService so it can apply to existing installs
		if( CFEngineName == 'adobe' ) {
			// Work arounnd sketchy resoution of non-existent paths in Undertow
			// https://issues.jboss.org/browse/UNDERTOW-1413
			var flexLogFile = serverInfo.serverHomeDirectory & "/WEB-INF/cfform/logs/flex.log";
			if ( !fileExists( flexLogFile ) ) {
				// if this doesn't already exist, it ends up getting created in a WEB-INF folder in the web root.  Eww....
				directoryCreate( getDirectoryFromPath( flexLogFile ), true, true );
				fileWrite( flexLogFile, '' );
			}
		}

		// logdir is set above and is different for WARs and CF engines
		serverInfo.consolelogPath = serverInfo.logdir & '/server.out.txt';
		serverInfo.accessLogPath = serverInfo.logDir & '/access.txt';
		serverInfo.rewritesLogPath = serverInfo.logDir & '/rewrites.txt';

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
				} else if( listFirst( serverInfo.engineVersion, '.' ) == 2018 ) {
					serverInfo.trayIcon = '/commandbox/system/config/server-icons/trayicon-cf2018#iconSize#.png';
				} else {
					serverInfo.trayIcon = '/commandbox/system/config/server-icons/trayicon-cf2018#iconSize#.png';
				}

			}
		}

		// Default tray icon
		serverInfo.trayIcon = ( len( serverInfo.trayIcon ) ? serverInfo.trayIcon : '/commandbox/system/config/server-icons/trayicon.png' );
		serverInfo.trayIcon = expandPath( serverInfo.trayIcon );

		// Set default options for all servers
		// TODO: Don't overwrite existing options with the same label.

		var appFileSystemPathDisplay = fileSystemUtil.normalizeSlashes( serverInfo.appFileSystemPath );
		// Deal with possibly very deep folder structures which would look bad in the menu or possible reach off the screen
		if( appFileSystemPathDisplay.len() > 50 && appFileSystemPathDisplay.listLen( '/' ) > 2 ) {
			var pathLength = appFileSystemPathDisplay.listLen( '/' );
			var firstFolder = appFileSystemPathDisplay.listFirst( '/' );
			var lastFolder = appFileSystemPathDisplay.listLast( '/' );
			var middleStuff = appFileSystemPathDisplay.listDeleteAt( pathLength, '/' ).listDeleteAt( 1, '/' );
			// Ignoring slashes here.  Doesn't need to be exact.
			var leftOverLen = max( 50 - (firstFolder.len() + lastFolder.len() ), 1 );
			// This will shorten the path to C:/firstfolder/somes/tuff.../lastFolder/
			// with a final result that is close to 50 characters
			appFileSystemPathDisplay = firstFolder & '/' & middleStuff.left( leftOverLen ) & '.../' & lastFolder & '/';
		}

		// If there is a max size and it doesn't have a letter in it
		if( len( serverInfo.heapSize ) && serverInfo.heapSize == val( serverInfo.heapSize ) ) {
			// Default it to megs
			serverInfo.heapSize &= 'm';
		}
		// Same for min heap size
		if( len( serverInfo.minHeapSize ) && serverInfo.minHeapSize == val( serverInfo.minHeapSize ) ) {
			// Default it to megs
			serverInfo.minHeapSize &= 'm';
		}

		var tempOptions = [];
		serverInfo.trayOptions = [];
		tempOptions.prepend(
			{
				"label":"Info",
				"items": [
					{ "label" : "Engine: " & displayEngineName, "disabled" : true },
					{ "label" : "Webroot: " & appFileSystemPathDisplay, "action" : "openfilesystem", "path" : serverInfo.appFileSystemPath, 'image' : expandPath('/commandbox/system/config/server-icons/folder.png' ) },
					{ "label" : "URL: " & serverInfo.defaultBaseURL, 'action':'openbrowser', 'url': serverInfo.defaultBaseURL, 'image' : expandPath('/commandbox/system/config/server-icons/home.png' ) },
					{ "label" : "PID: ${runwar.PID}", "disabled" : true  },
					{ "label" : "Heap: #( len( serverInfo.heapSize ) ? serverInfo.heapSize : 'Not set' )#", "disabled" : true  }
				],
				"image" : expandPath('/commandbox/system/config/server-icons/info.png' )
			} );

		var openItems = [];
	    if( CFEngineName contains "lucee" ) {
			openItems.prepend( { 'label':'Web Admin', 'action':'openbrowser', 'url':'#serverInfo.defaultBaseURL#/lucee/admin/web.cfm', 'image' : expandPath('/commandbox/system/config/server-icons/web_settings.png' ) } );
			openItems.prepend( { 'label':'Server Admin', 'action':'openbrowser', 'url':'#serverInfo.defaultBaseURL#/lucee/admin/server.cfm', 'image' : expandPath('/commandbox/system/config/server-icons/server_settings.png' ) } );
		} else if( CFEngineName contains "railo" ) {
			openItems.prepend( { 'label':'Web Admin', 'action':'openbrowser', 'url':'#serverInfo.defaultBaseURL#/railo-context/admin/web.cfm', 'image' : expandPath('/commandbox/system/config/server-icons/web_settings.png' ) } );
			openItems.prepend( { 'label':'Server Admin', 'action':'openbrowser', 'url':'#serverInfo.defaultBaseURL#/railo-context/admin/server.cfm', 'image' : expandPath('/commandbox/system/config/server-icons/server_settings.png' ) } );
		} else if( CFEngineName contains "adobe" ) {
			openItems.prepend( { 'label':'Server Admin', 'action':'openbrowser', 'url':'#serverInfo.defaultBaseURL#/CFIDE/administrator/enter.cfm', 'image' : expandPath('/commandbox/system/config/server-icons/server_settings.png' ) } );
		}

		openItems.prepend( { 'label':'Site Home', 'action':'openbrowser', 'url': serverInfo.openbrowserURL, 'image' : expandPath('/commandbox/system/config/server-icons/home.png' ) } );

		openItems.prepend( { "label" : "Server Home", "action" : "openfilesystem", "path" : serverInfo.serverHomeDirectory, "image" : expandPath('/commandbox/system/config/server-icons/folder.png' ) } );

		openItems.prepend( { "label" : "Webroot", "action" : "openfilesystem", "path" : serverInfo.appFileSystemPath, "image" : expandPath('/commandbox/system/config/server-icons/folder.png' ) } );

		tempOptions.prepend( { 'label':'Open...', 'items': openItems, "image" : expandPath('/commandbox/system/config/server-icons/open.png' ) } );

		tempOptions.prepend( { 'label' : 'Restart Server', 'hotkey':'R', 'action' : "runAsync" , "command" : "box server restart " & "'#serverInfo.name#'", 'image': expandPath('/commandbox/system/config/server-icons/restart.png' ), 'workingDirectory': defaultwebroot} );

		tempOptions.prepend( { 'label':'Stop Server', 'action':'stopserver', 'image' : expandPath('/commandbox/system/config/server-icons/stop.png' ) } );

		// Take default options, then append config defaults and server.json trayOptions on top of them (allowing nested overwrite)
		serverInfo.trayOptions = appendMenuItems( tempOptions, defaultwebroot, [] );
		serverInfo.trayOptions = appendMenuItems( defaults.trayOptions, defaultwebroot, serverInfo.trayOptions );
		serverInfo.trayOptions = appendMenuItems( serverJSON.trayOptions ?: [], defaultServerConfigFileDirectory, serverInfo.trayOptions );

	    // This is due to a bug in RunWar not creating the right directory for the logs
	    directoryCreate( serverInfo.logDir, true, true );

		// Make current settings available to package scripts
		setServerInfo( serverInfo );
		// installDetails doesn't exist for a war server
		interceptorService.announceInterception( 'onServerStart', { serverInfo=serverInfo, serverJSON=serverJSON, defaults=defaults, serverProps=serverProps, serverDetails=serverDetails, installDetails=installDetails ?: {} } );

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
		var trayOptionsPath = serverinfo.serverHomeDirectory & '/.trayOptions.json';
		var trayJSON = {
			'title' : displayServerName,
			'tooltip' : processName,
			'items' : serverInfo.trayOptions
		};
		fileWrite( trayOptionsPath,  serializeJSON( trayJSON ) );
		var background = !(serverInfo.console ?: false);
		// The java arguments to execute:  Shared server, custom web configs

		// This is an array of tokens to send to the process builder
		var args = [];
		// "borrow" the CommandBox commandline parser to tokenize the JVM args. Not perfect, but close. Handles quoted values with spaces.
		// Escape any semicolons so the parser ignores them in a string and doesn't break the token ex: -DMY_ENV_VAR=foo;bar
		var argTokens = parser.tokenizeInput( serverInfo.JVMargs.replace( ';', '\;', 'all' ) )
			.map( function( i ){
				// unwrap quotes, and unescape any special chars like \" inside the string
				return parser.replaceEscapedChars( parser.removeEscapedChars( parser.unwrapQuotes( i ) ) );
			});


		// Add in max heap size
		if( len( serverInfo.heapSize ) ) {
			argTokens.append( '-Xmx#serverInfo.heapSize#' );
		}

		// Add in min heap size
		if( len( serverInfo.minHeapSize ) ) {
			if( len(serverInfo.minHeapSize ) && len( serverInfo.heapSize ) && isHeapLarger( serverInfo.minHeapSize, serverInfo.heapSize ) ) {
				job.addWarnLog( 'Your JVM min heap size [#serverInfo.minHeapSize#] is set larger than your max size [#serverInfo.heapSize#]! Reducing the Min to prevent errors.' );
				serverInfo.minHeapSize = serverInfo.heapSize;
			}
			argTokens.append( '-Xms#serverInfo.minHeapSize#' );
		}

		// Add java agent
		if( len( trim( javaAgent ) ) ) { argTokens.append( javaagent ); }

		 args
		 	.append( '-jar' ).append( serverInfo.runwarJarPath )
			.append( '--background=#background#' )
			.append( '--host' ).append( serverInfo.host )
			.append( '--stop-port' ).append( serverInfo.stopsocket )
			.append( '--processname' ).append( processName )
			.append( '--log-dir' ).append( serverInfo.logDir )
			.append( '--server-name' ).append( serverInfo.name )
			.append( '--tray-enable' ).append( serverInfo.trayEnable )
			.append( '--dock-enable' ).append( serverInfo.dockEnable )
			.append( '--directoryindex' ).append( serverInfo.directoryBrowsing )
			.append( '--timeout' ).append( serverInfo.startTimeout )
			.append( '--proxy-peeraddress' ).append( 'true' )
			.append( '--cookie-secure' ).append( serverInfo.sessionCookieSecure )
			.append( '--cookie-httponly' ).append( serverInfo.sessionCookieHTTPOnly );

		if( ConfigService.settingExists( 'preferredBrowser' ) ) {
			args.append( '--preferred-browser' ).append( ConfigService.getSetting( 'preferredBrowser' ) );
		}

		args.append( serverInfo.runwarArgs.listToArray( ' ' ), true );

		if( serverInfo.trayEnable ) {
			args
				.append( '--tray-icon' ).append( serverInfo.trayIcon )
				.append( '--tray-config' ).append( trayOptionsPath )
		}

		if( serverInfo.runwarXNIOOptions.count() ) {
			args.append( '--xnio-options=' & serverInfo.runwarXNIOOptions.reduce( ( opts='', k, v ) => opts.listAppend( k & '=' & v ) ) );
		}

		if( len( serverInfo.allowedExt ) ) {
			args.append( '--default-servlet-allowed-ext=' & serverInfo.allowedExt );
		}

		if( serverInfo.runwarUndertowOptions.count() ) {
			args.append( '--undertow-options=' & serverInfo.runwarUndertowOptions.reduce( ( opts='', k, v ) => opts.listAppend( k & '=' & v ) ) );
		}

		if( serverInfo.debug ) {
			// Debug is getting turned on any time I include the --debug flag regardless of whether it's true or false.
			args.append( '--debug' ).append( serverInfo.debug );
		}

		if( len( serverInfo.restMappings ) ) {
			args.append( '--servlet-rest-mappings' ).append( serverInfo.restMappings );
		}

		if( serverInfo.trace ) {
			args.append( '--log-level' ).append( 'TRACE' );
		}

		if( len( errorPages ) ) {
			args.append( '--error-pages' ).append( errorPages );
		}

		if( serverInfo.GZIPEnable ) {
			args.append( '--gzip-enable' ).append( true );
			if( len( trim( serverInfo.gzipPredicate ) ) ){
				args.append( '--gzip-predicate' ).append( serverInfo.gzipPredicate );
			}
		}

		if( serverInfo.accesslogenable ) {
			args
				.append( '--logaccess-enable' ).append( true )
			 	.append( '--logaccess-basename' ).append( 'access' )
			 	.append( '--logaccess-dir' ).append( serverInfo.logDir );
		}


		if( serverInfo.rewritesLogEnable ) {
			args.append( '--urlrewrite-log' ).append( serverInfo.rewritesLogPath );
		}

		/* 	.append( '--logrequests-enable' ).append( true )
		 	.append( '--logrequests-basename' ).append( 'request' )
		 	.append( '--logrequests-dir' ).append( serverInfo.logDir )
		 	*/


	 	if( len( CFEngineName ) ) {
	 		 args.append( '--cfengine-name' ).append( CFEngineName );
	 	}
	 	if( len( serverInfo.welcomeFiles ) ) {
	 		 args.append( '--welcome-files' ).append( serverInfo.welcomeFiles );
	 	}
	 	if( len( serverInfo.maxRequests ) ) {
	 		 args.append( '--worker-threads' ).append( serverInfo.maxRequests );
	 	}
	 	if( len( CLIAliases ) ) {
	 		 args.append( '--dirs' ).append( CLIAliases );
	 	}


		// If background, wrap up JVM args to pass through to background servers.  "Real" JVM args must come before Runwar args
		if( background ) {
			// Escape any semi colons or backslash literals in the args so Runwar can process this properly
			// -Darg=one;-Darg=two
			var argString = argTokens
				.map( ( token ) => token.replace( '\', '\\', 'all' ).replace( ';', '\;', 'all' ) )
				.toList( ';' );
			if( len( argString ) ) {
				args.append( '--jvm-args=#trim( argString )#' );
			}
		// If foreground, just stick them in.
		} else {
			argTokens.each( function(i) { args.prepend( i ); } );
		}

		// Webroot for normal server, and war home for a standard war
		args.append( '-war' ).append( serverInfo.appFileSystemPath );

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

		// Always send the enable flag for each protocol
		args
			.append( '--http-enable' ).append( serverInfo.HTTPEnable )
			.append( '--ssl-enable' ).append( serverInfo.SSLEnable )
			.append( '--ajp-enable' ).append( serverInfo.AJPEnable );


		if( serverInfo.HTTPEnable || serverInfo.SSLEnable ) {
			args
			 	.append( '--open-browser' ).append( serverInfo.openbrowser )
				.append( '--open-url' ).append( serverInfo.openbrowserURL );
		} else {
			args.append( '--open-browser' ).append( false );
		}


		// Send HTTP port if it's enabled
		if( serverInfo.HTTPEnable ){
			args.append( '--port' ).append( serverInfo.port )
		}

		// Send SSL port if it's enabled
		if( serverInfo.SSLEnable ){
			args.append( '--ssl-port' ).append( serverInfo.SSLPort );
		}

		// Send AJP port if it's enabled
		if( serverInfo.AJPEnable ){
			args.append( '--ajp-port' ).append( serverInfo.AJPPort );
		}

		// Send SSL cert info if SSL is enabled and there's cert info
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
				job.error( 'URL rewrite config not found [#serverInfo.rewritesConfig#]' );
				return;
			}
			args.append( '--urlrewrite-file' ).append( serverInfo.rewritesConfig );
		}

		if( serverInfo.webRules.len() ){
			var predicateFile = serverinfo.serverHomeDirectory & '/.predicateFile.txt';
			fileWrite( predicateFile, serverInfo.webRules.toList( CR ) );
			args.append( '--predicate-file' ).append( predicateFile );
		}

		// change status to starting + persist
		serverInfo.dateLastStarted = now();
		serverInfo.status = "starting";
		setServerInfo( serverInfo );

	    // needs to be unique in each run to avoid errors
		var threadName = 'server#hash( serverInfo.webroot )##createUUID()#';
		// Construct a new process object
	    var processBuilder = createObject( "java", "java.lang.ProcessBuilder" );
	    // Pass array of tokens comprised of command plus arguments
	    args.prepend( serverInfo.javaHome );

	    // In *nix OS's we need to separate the server process from the CLI process
	    // so SIGINTs from Ctrl-C won't also kill previously started servers
	    if( !fileSystemUtil.isWindows() && background ) {
	    	// The shell script will take care of creating this file and emptying it every time
	    	var nohupLog = '#serverInfo.serverHomeDirectory#/nohup.log';
	    	// Pass log file to external process.  This is so we can capture the output of the server process
	    	args.prepend( '#serverInfo.serverHomeDirectory#/nohup.log' );
	    	// Use this intermediate shell script to start our server via nohup
	    	args.prepend( expandPath( '/server-commands/bin/server_spawner.sh' ) );
	    	// Pass script directly to bash so I don't have to worry about it being executable
			args.prepend( fileSystemUtil.getNativeShell() );
	    }

		// At this point all command line arguments are in place, announce this
		var interceptData = {
			commandLineArguments=args,
			serverInfo=serverInfo,
			serverJSON=serverJSON,
			defaults=defaults,
			serverProps=serverProps,
			serverDetails=serverDetails,
			installDetails=installDetails ?: {}
		};
		interceptorService.announceInterception( 'onServerProcessLaunch', interceptData );
		// ensure we get the updated args if they were replaced wholesale by interceptor
		args = interceptData.commandLineArguments;

		// now we can log the *final* command line string that will be used to start the server
	    if( serverInfo.verbose ) {
			var cleanedArgs = cr & '    ' & trim( args.map( ( arg )=>reReplaceNoCase( arg, '^(-|"-)', cr & '    \1', 'all' )  ).toList( ' ' ) );
			job.addLog("Server start command: #cleanedargs#");
	    }

		if( serverProps.dryRun ?: false ) {
			job.addLog( 'Dry run specified, exiting without starting server.' );
			job.complete( serverInfo.verbose );
			return;
		}

	    processBuilder.init( args );

        // incorporate CommandBox environment variables into the process's env
        var currentEnv = processBuilder.environment();
        currentEnv.putAll( systemSettings.getAllEnvironmentsFlattened().map( (k, v)=>toString(v) ) );

        // Special check to remove ConEMU vars which can screw up the sub process if it happens to run cmd, such as opening VSCode.
        if( fileSystemUtil.isWindows() && currentEnv.containsKey( 'ConEmuPID' ) ) {
            for( var key in currentEnv ) {
            	if( key.startsWith( 'ConEmu' ) || key == 'PROMPT' ) {
            		currentEnv.remove( key );
            	}
            }
        }

	    // Conjoin standard error and output for convenience.
	    processBuilder.redirectErrorStream( true );
	    // Kick off actual process
	    variables.process = processBuilder.start();

		// She'll be coming 'round the mountain when she comes...
		job.addWarnLog( "The server for #serverInfo.webroot# is starting on #serverInfo.openbrowserURL# ..." );

	    job.complete( serverInfo.verbose );
	    consoleLogger.debug( '.' );

		// If the user is running a one-off command to start a server or specified the verbose flag, stream the output and wait until it's finished starting.
		var interactiveStart = ( shell.getShellType() == 'command' || serverInfo.verbose || !background );

		// A reference to the current thread so the thread we're about to spin up can access it.
		// This may be available as parent thread or something.
		var thisThread = createObject( 'java', 'java.lang.Thread' ).currentThread();
		variables.waitingOnConsoleStart = false;
		variables.internalInterrupt = false;
		serverInfo.exitCode = 0;
		// Spin up a thread to capture the standard out and error from the server
		thread name="#threadName#" interactiveStart=interactiveStart serverInfo=serverInfo args=args startTimeout=serverInfo.startTimeout parentThread=thisThread {
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

					// Log messages from the CF engine or app code writing directly to std/err out strip off "runwar.context" but leave color coded severity
					// Ex:
					// [INFO ] runwar.context: 04/11 15:47:10 INFO Starting Flex 1.5 CF Edition
					line = reReplaceNoCase( line, '^((#chr( 27 )#\[m)?\[[^]]*])( runwar\.context: )(.*)', '\1 \4' );

					// Log messages from runwar itself, simplify the logging category to just "Runwar:" and leave color coded severity
					// Ex:
					// [DEBUG] runwar.config: Enabling Proxy Peer Address handling
					// [DEBUG] runwar.server: Starting open browser action
					line = reReplaceNoCase( line, '^((#chr( 27 )#\[m)?\[[^]]*])( runwar\.[^:]*: )(.*)', '\1 Runwar: \4' );
					//consoleLogger.debug( 'LINE:' . line );
					line = AnsiFormater.cleanLine( line );
					// Log messages from any other 3rd party java lib tapping into Log4j will be left alone
					// Ex:
					// [DEBUG] org.tuckey.web.filters.urlrewrite.RuleExecutionOutput: needs to be forwarded to /index.cfm/Main

					// Build up our output.  Limit the size of this so a console server running for a month doesn't fill up memory.
					// We only use this for the server info result anyway.
					if( startOutput.length() < 1000 ) {
						startOutput.append( line & chr( 13 ) & chr( 10 ) );
					}

					// output it if we're being interactive
					if( attributes.interactiveStart ) {
						print
							.line( line )
							.toConsole();
					}

					line = bufferedReader.readLine();
				} // End of inputStream

				// When we require Java 8 for CommandBox, we can pass a timeout to waitFor().
				serverInfo.exitCode = process.waitFor();

				if( serverInfo.exitCode == 0 ) {
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
				serverInfo.statusInfo.result = print.unansi( startOutput.toString() );
				setServerInfo( serverInfo );
				// If the "start" command is on the line watching our console output
				if( variables.waitingOnConsoleStart ) {
					print
						.line()
						.line( "Server's output stream closed. It's been stopped elsewhere." )
						.toConsole();
					// This will end the readline() call below so the "start" command can finally exit
					variables.internalInterrupt = true;
					parentThread.interrupt();
				}
			}
		}

		var serverInterrupted = false;
		// Block until the process ends and the streaming output thread above is done.
		if( interactiveStart ) {

			if( !background ) {
				try {

					// Need to start reading the input stream or we can't detect Ctrl-C on Windows
					var terminal = shell.getReader().getTerminal();
					if( terminal.paused() ) {
							terminal.resume();
					}
					variables.waitingOnConsoleStart = true;
					while( true ) {
						// For dumb terminals, just sit and wait to be interrupted
						// Trying to read from a dumb terminal will throw "The handle is invalid" errors
						if( terminal.getClass().getName() contains 'dumb' ) {
							sleep( 500 );
						} else {
							// Detect user pressing Ctrl-C
							// Any other characters captured will be ignored
							var line = shell.getReader().readLine();
							if( line == 'q' ) {
								break;
							} else {
								consoleLogger.error( 'To exit press Ctrl-C or "q" followed the enter key.' );
							}
						}
					}

				// user wants to exit this command, they've pressed Ctrl-C
				} catch ( org.jline.reader.UserInterruptException e ) {
					consoleLogger.error( 'Stopping server...' );
					serverInterrupted = true;
				// user wants to exit the shell, they've pressed Ctrl-D
				} catch ( org.jline.reader.EndOfFileException e ) {
					consoleLogger.error( 'Stopping server...' );
					shell.setKeepRunning( false );
					serverInterrupted = true;
				// Something bad happened
				} catch ( Any e ) {
					logger.error( '#e.message# #e.detail#' , e.stackTrace );
					consoleLogger.error( '#e.message##chr(10)##e.detail#' );
				// Either way, this server is done like dinner
				} finally {
					variables.waitingOnConsoleStart = false;
					shell.setPrompt();
					process.destroy();
					// "server stop" is never run for a --console start, so make sure this fires.
					interceptorService.announceInterception( 'onServerStop', { serverInfo=serverInfo } );
				}
			}

			thread action="join" name="#threadName#";
		}

		// It's hard to tell the difference between a user hitting Ctrl-C on a console server and the process getting killed elsewhere, which also sends an interrupt to the main thread.
		// We care abut failing exit codes if the server was interrupted unexpectedly
		if( serverInfo.exitCode != 0 && ( !serverInterrupted || variables.internalInterrupt ) ) {
			consoleLogger.info( '.' );
			throw( message='Server process returned failing exit code [#serverInfo.exitCode#]', type="commandException", errorcode=serverInfo.exitCode );
		}

	}


	/**
	* allows to iterate on a tray menu item recursively
	* and checks for the default image and default shell
	*/
	array function appendMenuItems( array trayOptions, relativePath, array parentOptions ) {
		arguments.trayOptions.each( function( menuItem ){
			// Resolve images and massage default tray options
			newMenuItem = prepareMenuItem( menuItem, relativePath );

			var match = parentOptions.find( (m)=>trim( m.label ) == trim( newMenuItem.label ) );
			if( match ) {
				parentOptions[ match ].append( newMenuItem );
				newMenuItem = parentOptions[ match ]
			} else {
				parentOptions.append( newMenuItem );
			}

			if( menuItem.keyExists( 'items' ) && menuItem.items.len() ){
				// Runwar requires "items" to be lowercase
				newMenuItem[ 'items' ] = appendMenuItems( menuItem.items, relativePath, newMenuItem.items ?: [] );
			}
		} );
		return arguments.parentOptions;
	}

	/**
	* checks for the default image and default shell
	*/
	function prepareMenuItem( menuItem, relativePath ) {
		menuItem.label = menuItem.label ?: '';
		// Make relative image paths absolute
		if( menuItem.keyExists( 'image' ) && menuItem.image.len() ) {
			menuItem[ 'image' ] = fileSystemUtil.resolvePath( menuItem.image, relativePath );
		}

		// Make relative working directory paths absolute
		if( menuItem.keyExists( 'workingDirectory' ) ) {
			menuItem[ 'workingDirectory' ] = fileSystemUtil.resolvePath( menuItem.workingDirectory, relativePath );
		}

		// Make relative file system paths absolute
		if( menuItem.keyExists( 'path' ) ) {
			menuItem[ 'path' ] = fileSystemUtil.resolvePath( menuItem.path, relativePath );
		}

		//need to check if a shell has been defined for this action
		if( menuItem.keyExists( 'action' ) && listFindNoCase('run,runAsync,runTerminal',menuItem.action)){
			menuItem[ 'shell' ] = menuItem.shell ?: fileSystemUtil.getNativeShell();
			// Some special love for box commands
			if( menuItem.command.lCase().reFindNoCase( '^box(\.exe)? ' )  ) {
				menuItem.command = fixBinaryPath( trim(menuItem.command), systemSettings.getSystemSetting( 'java.class.path' ));
				menuItem[ 'image' ] = menuItem.image ?: expandPath('/commandbox/system/config/server-icons/box.png' );
			} else {
				menuItem[ 'image' ] = menuItem.image ?: expandPath('/commandbox/system/config/server-icons/' & menuItem.action & '.png' );
			}
		}

		if(menuItem.keyExists( 'action' ) && menuItem.action == 'runTerminal' ){
			var nativeTerminal = "";

			if (fileSystemUtil.isMac()) {
				nativeTerminal = ConfigService.getSetting( 'nativeTerminal', "osascript -e 'tell app " & "terminal" &  " to do script " & "@@command@@" & "'"  );
				menuItem[ 'action' ] = 'runAsync';
			} else if (fileSystemUtil.isWindows()) {
				nativeTerminal = ConfigService.getSetting( 'nativeTerminal', 'start cmd.exe /k "@@command@@"' );
				menuItem[ 'action' ] = 'runAsync';
			} else {
				// For unsupported OS's simply run the command
				nativeTerminal = ConfigService.getSetting( 'nativeTerminal', '"@@command@@"' );
				menuItem[ 'action' ] = 'run';
			}

			menuItem[ 'command' ] = replaceNoCase( nativeTerminal, '@@command@@', menuItem[ 'command' ], 'all' );
		}
		return menuItem.filter( (k)=>k!='items' );
	}

	function fixBinaryPath(command, fullPath){
		if(!isNull(fullPath) or !isEmpty(fullPath)){
			if( command.left( 4 ) == 'box ' ){
				command = command.replacenoCase( 'box ', fullPath & ' ', 'one' );
			} else if( command.left( 8 ) == 'box.exe ' ){
				command = command.replacenoCase( 'box.exe ', fullPath & ' ', 'one' );
			}
		}
		return command;
	}

	/**
	* Detects if the first heap size is larger than the second
	* @heapSize1 Specified as 1024m, 2G, or 512k
	* @heapSize2 Specified as 1024m, 2G, or 512k
	*/
	function isHeapLarger( heapSize1, heapSize2 ) {
		heapSize1 = convertHeapToMB( heapSize1 );
		heapSize2 = convertHeapToMB( heapSize2 );
		return heapSize1 > heapSize2;
	}

	/**
	* Convert heap in format like 1G to 1024
	* Will always return MB, but without the "m"
	*/
	function convertHeapToMB( heapSize ) {
		heapSize = heapSize.lcase();
		// 1024m or just 1024
		if( heapSize.endsWith( 'm' ) || val( heapSize ) == heapSize ) {
			return val( heapSize );
		}
		// 2G
		if( heapSize.endsWith( 'g' ) ) {
			return val( heapSize ) * 1024;
		}
		// 512K
		if( heapSize.endsWith( 'k' ) ) {
			return val( heapSize ) / 1024;
		}
		throw( 'Invalid Heap size [#heapSize#]' );
	}

	function getFirstServer() {
		return getServers()[ getServers().keyArray().first() ];
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

		// If CommandBox is in single server mode, just force the first (and only) server to be the one we find
		if( ConfigService.getSetting( 'server.singleServerMode', false ) && getServers().count() ){

			// CFConfig calls this method sometimes with a path to a JSON file and needs to get no server back
			if( serverProps.keyExists( 'name' ) && lcase( serverProps.name ).endsWith( '.json' ) ) {
				return {
					defaultName : '',
					defaultwebroot : '',
					defaultServerConfigFile : '',
					serverJSON : {},
					serverInfo : {},
					serverIsNew : true
				};
			}

			var serverInfo = getFirstServer();
			return {
				defaultName : serverInfo.name,
				defaultwebroot : serverInfo.webroot,
				defaultServerConfigFile : serverInfo.serverConfigFile,
				serverJSON : readServerJSON( serverInfo.serverConfigFile ),
				serverInfo : serverInfo,
				serverIsNew : false
			};
		}

		var job = wirebox.getInstance( 'interactiveJob' );
		var locVerbose = serverProps.verbose ?: false;

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
	    if( locVerbose ) { consoleLogger.debug("Looking for server JSON file by convention: #defaultServerConfigFile#"); }
		var serverJSON_rawSystemSettings = readServerJSON( defaultServerConfigFile );
		var serverJSON = systemSettings.expandDeepSystemSettings( duplicate( serverJSON_rawSystemSettings ) );

		// Get the web root out of the server.json, if specified and make it relative to the actual server.json file.
		// If user gave us a webroot, we use it first.
		if( len( arguments.serverProps.directory ?: '' ) ) {
			var defaultwebroot = arguments.serverProps.directory;
		    if( locVerbose ) { consoleLogger.debug("webroot specified by user: #defaultwebroot#"); }
		// Get the web root out of the server.json, if specified and make it relative to the actual server.json file.
		} else if( len( serverJSON.web.webroot ?: '' ) ) {
			var defaultwebroot = fileSystemUtil.resolvePath( serverJSON.web.webroot, getDirectoryFromPath( defaultServerConfigFile ) );
		    if( locVerbose ) { consoleLogger.debug("webroot pulled from server's JSON: #defaultwebroot#"); }
		// Otherwise default to the directory the server's JSON file lives in (which defaults to the CWD)
		} else {
			var defaultwebroot = fileSystemUtil.resolvePath( getDirectoryFromPath( defaultServerConfigFile ) );
		    if( locVerbose ) { consoleLogger.debug("webroot defaulted to location of server's JSON file: #defaultwebroot#"); }
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
			serverConfigFile	= serverProps.serverConfigFile ?: '' //  Since this takes precedence, I only want to use it if it was actually specified
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
			if( len( serverProps.serverConfigFile ?: '' ) ) {
				serverInfo.serverConfigFile = serverProps.serverConfigFile
			}
		}

		// If the user didn't provide an explicit config file and it turns out last time we started a server by this name, we used a different
		// config, let's re-read out that config JSON file to use instead of the default above.
		if( !len( serverProps.serverConfigFile ?: '' )
			&& len( serverInfo.serverConfigFile ?: '' )
			&& serverInfo.serverConfigFile != defaultServerConfigFile
			&& fileExists( serverInfo.serverConfigFile ) ) {

			// Get server descriptor again
		    if( locVerbose ) { consoleLogger.debug("Switching to the last-used server JSON file for this server: #serverInfo.serverConfigFile#"); }
			var serverJSON_rawSystemSettings = readServerJSON( serverInfo.serverConfigFile );
			var serverJSON = systemSettings.expandDeepSystemSettings( duplicate( serverJSON_rawSystemSettings ) );
			defaultServerConfigFile = serverInfo.serverConfigFile;

			// Now that we changed server JSONs, we need to recalculate the webroot.
		    if( locVerbose ) { consoleLogger.debug("Recalculating web root based on new server JSON file."); }
			// If user gave us a webroot, we use it first.
			if( len( arguments.serverProps.directory ?: '' ) ) {
				var defaultwebroot = arguments.serverProps.directory;
			    if( locVerbose ) { consoleLogger.debug("webroot specified by user: #defaultwebroot#"); }
			// Get the web root out of the server.json, if specified and make it relative to the actual server.json file.
			} else if( len( serverJSON.web.webroot ?: '' ) ) {
				var defaultwebroot = fileSystemUtil.resolvePath( serverJSON.web.webroot, getDirectoryFromPath( serverInfo.serverConfigFile ) );
			    if( locVerbose ) { consoleLogger.debug("webroot pulled from server's JSON: #defaultwebroot#"); }
			// Otherwise default to the directory the server's JSON file lives in (which defaults to the CWD)
			} else {
				var defaultwebroot = fileSystemUtil.resolvePath( getDirectoryFromPath( serverInfo.serverConfigFile ) );
			    if( locVerbose ) { consoleLogger.debug("webroot defaulted to location of server's JSON file: #defaultwebroot#"); }
			}

		}

		// By now we've figured out the name, webroot, and serverConfigFile for this server.
		// Also return the serverInfo of the last values the server was started with (if ever)
		// and the serverJSON setting for the server, if they exist.
		return {
			defaultName : defaultName,
			defaultwebroot : defaultwebroot,
			defaultServerConfigFile : defaultServerConfigFile,
			serverJSON : serverJSON_rawSystemSettings,
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
		if( configService.getSetting( 'server.singleServerMode', false ) ){
			return variables.customServerDirectory & 'serverHome';
		} else {
			return variables.customServerDirectory & arguments.serverinfo.id & "-" & arguments.serverInfo.name;
		}
	}

	/**
	 * Get a random port for the specified host
	 * @host.hint host to get port on, defaults 127.0.0.1
 	 **/
	function getRandomPort( host="127.0.0.1" ){
		try {
			var nextAvail  = java.ServerSocket.init( javaCast( "int", 0 ),
													 javaCast( "int", 1 ),
													 java.InetAddress.getByName( arguments.host ) );
			var portNumber = nextAvail.getLocalPort();
			nextAvail.close();
		} catch( java.net.UnknownHostException var e ) {
			throw( "The host name [#arguments.host#] can't be found. Do you need to add a host file entry?", 'serverException', e.message & ' ' & e.detail );
		} catch( java.net.BindException var e ) {
			// Same as above-- the IP address/host isn't bound to any local adapters.  Probably a host file entry went missing.
			throw( "The IP address that [#arguments.host#] resolves to can't be bound.  If you ping it, does it point to a local network adapter?", 'serverException', e.message & ' ' & e.detail );
		}

		return portNumber;
	}

	/**
	 * Find out if a given host/port is already bound
	 * @host.hint host to test port on, defaults 127.0.0.1
 	 **/
	function isPortAvailable( host="127.0.0.1", required port ){
		try {
			var serverSocket = java.serverSocket
				.init(
					javaCast( "int", arguments.port ),
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
			if( e.message contains 'Cannot assign requested address' || e.message contains 'Can''t assign requested address' ) {
				return true;
			}
			if( e.message contains 'Permission denied' ) {
				consoleLogger.debug( e.message);
				consoleLogger.error( "Permission to bind the port was denied. This likely means you need to run as root or pick a port above 1024.");
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
		var portToCheck = serverInfo.stopSocket;
		if( serverInfo.HTTPEnable ) {
			portToCheck = serverInfo.port;
		} else if( serverInfo.SSLEnable ) {
			portToCheck = serverInfo.SSLPort;
		} else if( serverInfo.AJPEnable ) {
			portToCheck = serverInfo.AJPPort;
		}

		lock name="server-status-check-#portToCheck#" type="exclusive"{
			return !isPortAvailable( serverInfo.host, portToCheck );
		}
	}

	/**
	 * persist server info
	 * @serverInfo.hint struct of server info (ports, etc.)
 	 **/
	function setServerInfo( required struct serverInfo ){
		var servers 	= getServers();
		var serverID = calculateServerID( arguments.serverInfo.webroot, arguments.serverInfo.name );

		arguments.serverInfo.id = serverID;

		if( arguments.serverInfo.webroot == "" ){
			throw( "The webroot cannot be empty!" );
		}

		servers[ serverID ] = serverInfo;

		// persist back safely
		setServers( servers );

	}

	function calculateServerID( webroot, name ) {

		if( ConfigService.getSetting( 'server.singleServerMode', false ) ){
			return 'serverHome';
		}
		var normalizedWebroot = normalizeWebroot( webroot );
		return hash( normalizedWebroot & ucase( name ) );
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
		fileSystemUtil.lockingFileWrite( serverConfig, '{}' );
	}

	/**
	 * persist servers
	 * @servers.hint struct of serverInfos
 	 **/
	ServerService function setServers( required Struct servers ){
		JSONService.writeJSONFile( serverConfig, servers, true );
		return this;
	}

	/**
	* get servers struct from config file on disk
 	**/
	struct function getServers() {
		if( fileExists( variables.serverConfig ) ){
			var results = deserializeJSON( fileSystemUtil.lockingfileRead( variables.serverConfig ) );
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
					thisServer.id = calculateServerID( thisServer.webroot, thisServer.name );
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

		if( ConfigService.getSetting( 'server.singleServerMode', false ) && getServers().count() ){
			return getFirstServer();
		}

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

		if( ConfigService.getSetting( 'server.singleServerMode', false ) && getServers().count() ){
			return getFirstServer();
		}

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

		if( ConfigService.getSetting( 'server.singleServerMode', false ) && getServers().count() ){
			return getFirstServer();
		}

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

		if( ConfigService.getSetting( 'server.singleServerMode', false ) && getServers().count() ){
			return getFirstServer();
		}

		arguments.webroot = fileSystemUtil.resolvePath( arguments.webroot );
		var servers = getServers();
		for( var thisServer in servers ){
			if( fileSystemUtil.resolvePath( path=servers[ thisServer ].webroot, forceDirectory=true ) == arguments.webroot ){
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
		var serverID = calculateServerID( arguments.webroot, arguments.name );
		var statusInfo 	= {};

		if( !directoryExists( arguments.webroot ) ){
			statusInfo = { result:"Webroot does not exist, cannot start :" & arguments.webroot };
		}

		if( isNull( servers[ serverID ] ) ){
			// prepare new server info
			var serverInfo 		= newServerInfoStruct();
			serverInfo.id 		= serverID;
			serverInfo.webroot 	= arguments.webroot;
			serverInfo.name 	= arguments.name;

			// Don't overlap an existing server name
			var originalName = serverInfo.name;
			var nameCounter = 1;
			while( structCount( getServerInfoByName( serverInfo.name ) ) ) {
				serverInfo.name = originalName & ++nameCounter;
				serverID = calculateServerID( arguments.webroot, serverInfo.name );
			}

			// Store it in server struct
			servers[ serverID ] = serverInfo;
		}

		// Return the new record
		return servers[ serverID ];
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
			'verbose'			: false,
			'trace'				: false,
			'console'			: false,
			'status'			: "stopped",
			'statusInfo'		: {
				'result' 	: "",
				'arguments' : "",
				'command' 	: ""
			},
			'name'				: "",
			'logDir' 			: "",
			'consolelogPath'	: "",
			'accessLogPath'		: "",
			'rewritesLogPath'	: "",
			'trayicon' 			: "",
			'libDirs' 			: "",
			'webConfigDir' 		: "",
			'serverConfigDir' 	: "",
			'serverHomeDirectory' : "",
			'serverHome'		 : "",
			'webroot'			: "",
			'webXML' 			: "",
			'HTTPEnable'		: true,
			'SSLEnable'			: false,
			'SSLPort'			: 1443,
			'AJPEnable'			: false,
			'AJPPort'			: 8009,
			'SSLCertFile'		: "",
			'SSLKeyFile'		: "",
			'SSLKeyPass'		: "",
			'rewritesEnable'	: false,
			'rewritesConfig'	: "",
			'rewritesStatusPath': "",
			'rewritesConfigReloadSeconds'	: "",
			'basicAuthEnable'	: true,
			'basicAuthUsers'	: {},
			'heapSize'			: '',
			'minHeapSize'		: '',
			'javaHome'			: '',
			'javaVersion'		: '',
			'directoryBrowsing' : false,
			'JVMargs'			: "",
			'runwarArgs'		: "",
			'runwarXNIOOptions'	: {},
			'runwarUndertowOptions'	: {},
			'cfengine'			: "",
			'restMappings'		: "",
			'sessionCookieSecure'	: false,
			'sessionCookieHTTPOnly'	: false,
			'engineName'		: "",
			'engineVersion'		: "",
			'WARPath'			: "",
			'serverConfigFile'	: "",
			'aliases'			: {},
			'errorPages'		: {},
			'accessLogEnable'	: false,
			'GZipEnable'		: true,
			'GZipPredicate'		: '',
			'rewritesLogEnable'	: false,
			'trayOptions'		: {},
			'trayEnable'		: true,
			'dockEnable'		: true,
			'dateLastStarted'	: '',
			'openBrowser'		: true,
			'openBrowserURL'	: '',
			'profile'			: '',
			'customServerFolder': '',
			'welcomeFiles'		: '',
			'maxRequests'		: '',
			'exitCode'			: 0,
			'rules'				: [],
			'rulesFile'			: '',
			'blockCFAdmin'		: false,
			'blockSensitivePaths'	: false,
			'blockFlashRemoting'	: false,
			'allowedExt'		: ''
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
				throw( message='File is not valid JSON. [#path#].  Operation aborted.', type="commandException");
			}
		} else {
			return {};
		}
	}

	/**
	* Save a server.json file.
	*/
	function saveServerJSON( required string configFilePath, required struct data ) {
		JSONService.writeJSONFile( configFilePath, data );
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
	
		
	/**
	* Loads config settings from env vars or Java system properties
	*/
	function loadOverrides( serverJSON, serverInfo ){
		var overrides={};
		
		// Look for individual BOX settings to import.		
		var processVarsUDF = function( envVar, value ) {
			// Loop over any that look like box_server_xxx
			if( envVar.len() > 11 && left( envVar, 11 ) == 'box_server_' ) {
				// proxy_host gets turned into proxy.host
				// Note, the asssumption is made that no config setting will ever have a legitimate underscore in the name
				var name = right( envVar, len( envVar ) - 11 ).replace( '_', '.', 'all' );
				JSONService.set( JSON=overrides, properties={ '#name#' : value }, thisAppend=true );
			}
		};
		
		// Get all OS env vars
		var envVars = system.getenv();
		for( var envVar in envVars ) {
			processVarsUDF( envVar, envVars[ envVar ] );
		}
		
		// Get all System Properties
		var props = system.getProperties();
		for( var prop in props ) {
			processVarsUDF( prop, props[ prop ] );
		}

		// Get all box environemnt variable
		var envVars = systemSettings.getAllEnvironmentsFlattened();
		for( var envVar in envVars ) {
			processVarsUDF( envVar, envVars[ envVar ] );
		}
	
		if( overrides.keyExists( 'profile' ) ) {
			serverInfo.envVarHasProfile=true
		}
	
		JSONService.mergeData( serverJSON, overrides );
	}

}

