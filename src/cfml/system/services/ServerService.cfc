/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant, Scott Steinbeck
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
	property name='rootLogger'				inject='logbox:root';
	property name='wirebox'					inject='wirebox';
	property name='CR'						inject='CR@constants';
	property name='parser'					inject='parser';
	property name='systemSettings'			inject='SystemSettings';
	property name='javaService'				inject='provider:javaService';
	property name='ansiFormatter'			inject='AnsiFormatter';
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
		variables.java = {
			ServerSocket 	: createObject( "java", "java.net.ServerSocket" ),
			File 			: createObject( "java", "java.io.File" ),
			Socket	 		: createObject( "java", "java.net.Socket" ),
			InetAddress 	: createObject( "java", "java.net.InetAddress" ),
			LaunchUtil 		: createObject( "java", "runwar.LaunchUtil" ),
			TimeUnit		: createObject( "java", "java.util.concurrent.TimeUnit" )
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
			'preferredBrowser' : d.preferredBrowser ?: '',
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
			// Only default this on for Windows-- off for Linux and Mac due to crap unfixed bugs in the
			// upstream Java library. https://github.com/dorkbox/SystemTray/issues/119
			'trayEnable' : d.trayEnable ?: fileSystemUtil.isWindows(),
			'dockEnable' : d.dockEnable ?: true,
			'profile'	: d.profile ?: '',
			'jvm' : {
				'heapSize' : d.jvm.heapSize ?: '',
				'minHeapSize' : d.jvm.minHeapSize ?: '',
				'args' : d.jvm.args ?: '',
				'javaHome' : d.jvm.javaHome ?: '',
				'javaVersion' : d.jvm.javaVersion ?: '',
				'properties' : d.jvm.properties ?: {}
			},
			'sites' : duplicate( d.sites ?: [:] ),
			'siteConfigFiles' : d.siteConfigFiles ?: '',
			'web' : {
				'host' : d.web.host ?: '127.0.0.1',
				'hostAlias' : d.web.hostAlias ?: '',
				'directoryBrowsing' : d.web.directoryBrowsing ?: '',
				'webroot' : d.web.webroot ?: '',
				'caseSensitivePaths' : d.web.caseSensitivePaths ?: '',
				// Duplicate so onServerStart interceptors don't actually change config settings via reference.
				'aliases' : duplicate( d.web.aliases ?: {} ),
				// Duplicate so onServerStart interceptors don't actually change config settings via reference.
				'errorPages' : duplicate( d.web.errorPages ?: {} ),
				'accessLogEnable' : d.web.accessLogEnable ?: false,
				'GZIPEnable' : d.web.GZIPEnable ?: true,
				'gzipPredicate' : d.web.gzipPredicate ?: '',
				'welcomeFiles' : d.web.welcomeFiles ?: '',
				'maxRequests' : d.web.maxRequests ?: '',
				// TODO: override each binding key individually?
				'bindings' : duplicate( d.web.bindings ?: {} ),
				'HTTP' : {
					'port' : d.web.http.port ?: 0,
					'enable' : d.web.http.enable ?: nullvalue()
				},
				'HTTP2' : {
					'enable' : d.web.HTTP2.enable ?: true
				},
				'SSL' : {
					'enable' : d.web.ssl.enable ?: false,
					'port' : d.web.ssl.port ?: 1443,
					'certFile' : d.web.ssl.certFile ?: '',
					'keyFile' : d.web.ssl.keyFile ?: '',
					'keyPass' : d.web.ssl.keyPass ?: '',
					'forceSSLRedirect' : d.web.ssl.forceSSLRedirect ?: false,
					'HSTS' : {
						'enable' : d.web.ssl.hsts.enable ?: false,
						'maxAge' : d.web.ssl.hsts.maxAge ?:  31536000,
						'includeSubDomains' : d.web.ssl.hsts.includeSubDomains ?: false
					},
					'clientCert' : {
						'mode' : d.web.ssl.clientCert.mode ?:  '',
						'CACertFiles' : d.web.ssl.clientCert.CACertFiles ?: '',
						'CATrustStoreFile' : d.web.ssl.clientCert.CATrustStoreFile ?: '',
						'CATrustStorePass' : d.web.ssl.clientCert.CATrustStorePass ?: ''
					}
				},
				'AJP' : {
					'enable' : d.web.ajp.enable ?: false,
					'port' : d.web.ajp.port ?: 8009,
					'secret' : d.web.ajp.secret ?: ''
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
				'fileCache' : {
					'enable' : d.web.fileCache.enable ?: '',
					'totalSizeMB' : d.web.fileCache.totalSizeMB ?: 50,
					'maxFileSizeKB' : d.web.fileCache.maxFileSizeKB ?: 50
				},
				'rules' : duplicate( d.web.rules ?: [] ),
				'rulesFile' : duplicate( d.web.rulesFile ?: [] ),
				'blockCFAdmin' : d.web.blockCFAdmin ?: '',
				'blockSensitivePaths' :  d.web.blockSensitivePaths ?: '',
				'blockFlashRemoting' :  d.web.blockFlashRemoting ?: '',
				'allowedExt' : d.web.allowedExt ?: '',
				'useProxyForwardedIP' : d.web.useProxyForwardedIP ?: false,
				'security' : {
					'realm' : d.web.security.realm ?: '',
					'authPredicate' : d.web.security.authPredicate ?: '',
					'basicAuth' : {
						'enable' : d.web.security.basicAuth.enable ?: nullvalue(),
						'users' : d.web.security.basicAuth.users ?: nullvalue()
					},
					'clientCert' : {
						'enable' : d.web.security.clientCert.enable ?: false,
						'SSLRenegotiationEnable' : d.web.security.clientCert.SSLRenegotiationEnable ?:  false,
						'trustUpstreamHeaders' : d.web.security.clientCert.trustUpstreamHeaders ?: false,
						'subjectDNs' : d.web.security.clientCert.subjectDNs ?: '',
						'issuerDNs' : d.web.security.clientCert.issuerDNs ?: ''
					}
				},
				'mimeTypes' : duplicate( d.web.mimeTypes ?: {} ),
				'bindings' : duplicate( d.web.bindings ?: {} )
			},
			'app' : {
				'logDir' : d.app.logDir ?: '',
				'libDirs' : d.app.libDirs ?: '',
				'webConfigDir' : d.app.webConfigDir ?: '',
				'serverConfigDir' : d.app.serverConfigDir ?: '',
				'webXMLOverride' : d.app.webXMLOverride ?: '',
				'webXMLOverrideForce' : d.app.webXMLOverrideForce ?: false,
				'standalone' : d.app.standalone ?: false,
				'WARPath' : d.app.WARPath ?: '',
				'cfengine' : d.app.cfengine ?: '',
				'restMappings' : d.app.cfengine ?: '',
				'serverHomeDirectory' : d.app.serverHomeDirectory ?: '',
				'singleServerHome' : d.app.singleServerHome ?: false,
				'sessionCookieSecure' : d.app.sessionCookieSecure ?: false,
				'sessionCookieHTTPOnly' : d.app.sessionCookieHTTPOnly ?: false,
				'customHTTPStatusEnable' : d.app.customHTTPStatusEnable ?: true
			},
			'runwar' : {
				'jarPath' : d.runwar.jarPath ?: variables.jarPath,
				'args' : d.runwar.args ?: '',
				// Duplicate so onServerStart interceptors don't actually change config settings via reference.
				'XNIOOptions' : duplicate( d.runwar.XNIOOptions ?: {} ),
				// Duplicate so onServerStart interceptors don't actually change config settings via reference.
				'undertowOptions' : duplicate( d.runwar.undertowOptions ?: {} ),
				'console' : {
					'appenderLayout' : d.runwar.console.appenderLayout ?: '',
					'appenderLayoutOptions' : duplicate( d.runwar.console.appenderLayoutOptions ?: {} )
				}
			},
			'ModCFML' : {
				'enable' : d.ModCFML.enable ?: false,
				'maxContexts' : d.ModCFML.maxContexts ?: 200,
				'sharedKey' : d.ModCFML.sharedKey ?: '',
				'requireSharedKey' : d.ModCFML.requireSharedKey ?: true,
				'createVirtualDirectories' : d.ModCFML.createVirtualDirectories ?: true
			},
			'scripts' : d.scripts ?: {}
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


		var foundServer = getServerInfoByName( serverDetails.defaultName );
		if( !isSingleServerMode() && structCount( foundServer ) && normalizeWebroot( foundServer.webroot ) != normalizeWebroot( serverDetails.defaultwebroot ) ) {
			throw(
				message='You''ve asked to start a server named [#serverDetails.defaultName#] with a webroot of [#serverDetails.defaultwebroot#], but a server of this name already exists with a different webroot of [#foundServer.webroot#]',
				detail='Server name and webroot must be unique.  Please forget the old server first.  Use "server list" to see all defined servers.',
				type="commandException"
			 );
		}


		// Get defaults
		var defaults = getDefaultServerJSON();
		var defaultName = serverDetails.defaultName;
		var defaultwebroot = serverDetails.defaultwebroot;
		var defaultServerConfigFile = serverDetails.defaultServerConfigFile;
		var defaultServerConfigFileDirectory = getDirectoryFromPath( defaultServerConfigFile );
		var serverJSON = serverDetails.serverJSON;
		var serverJSONToSave = duplicate( serverJSON );
		var serverInfo = serverDetails.serverinfo;

		interceptorService.announceInterception( 'preServerStart', { serverDetails=serverDetails, serverProps=serverProps, serverInfo=serverDetails.serverInfo, serverJSON=serverDetails.serverJSON, defaults=defaults } );

		// In case the interceptor changed them
		defaultName = serverDetails.defaultName;
		defaultwebroot = serverDetails.defaultwebroot;
		defaultServerConfigFile = serverDetails.defaultServerConfigFile;
		defaultServerConfigFileDirectory = getDirectoryFromPath( defaultServerConfigFile );

		systemSettings.expandDeepSystemSettings( serverJSON );
		systemSettings.expandDeepSystemSettings( defaults );

		// Mix in environment variable overrides like BOX_SERVER_PROFILE
		loadOverrides( serverJSON, serverInfo, serverProps.verbose ?: serverProps.debug ?: serverJSON.verbose ?: defaults.verbose ?: false );

		// Load up our fully-realized server.json-specific env vars into CommandBox's environment
		systemSettings.setDeepSystemSettings( serverDetails.serverJSON.env ?: {}, '', '_' );

		// If the server is already running, make sure the user really wants to do this.
		if( isServerRunning( serverInfo ) && !(serverProps.force ?: false ) && !(serverProps.dryRun ?: false ) ) {

			if( !shell.isTerminalInteractive() || isSingleServerMode() ) {
				throw( message="Cannot start server [#serverInfo.name#] because it is already running.", detail="Run [server info --verbose] to find out why CommandBox thinks this server is running.", type="commandException" );
			}

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
				job.error( 'Aborting...' );
				shell.callCommand( 'server open', false);
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
					serverJSONToSave[ 'web' ][ 'http' ][ 'port' ] = serverProps[ prop ];
			         break;
			    case "host":
					serverJSONToSave[ 'web' ][ 'host' ] = serverProps[ prop ];
			         break;
			    case "directory":
			    	// This path is canonical already.
			    	var thisDirectory = replace( serverProps[ 'directory' ], '\', '/', 'all' ) & '/';
			    	// If the web root is south of the server's JSON, make it relative for better portability.
			    	if( thisDirectory contains configPath ) {
			    		thisDirectory = replaceNoCase( thisDirectory, configPath, '' );
			    	}
					serverJSONToSave[ 'web' ][ 'webroot' ] = thisDirectory;
			         break;
			    case "trayEnable":
					serverJSONToSave[ 'trayEnable' ] = serverProps[ prop ];
			         break;
			    case "trayIcon":
			    	// This path is canonical already.
			    	var thisFile = replace( serverProps[ 'trayIcon' ], '\', '/', 'all' );
			    	// If the trayIcon is south of the server's JSON, make it relative for better portability.
			    	if( thisFile contains configPath ) {
			    		thisFile = replaceNoCase( thisFile, configPath, '' );
			    	}
					serverJSONToSave[ 'trayIcon' ] = thisFile;
			         break;
			    case "stopPort":
					serverJSONToSave[ 'stopsocket' ] = serverProps[ prop ];
			         break;
			    case "webConfigDir":
			    	// This path is canonical already.
			    	var thisDirectory = replace( serverProps[ 'webConfigDir' ], '\', '/', 'all' ) & '/';
			    	// If the webConfigDir is south of the server's JSON, make it relative for better portability.
			    	if( thisDirectory contains configPath ) {
			    		thisDirectory = replaceNoCase( thisDirectory, configPath, '' );
			    	}
					serverJSONToSave[ 'app' ][ 'webConfigDir' ] = thisDirectory;
			        break;
			    case "serverConfigDir":
			    	// This path is canonical already.
			    	var thisDirectory = replace( serverProps[ 'serverConfigDir' ], '\', '/', 'all' ) & '/';
			    	// If the webConfigDir is south of the server's JSON, make it relative for better portability.
			    	if( thisDirectory contains configPath ) {
			    		thisDirectory = replaceNoCase( thisDirectory, configPath, '' );
			    	}
					serverJSONToSave[ 'app' ][ 'serverConfigDir' ] = thisDirectory;
			         break;
			    case "libDirs":
					serverJSONToSave[ 'app' ][ 'libDirs' ] = serverProps[ 'libDirs' ]
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
					serverJSONToSave[ 'app' ][ 'cfengine' ] = serverProps[ prop ];
			         break;
			    case "restMappings":
					serverJSONToSave[ 'app' ][ 'restMappings' ] = serverProps[ prop ];
			         break;
			    case "WARPath":
			    	// This path is canonical already.
			    	var thisFile = replace( serverProps[ 'WARPath' ], '\', '/', 'all' );
			    	// If the trayIcon is south of the server's JSON, make it relative for better portability.
			    	if( thisFile contains configPath ) {
			    		thisFile = replaceNoCase( thisFile, configPath, '' );
			    	}
					serverJSONToSave[ 'app' ][ 'WARPath' ] = thisFile;
			         break;
			    case "serverHomeDirectory":
			    	// This path is canonical already.
			    	var thisDirectory = replace( serverProps[ 'serverHomeDirectory' ], '\', '/', 'all' ) & '/';
			    	// If the webConfigDir is south of the server's JSON, make it relative for better portability.
			    	if( thisDirectory contains configPath ) {
			    		thisDirectory = replaceNoCase( thisDirectory, configPath, '' );
			    	}
					serverJSONToSave[ 'app' ][ 'serverHomeDirectory' ] = thisDirectory;
			        break;
			    case "HTTPEnable":
					serverJSONToSave[ 'web' ][ 'HTTP' ][ 'enable' ] = serverProps[ prop ];
			         break;
			    case "SSLEnable":
					serverJSONToSave[ 'web' ][ 'SSL' ][ 'enable' ] = serverProps[ prop ];
			         break;
			    case "SSLPort":
					serverJSONToSave[ 'web' ][ 'SSL' ][ 'port' ] = serverProps[ prop ];
			         break;
			    case "AJPEnable":
					serverJSONToSave[ 'web' ][ 'AJP' ][ 'enable' ] = serverProps[ prop ];
			         break;
			    case "AJPPort":
					serverJSONToSave[ 'web' ][ 'AJP' ][ 'port' ] = serverProps[ prop ];
			         break;
			    case "SSLCertFile":
					serverJSONToSave[ 'web' ][ 'SSL' ][ 'certFile' ] = serverProps[ prop ];
			         break;
			    case "SSLKeyFile":
					serverJSONToSave[ 'web' ][ 'SSL' ][ 'keyFile' ] = serverProps[ prop ];
			         break;
			    case "SSLKeyPass":
					serverJSONToSave[ 'web' ][ 'SSL' ][ 'keyPass' ] = serverProps[ prop ];
			         break;
			    case "welcomeFiles":
					serverJSONToSave[ 'web' ][ 'welcomeFiles' ] = serverProps[ prop ];
			         break;
			    case "rewritesEnable":
					serverJSONToSave[ 'web' ][ 'rewrites' ][ 'enable' ] = serverProps[ prop ];
			         break;
			    case "rewritesConfig":
			    	// This path is canonical already.
			    	var thisFile = replace( serverProps[ 'rewritesConfig' ], '\', '/', 'all' );
			    	// If the trayIcon is south of the server's JSON, make it relative for better portability.
			    	if( thisFile contains configPath ) {
			    		thisFile = replaceNoCase( thisFile, configPath, '' );
			    	}
					serverJSONToSave[ 'web' ][ 'rewrites' ][ 'config' ] = thisFile;
			         break;
			    case "blockCFAdmin":
					serverJSONToSave[ 'web' ][ 'blockCFAdmin' ] = serverProps[ prop ];
			         break;
			    case "heapSize":
					serverJSONToSave[ 'JVM' ][ 'heapSize' ] = serverProps[ prop ];
			         break;
			    case "minHeapSize":
					serverJSONToSave[ 'JVM' ][ 'minHeapSize' ] = serverProps[ prop ];
			         break;
			    case "JVMArgs":
					serverJSONToSave[ 'JVM' ][ 'args' ] = serverProps[ prop ];
			         break;
			    case "javaHomeDirectory":
					serverJSONToSave[ 'JVM' ][ 'javaHome' ] = serverProps[ prop ];
			         break;
			    case "javaVersion":
					serverJSONToSave[ 'JVM' ][ 'javaVersion' ] = serverProps[ prop ];
			         break;
				case "runwarJarPath":
					serverJSONToSave[ 'runwar' ][ 'jarPath' ] = serverProps[ prop ];
					 break;
			    case "runwarArgs":
					serverJSONToSave[ 'runwar' ][ 'args' ] = serverProps[ prop ];
			         break;
			    default:
					serverJSONToSave[ prop ] = serverProps[ prop ];
			} // end switch
		} // for loop

		if( !serverJSONToSave.isEmpty() && serverProps.saveSettings ) {
			saveServerJSON( defaultServerConfigFile, serverJSONToSave );
		}

		// These are already hammered out above, so no need to go through all the defaults.
		serverInfo.serverConfigFile	= defaultServerConfigFile;
		serverInfo.name 			= defaultName;
		serverInfo.webroot 			= normalizeWebroot( defaultwebroot );

		// Setup serverinfo according to params
		// Hand-entered values take precedence, then settings saved in server.json, and finally defaults.
		// The big servers.json is only used to keep a record of the last values the server was started with
		serverInfo.trace 			= serverProps.trace 			?: serverJSON.trace 				?: defaults.trace;
		serverInfo.debug 			= serverProps.debug 			?: serverJSON.debug 				?: defaults.debug;
		serverInfo.verbose 			= serverProps.verbose 			?: serverJSON.verbose 				?: defaults.verbose;
		serverInfo.console 			= serverProps.console 			?: serverJSON.console 				?: defaults.console;
		serverInfo.openbrowser		= serverProps.openbrowser 		?: serverJSON.openbrowser			?: defaults.openbrowser;

		serverInfo.openbrowserURL	= serverProps.openbrowserURL	?: serverJSON.openbrowserURL		?: defaults.openbrowserURL;
		serverInfo.preferredBrowser	= serverJSON.preferredBrowser	?: defaults.preferredBrowser;

		// Trace assumes debug
		serverInfo.debug = serverInfo.trace || serverInfo.debug;
		// Debug assumes verbose
		serverInfo.verbose = serverInfo.debug || serverInfo.verbose;

		if( serverInfo.verbose ) {
			job.setDumpLog( serverInfo.verbose );
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

		// relative trayIcon in server.json is resolved relative to the server.json
		if( serverJSON.keyExists( 'trayIcon' ) ) { serverJSON.trayIcon = fileSystemUtil.resolvePath( serverJSON.trayIcon, defaultServerConfigFileDirectory ); }
		// relative trayIcon in config setting server defaults is resolved relative to the web root
		if( defaults.keyExists( 'trayIcon' ) && len( defaults.trayIcon ) ) { defaults.trayIcon = fileSystemUtil.resolvePath( defaults.trayIcon, defaultwebroot ); }
		serverInfo.trayIcon			= serverProps.trayIcon 			?: serverJSON.trayIcon 				?: defaults.trayIcon;


/*
		// Double check that the port in the user params or server.json isn't in use
		if( serverInfo.HTTPEnable && !isPortAvailable( serverInfo.host, serverInfo.port ) ) {
			job.addErrorLog( "" );
			var badPortlocation = 'config';
			if( serverProps.keyExists( 'port' ) ) {
				badPortlocation = 'start params';
			} else if ( len( defaults.web.http.port ?: '' ) ) {
				badPortlocation = 'server.json';
			} else {
				badPortlocation = 'config server defaults';
			}
			throw( message="You asked for port [#serverInfo.port#] in your #badPortlocation# but it's already in use.", detail="Please choose another or use netstat to find out what process is using the port already.", type="commandException" );
		}
*/

		serverInfo.rewritesEnable 	= serverProps.rewritesEnable	?: serverJSON.web.rewrites.enable		?: defaults.web.rewrites.enable;
		serverInfo.rewritesStatusPath = 							   serverJSON.web.rewrites.statusPath	?: defaults.web.rewrites.statusPath;
		serverInfo.rewritesConfigReloadSeconds =					   serverJSON.web.rewrites.configReloadSeconds ?: defaults.web.rewrites.configReloadSeconds;

		// relative rewrite config path in server.json is resolved relative to the server.json
		if( isDefined( 'serverJSON.web.rewrites.config' ) ) { serverJSON.web.rewrites.config = fileSystemUtil.resolvePath( serverJSON.web.rewrites.config, defaultServerConfigFileDirectory ); }
		// relative rewrite config path in config setting server defaults is resolved relative to the web root
		if( isDefined( 'defaults.web.rewrites.config' ) ) { defaults.web.rewrites.config = fileSystemUtil.resolvePath( defaults.web.rewrites.config, defaultwebroot ); }
		serverInfo.rewritesConfig 	= serverProps.rewritesConfig 	?: serverJSON.web.rewrites.config 	?: defaults.web.rewrites.config;
		serverInfo.rewriteslogEnable = serverJSON.web.rewrites.logEnable ?: defaults.web.rewrites.logEnable;

		serverInfo.maxRequests = serverJSON.web.maxRequests			?: defaults.web.maxRequests;
		serverInfo.trayEnable	 	= serverProps.trayEnable		?: serverJSON.trayEnable			?: defaults.trayEnable;
		serverInfo.dockEnable	 	= serverJSON.dockEnable			?: defaults.dockEnable;
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
		// Then server defaults java version
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

		// Global defaults are always added on top of whatever is specified by the user or server.json
		serverInfo.JVMargsArray = [];
		serverInfo.JVMargs			= serverProps.JVMargs			?: '';
		if( !isNull( serverJSON.JVM.args ) && isArray( serverJSON.JVM.args ) ) {
			serverInfo.JVMargsArray.append( serverJSON.JVM.args, true );
		} else if( !isNull( serverJSON.JVM.args ) && isSimpleValue( serverJSON.JVM.args ) && len( serverJSON.JVM.args ) ) {
			serverInfo.JVMargs &= ' ' & serverJSON.JVM.args;
		}
		if( !isNull( defaults.JVM.args ) && isArray( defaults.JVM.args ) ) {
			serverInfo.JVMargsArray.append( defaults.JVM.args, true );
		} else if( !isNull( defaults.JVM.args ) && isSimpleValue( defaults.JVM.args ) && len( defaults.JVM.args ) ) {
			serverInfo.JVMargs &= ' ' & defaults.JVM.args;
		}

		// Global defaults are always added on top of whatever is specified by the user or server.json
		serverInfo.runwarJarPath	= serverProps.runwarJarPath		?: serverJSON.runwar.jarPath	?: defaults.runwar.jarPath;

		// Global defaults are always added on top of whatever is specified by the user or server.json
		serverInfo.runwarArgsArray = [];
		serverInfo.runwarArgs			= serverProps.runwarArgs			?: '';
		if( !isNull( serverJSON.runwar.args ) && isArray( serverJSON.runwar.args ) ) {
			serverInfo.runwarArgsArray.append( serverJSON.runwar.args, true );
		} else if( !isNull( serverJSON.runwar.args ) && isSimpleValue( serverJSON.runwar.args ) && len( serverJSON.runwar.args ) ) {
			serverInfo.runwarArgs &= ' ' & serverJSON.runwar.args;
		}
		if( !isNull( defaults.runwar.args ) && isArray( defaults.runwar.args ) ) {
			serverInfo.runwarArgsArray.append( defaults.runwar.args, true );
		} else if( !isNull( defaults.runwar.args ) && isSimpleValue( defaults.runwar.args ) && len( defaults.runwar.args ) ) {
			serverInfo.runwarArgs &= ' ' & defaults.runwar.args;
		}


		// Global defaults are always added on top of whatever is specified by the user or server.json
		serverInfo.runwarXNIOOptions	= ( serverJSON.runwar.XNIOOptions ?: {} ).append( defaults.runwar.XNIOOptions, true );

		// Global defaults are always added on top of whatever is specified by the user or server.json
		serverInfo.runwarUndertowOptions	= ( serverJSON.runwar.UndertowOptions ?: {} ).append( defaults.runwar.UndertowOptions, true );

		serverInfo.runwarAppenderLayout	= serverJSON.runwar.console.appenderLayout ?: defaults.runwar.console.appenderLayout;
		serverInfo.runwarAppenderLayoutOptions = serverJSON.runwar.console.appenderLayoutOptions ?: defaults.runwar.console.appenderLayoutOptions;


		// Server startup timeout
		serverInfo.startTimeout		= serverProps.startTimeout 			?: serverJSON.startTimeout 	?: defaults.startTimeout;

		serverInfo.JVMProperties =	serverJSON.JVM.properties		?: {};
		serverInfo.JVMProperties.append( defaults.jvm.properties, false );

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
			// listReduce starts with an initial value of "" and aggregates the new list, only appending the items it wants to keep
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


		serverInfo.cfengine			= serverProps.cfengine			?: serverJSON.app.cfengine			?: defaults.app.cfengine;
		serverInfo.cfengineSource = 'defaults';
		if( !isNull( serverJSON.app.cfengine ) ) {
			serverInfo.cfengineSource = 'serverJSON';
		}
		if( !isNull( serverProps.cfengine ) ) {
			serverInfo.cfengineSource = 'serverProps';
		}

		serverInfo.restMappings		= serverProps.restMappings		?: serverJSON.app.restMappings		?: defaults.app.restMappings;
		// relative rewrite config path in server.json is resolved relative to the server.json
		if( isDefined( 'serverJSON.app.WARPath' ) ) { serverJSON.app.WARPath = fileSystemUtil.resolvePath( serverJSON.app.WARPath, defaultServerConfigFileDirectory ); }
		if( isDefined( 'defaults.app.WARPath' ) && len( defaults.app.WARPath )  ) { defaults.app.WARPath = fileSystemUtil.resolvePath( defaults.app.WARPath, defaultwebroot ); }
		serverInfo.WARPath			= serverProps.WARPath			?: serverJSON.app.WARPath			?: defaults.app.WARPath;

		// relative rewrite config path in server.json is resolved relative to the server.json
		if( isDefined( 'serverJSON.app.serverHomeDirectory' ) && len( serverJSON.app.serverHomeDirectory ) ) { serverJSON.app.serverHomeDirectory = fileSystemUtil.resolvePath( serverJSON.app.serverHomeDirectory, defaultServerConfigFileDirectory ); }
		if( isDefined( 'defaults.app.serverHomeDirectory' ) && len( defaults.app.serverHomeDirectory )  ) { defaults.app.serverHomeDirectory = fileSystemUtil.resolvePath( defaults.app.serverHomeDirectory, defaultwebroot ); }
		serverInfo.serverHomeDirectory			= serverProps.serverHomeDirectory			?: serverJSON.app.serverHomeDirectory			?: defaults.app.serverHomeDirectory;
		serverInfo.singleServerHome				= serverJSON.app.singleServerHome			?: defaults.app.singleServerHome;

		if( len( serverJSON.app.webXMLOverride ?: '' ) ){ serverJSON.app.webXMLOverride = fileSystemUtil.resolvePath( serverJSON.app.webXMLOverride, defaultServerConfigFileDirectory ); }
		if( len( defaults.app.webXMLOverride ?: '' ) ){ defaults.app.webXMLOverride = fileSystemUtil.resolvePath( defaults.app.webXMLOverride, defaultwebroot ); }
		serverInfo.webXMLOverride	= serverJSON.app.webXMLOverride	?: defaults.app.webXMLOverride;
		if( len( serverInfo.webXMLOverride ) && !fileExists( serverInfo.webXMLOverride ) ) {
			job.error( 'webXMLOverride file not found [#serverInfo.webXMLOverride#]' );
			return;
		}

		serverInfo.webXMLOverrideForce = serverJSON.app.webXMLOverrideForce ?: defaults.app.webXMLOverrideForce;

		serverInfo.sessionCookieSecure			= serverJSON.app.sessionCookieSecure			?: defaults.app.sessionCookieSecure;
		serverInfo.sessionCookieHTTPOnly		= serverJSON.app.sessionCookieHTTPOnly			?: defaults.app.sessionCookieHTTPOnly;
		serverInfo.customHTTPStatusEnable		= serverJSON.app.customHTTPStatusEnable			?: defaults.app.customHTTPStatusEnable;

		serverInfo.ModCFMLenable				= serverJSON.ModCFML.enable						?: defaults.ModCFML.enable;
		serverInfo.ModCFMLMaxContexts			= serverJSON.ModCFML.maxContexts				?: defaults.ModCFML.maxContexts;
		serverInfo.ModCFMLSharedKey				= serverJSON.ModCFML.sharedKey					?: defaults.ModCFML.sharedKey;
		serverInfo.ModCFMLRequireSharedKey		= serverJSON.ModCFML.requireSharedKey			?: defaults.ModCFML.requireSharedKey;
		serverInfo.ModCFMLcreateVDirs			= serverJSON.ModCFML.createVirtualDirectories	?: defaults.ModCFML.createVirtualDirectories;

		serverInfo.multiContext = serverInfo.ModCFMLenable;

		if( serverInfo.rewritesEnable ){
			if( !fileExists(serverInfo.rewritesConfig) ){
				job.error( 'URL rewrite config not found [#serverInfo.rewritesConfig#]' );
				return;
			}
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
	    var serverInfo.engineName = '';
	    serverInfo.engineName = serverinfo.cfengine contains 'lucee' ? 'lucee' : serverInfo.engineName;
	    serverInfo.engineName = serverinfo.cfengine contains 'railo' ? 'railo' : serverInfo.engineName;
	    serverInfo.engineName = serverinfo.cfengine contains 'adobe' ? 'adobe' : serverInfo.engineName;
	    serverInfo.engineName = serverinfo.warPath contains 'adobe' ? 'adobe' : serverInfo.engineName;

		var processName = ( serverInfo.name is "" ? "CommandBox" : serverInfo.name );

	    // As long as there's no WAR Path, let's install the engine to use.
		if( serverInfo.WARPath == '' ){
			// This will install the engine war to start, possibly downloading it first
			var installDetails = serverEngineService.install( cfengine=serverInfo.cfengine, basedirectory=serverinfo.customServerFolder, serverInfo=serverInfo, serverHomeDirectory=serverInfo.serverHomeDirectory );

			// If we couldn't guess the engine type above, give it another go.  Perhaps the box.json in the CF Engine gave us a clue.
			// This happens then starting like so
			// start cfengine=http://hostname/rest/update/provider/forgebox/5.3.4.54-rc
			// Because the cfengine value doesn't actually contain "lucee" but the box.json in the download will tell us
			if( !len( serverInfo.engineName ) ) {
			    serverInfo.engineName = installDetails.engineName contains 'lucee' ? 'lucee' : serverInfo.engineName;
			    serverInfo.engineName = installDetails.engineName contains 'railo' ? 'railo' : serverInfo.engineName;
			    serverInfo.engineName = installDetails.engineName contains 'adobe' ? 'adobe' : serverInfo.engineName;
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
			interceptorService.announceInterception( 'onServerInstall', { serverInfo=serverInfo, installDetails=installDetails, serverJSON=serverJSON, defaults=defaults, serverProps=serverProps, serverDetails=serverDetails } );
			if( installDetails.initialInstall ) {
				interceptorService.announceInterception( 'onServerInitialInstall', { serverInfo=serverInfo, installDetails=installDetails, serverJSON=serverJSON, defaults=defaults, serverProps=serverProps, serverDetails=serverDetails } );
			}

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
			serverInfo.processName = ( serverInfo.name is "" ? "CommandBox" : serverInfo.name ) & ' [' & listFirst( serverinfo.cfengine, '@' ) & ' ' & installDetails.version & ']';
			var displayServerName = ( serverInfo.name is "" ? "CommandBox" : serverInfo.name );
			var displayEngineName = serverInfo.engineName & ' ' & installDetails.version;
			serverInfo.pidfile = serverInfo.serverHomeDirectory & '/.pid.txt';
			//serverInfo.predicateFile = serverinfo.serverHomeDirectory & '/.predicateFile.txt';
			serverInfo.trayOptionsFile = serverinfo.serverHomeDirectory & '/.trayOptions.json';

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
			serverInfo.accessLogBaseDir = serverInfo.logDir;
			serverInfo.pidfile = serverInfo.customServerFolder & '/.pid.txt';
			//serverInfo.predicateFile = serverinfo.customServerFolder & '/.predicateFile.txt';
			serverInfo.trayOptionsFile = serverinfo.customServerFolder & '/.trayOptions.json';
			var displayServerName = serverInfo.processName;
			var displayEngineName = 'WAR';
		}

		serverInfo.accessLogBaseName = 'access';
		serverJSON.sites = serverJSON.sites ?: {};
		serverJSON.siteConfigFiles = serverJSON.siteConfigFiles ?: '';

		// Add in any sites defined by siteConfigFiles
		if( len( serverJSON.siteConfigFiles ) ) {
			if( isSimpleValue( serverJSON.siteConfigFiles ) ) {
				serverJSON.siteConfigFiles = serverJSON.siteConfigFiles.listToArray();
			}
			// For each globbing pattern
			serverJSON.siteConfigFiles.each((siteConfigFileGlob)=>{
				siteConfigFileGlob = fileSystemUtil.resolvePath( siteConfigFileGlob, defaultServerConfigFileDirectory );
				// If the setting points to a real directory, look for JSON files in there
				if( directoryExists( siteConfigFileGlob ) ) {
					siteConfigFileGlob &= '*.json'
				}
				wirebox.getInstance( 'Globber' )
					.setPattern( siteConfigFileGlob )
					.apply( (siteConfigFile)=>{
						// For each JSON file
						if( lCase( siteConfigFile ).endsWith( '.json' ) ) {
							var site = {};
							site.siteConfigFile = siteConfigFile;
							site.siteConfigFileDirectory = getDirectoryFromPath( site.siteConfigFile );

							var siteName = loadSiteConfig( site );
							serverJSON.sites[ siteName ] = site;
						}
					} );

			} );
		}

		// multi-site mode
		if( serverJSON.sites.count() ) {

			serverInfo.multiContext = true;
			serverInfo['sites' ] = [:];
			serverJSON.sites.each( ( siteName, site ) => {

				job.start( 'Configuring site [#siteName#]' );
				if( site.keyExists( 'webroot' ) ) {
					site.webroot = fileSystemUtil.resolvePath( site.webroot, defaultServerConfigFileDirectory );
				}

				site.serverConfigFileDirectory = defaultServerConfigFileDirectory;
				// If this site points to an external site config file, load and merge its settings
				if( len( site.siteConfigFile ?: '' ) ) {
					// If this site came from our siteCOnfigFiles above, no need to load it again
					if( !(site.__loaded ?: false ) ) {
						site.siteConfigFile = fileSystemUtil.resolvePath( site.siteConfigFile, defaultServerConfigFileDirectory );
						site.siteConfigFileDirectory = getDirectoryFromPath( site.siteConfigFile );
						loadSiteConfig( site, siteName );
					}
				// Otherwise, if we have a webroot, look for a .site.json file by convention in it
				} else if( len( site.webroot ?: '' ) ) {
					if( fileExists( site.webroot & '.site.json' ) ) {
						site.siteConfigFile = site.webroot & '.site.json';
						site.siteConfigFileDirectory = getDirectoryFromPath( site.siteConfigFile );
						loadSiteConfig( site, siteName );
					} else {
						// The config for this site came only from the server.json
						site.siteConfigFile = serverInfo.serverConfigFile;
						site.siteConfigFileDirectory = defaultServerConfigFileDirectory;
					}
				// Um, we have no idea what the web root for this site is!
				} else {
					throw( message='Site [#siteName#] is missing a "webroot" key.', type="commandException" );
				}

				var siteServerInfo = newSiteInfoStruct();
				if( !isNull( serverInfo.sites[ siteName ] ) ) {
					siteServerInfo.append( serverInfo.sites[ siteName ] );
				}
				// The two settings aren't strictly site/web-related but we need them in resolveSiteSettings()
				siteServerInfo.verbose = serverInfo.verbose;
				siteServerInfo.logDir = serverInfo.logDir;

				resolveSiteSettings( siteName, siteServerInfo, serverProps, serverJSON, duplicate( defaults ), true );
				serverInfo.sites[ siteName ] = siteServerInfo;

				job.complete( serverInfo.verbose );
			 } );

		} else {

			var site = serverJSON.sites[ serverInfo.name ] = [:];
			site.serverConfigFileDirectory = defaultServerConfigFileDirectory;
			site.siteConfigFileDirectory = defaultServerConfigFileDirectory;
			site.siteConfigFile = defaultServerConfigFile;
			site.webroot = serverInfo.webroot;

			var siteServerInfo = newSiteInfoStruct();
			if( !isNull( serverInfo.sites[ serverInfo.name ] ) ) {
				siteServerInfo.append( serverInfo.sites[ serverInfo.name ] );
			}
			siteServerInfo.verbose = serverInfo.verbose;
			siteServerInfo.logDir = serverInfo.logDir;
			resolveSiteSettings( serverInfo.name, siteServerInfo, serverProps, serverJSON, defaults, false );
			serverInfo['sites' ] = [
				'#serverInfo.name#'	: siteServerInfo
			];
			// Append these back to the top level for backwards compat
			serverInfo.append( siteServerInfo )
		}

		if( !serverInfo.HTTPEnable && !serverInfo.SSLEnable ) {
			serverInfo.openbrowser = false;
		}

		buildBindings( serverInfo );

		// Base this on the "first" site for now.
		var firstSite = serverInfo.sites[ serverInfo.sites.keyArray().last() ];
		serverInfo.defaultBaseURL = serverInfo.SSLEnable ? 'https://#firstSite.host#:#firstSite.SSLPort#' : 'http://#firstSite.host#:#firstSite.port#';

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


		// Doing this check here instead of the ServerEngineService so it can apply to existing installs
		if( serverInfo.engineName == 'adobe' ) {
			// Work around sketchy resolution of non-existent paths in Undertow
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
		serverInfo.accessLogPath = serverInfo.logDir & '/#serverInfo.accessLogBaseName#.txt';
		serverInfo.rewritesLogPath = serverInfo.logDir & '/rewrites.txt';


		// Find the correct tray icon for this server
		if( !len( serverInfo.trayIcon ) ) {
			var iconSize = fileSystemUtil.isWindows() ? '-32px' : '';
		    if( serverInfo.engineName contains "lucee" ) {
		    	serverInfo.trayIcon = '/commandbox/system/config/server-icons/trayicon-lucee#iconSize#.png';
			} else if( serverInfo.engineName contains "railo" ) {
		    	serverInfo.trayIcon = '/commandbox/system/config/server-icons/trayicon-railo#iconSize#.png';
			} else if( serverInfo.engineName contains "adobe" ) {

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
	    if( serverInfo.engineName contains "lucee" ) {
			openItems.prepend( { 'label':'Web Admin', 'action':'openbrowser', 'url':'#serverInfo.defaultBaseURL#/lucee/admin/web.cfm', 'image' : expandPath('/commandbox/system/config/server-icons/web_settings.png' ) } );
			openItems.prepend( { 'label':'Server Admin', 'action':'openbrowser', 'url':'#serverInfo.defaultBaseURL#/lucee/admin/server.cfm', 'image' : expandPath('/commandbox/system/config/server-icons/server_settings.png' ) } );
		} else if( serverInfo.engineName contains "railo" ) {
			openItems.prepend( { 'label':'Web Admin', 'action':'openbrowser', 'url':'#serverInfo.defaultBaseURL#/railo-context/admin/web.cfm', 'image' : expandPath('/commandbox/system/config/server-icons/web_settings.png' ) } );
			openItems.prepend( { 'label':'Server Admin', 'action':'openbrowser', 'url':'#serverInfo.defaultBaseURL#/railo-context/admin/server.cfm', 'image' : expandPath('/commandbox/system/config/server-icons/server_settings.png' ) } );
		} else if( serverInfo.engineName contains "adobe" ) {
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

		// Serialize tray options and write to temp file
		var trayJSON = {
			'title' : displayServerName,
			'tooltip' : serverInfo.processName,
			'items' : serverInfo.trayOptions
		};
		fileWrite( serverInfo.trayOptionsFile,  serializeJSON( trayJSON ) );
		var background = !(serverInfo.console ?: false);

		if( serverInfo.ModCFMLenable && serverInfo.ModCFMLRequireSharedKey && !len( serverInfo.ModCFMLSharedKey ) ){
			throw( message='Since ModeCFML support is enabled, [ModCFML.sharedKey] is required for security.', detail='Disable IN DEVELOPMENT ONLY with [ModCFML.RequireSharedKey=false].', type="commandException" );
		}

		// "borrow" the CommandBox commandline parser to tokenize the JVM args. Not perfect, but close. Handles quoted values with spaces.
		// Escape any semicolons so the parser ignores them in a string and doesn't break the token ex: -DMY_ENV_VAR=foo;bar
		var argTokens = parser.tokenizeInput( serverInfo.JVMargs.replace( ';', '\;', 'all' ) )
			.map( function( i ){
				// unwrap quotes, and unescape any special chars like \" inside the string
				return parser.replaceEscapedChars( parser.removeEscapedChars( parser.unwrapQuotes( i ) ) );
			});

		argTokens.append( serverInfo.JVMargsArray, true );

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

		serverInfo.JVMProperties.each( (k,v)=>argTokens.append( '-D#k#=#v#' ) );

		// Add java agent
		if( len( trim( javaAgent ) ) ) { argTokens.append( javaagent ); }

		// Collect recursive list of all jars in libDirs
		jarArray = serverInfo.libDirs
			.listToArray()
			.reduce( function( jarArray, path ) {
				if( fileExists( path ) && path.lcase().endsWith( '.jar' ) ) {
					jarArray.append( path );
				} else if( directoryExists( path ) ) {
					directoryList( path, true, 'array' )
						.filter( (p)=>p.lcase().endsWith( '.jar' ) )
						.each( function( p ) {
							jarArray.append( p );
						} );
				}
				return jarArray;
			}, [] );
		jarArray.append( serverInfo.runwarJarPath );

		// If server.json has a default browser, use it
		if( !len( serverInfo.preferredBrowser ) && ConfigService.settingExists( 'preferredBrowser' ) ) {
			serverInfo.preferredBrowser = ConfigService.getSetting( 'preferredBrowser' );
		}

		// change status to starting + persist
		serverInfo.dateLastStarted = now();
		serverInfo.status = "starting";
		serverInfo.serverInfoJSON = serverInfo.serverHomeDirectory & '/serverInfo.json';
		setServerInfo( serverInfo );
		JSONService.writeJSONFile( serverInfo.serverInfoJSON, serverInfo, true );
	    // needs to be unique in each run to avoid errors
		var threadName = 'server#hash( serverInfo.webroot )##createUUID()#';
		// Construct a new process object
	    var processBuilder = createObject( "java", "java.lang.ProcessBuilder" );
	    // Pass array of tokens comprised of command plus arguments

		var args=[
			'-cp',
			jarArray.toList( server.system.properties[ 'path.separator' ] )
		];

		argTokens.reverse().each( function(i) { args.prepend( i ); } );

		args.prepend( serverInfo.javaHome )
			.append( 'runwar.Start' )
			.append( serverInfo.serverInfoJSON );

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


		// Setting this via env var so it doesn't blow up Java 8 and I don't have to try and detect what version of Java the server is using.
		var javaOpens = [
			'java.base/sun.nio.ch',
			'java.base/sun.nio.cs',
			'java.base/java.io',
			'java.base/java.lang',
			'java.base/java.lang.annotation',
			'java.base/java.lang.invoke',
			'java.base/java.lang.module',
			'java.base/java.lang.ref',
			'java.base/java.lang.reflect',
			'java.base/java.math',
			'java.base/java.net',
			'java.base/java.net.spi',
			'java.base/java.nio',
			'java.base/java.nio.channels',
			'java.base/java.nio.channels.spi',
			'java.base/java.nio.charset',
			'java.base/java.nio.charset.spi',
			'java.base/java.nio.file',
			'java.base/java.nio.file.attribute',
			'java.base/java.nio.file.spi',
			'java.base/java.security',
			'java.base/java.security.cert',
			'java.base/java.security.interfaces',
			'java.base/java.security.spec',
			'java.base/java.text',
			'java.base/java.text.spi',
			'java.base/java.time',
			'java.base/java.time.chrono',
			'java.base/java.time.format',
			'java.base/java.time.temporal',
			'java.base/java.time.zone',
			'java.base/java.util',
			'java.base/java.util.concurrent',
			'java.base/java.util.concurrent.atomic',
			'java.base/java.util.concurrent.locks',
			'java.base/java.util.function',
			'java.base/java.util.jar',
			'java.base/java.util.regex',
			'java.base/java.util.spi',
			'java.base/java.util.stream',
			'java.base/java.util.zip',
			'java.base/javax.crypto',
			'java.base/javax.crypto.interfaces',
			'java.base/javax.crypto.spec',
			'java.base/javax.net',
			'java.base/javax.net.ssl',
			'java.base/javax.security.auth',
			'java.base/javax.security.auth.callback',
			'java.base/javax.security.auth.login',
			'java.base/javax.security.auth.spi',
			'java.base/javax.security.auth.x500',
			'java.base/javax.security.cert',
			'java.base/sun.net.www.protocol.https',
			'java.desktop/com.sun.java.swing.plaf.nimbus',
			'java.desktop/com.sun.java.swing.plaf.motif',
			'java.desktop/com.sun.java.swing.plaf.nimbus',
			'java.desktop/com.sun.java.swing.plaf.windows',
			'java.desktop/sun.java2d',
			'java.rmi/sun.rmi.transport',
			'java.base/sun.security.rsa',
			'java.base/sun.security.pkcs',
			'java.base/sun.security.x509',
			'java.base/sun.security.util',
			'java.base/sun.util.cldr',
			'java.base/sun.util',
			'java.base/sun.util.locale.provider',
			'java.management/sun.management'
		].reduce( (opens='',o)=>opens &= ' --add-opens=#o#=ALL-UNNAMED' );

		var javaExports = [
			'java.desktop/sun.java2d',
			'java.base/sun.util'
		].reduce( (exports='',o)=>exports &= ' --add-exports=#o#=ALL-UNNAMED' );

		systemSettings.setSystemSetting( 'JDK_JAVA_OPTIONS', systemSettings.getSystemSetting( 'JDK_JAVA_OPTIONS', javaOpens & ' ' & javaExports )  );
		systemSettings.setSystemSetting( 'COMMANDBOX_HOME', systemSettings.getSystemSetting( 'COMMANDBOX_HOME', expandPath( '/commandbox-home' ) ) );
		systemSettings.setSystemSetting( 'COMMANDBOX_VERSION', systemSettings.getSystemSetting( 'COMMANDBOX_VERSION', shell.getVersion() ) );

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

	    if( fileSystemUtil.isWindows() ) {
	    	args = args.map( (a)=>replace( a, '"', '\"', 'all' ) );
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
		thread name="#threadName#" interactiveStart=interactiveStart serverInfo=serverInfo args=args startTimeout=serverInfo.startTimeout parentThread=thisThread background=background {
			try{

				// save server info and persist
				serverInfo.statusInfo = { 'command':serverInfo.javaHome, 'arguments':attributes.args.toList( ' ' ), 'result':'' };
				serverInfo.status="starting";
				setServerInfo( serverInfo );

				var startOutput = createObject( 'java', 'java.lang.StringBuilder' ).init();
	    		var inputStream = process.getInputStream();
	    		var inputStreamReader = createObject( 'java', 'java.io.InputStreamReader' ).init( inputStream );
	    		var bufferedReader = createObject( 'java', 'java.io.BufferedReader' ).init( inputStreamReader );
				var print = wirebox.getInstance( "PrintBuffer" );

				var line = bufferedReader.readLine();
				while( !isNull( line ) ){
					line = AnsiFormatter.cleanLine( line );

					// Build up our output.  Limit the size of this so a console server running for a month doesn't fill up memory.
					// We only use this for the server info result anyway.
					if( startOutput.length() < 5000 && !(line contains 'Picked up JDK_JAVA_OPTIONS:' ) ) {
						startOutput.append( line & chr( 13 ) & chr( 10 ) );
					}

					// output it if we're being interactive
					if( attributes.interactiveStart && !line.startsWith( 'NOTE: Picked up JDK_JAVA_OPTIONS:' ) ) {
						print
							.line( line )
							.toConsole();
					}

					if( attributes.background && line contains 'Server is up' ) {
						serverInfo.status="running";
						break;
					}
					line = bufferedReader.readLine();
				} // End of inputStream

				if( !attributes.background ) {
					serverInfo.exitCode = process.waitFor();

					if( serverInfo.exitCode == 0 ) {
						serverInfo.status="running";
					} else {
						serverInfo.status="unknown";
					}
				}

			} catch( any e ) {
				consoleLogger.error( e.message & ' ' & e.detail, e.stacktrace );
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
					// When the sleep() is interrupted, it comes as a Lucee NativeException with the message "sleep interrupted"
					if( e.message contains 'interrupted' ){
						consoleLogger.error( 'Stopping server...' );
						shell.setKeepRunning( false );
						serverInterrupted = true;
					} else {
						logger.error( '#e.message# #e.detail#' , e.stackTrace );
						consoleLogger.error( '#e.message##chr(10)##e.detail#' );
					}
				}

				// Now it's time to shut-er down
				variables.waitingOnConsoleStart = false;
				shell.setPrompt();
				// Politely ask the server to stop (async)
				stop( serverInfo );
				// Give it a chance to stop
				try {
					process.waitFor( 15, java.TimeUnit.SECONDS );
				} catch( any e ) {
					logger.error( '#e.message# #e.detail#' , e.stackTrace );
					consoleLogger.error( 'Waiting for server process to stop: #e.message##chr(10)##e.detail#' );
				}
				// Ok, you're done NOW!
				process.destroy();
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
	 * Load site config from an external file
	 */
	function loadSiteConfig( site, siteName ) {
		if( isNull( site.siteConfigFile ) || !fileExists( site.siteConfigFile ) ) {
			throw( message='Site config file [#site.siteConfigFile ?: 'not provided'#] doesn''t exist', type="commandExceptiond" );
		}


		var siteJSON = readServerJSON( site.siteConfigFile );
		// TODO: Add interception announcement so dotenv can read site-specific .env files
		// Also, use a nested command context to encapsulate the site envs
		siteJSON = systemSettings.expandDeepSystemSettings( siteJSON );
		// merge in the site settings
		JSONService.mergeData( site, siteJSON );

		if( siteJSON.keyExists( 'webroot' ) ) {
			site.webroot = fileSystemUtil.resolvePath( siteJSON.webroot, site.siteConfigFileDirectory );
		}

		if( !len( site.webroot ?: '' ) ) {
			// If there is no explicit web root, assume it's where the .site.json file lives
			site.webroot = getDirectoryFromPath( site.siteConfigFile );
		}
		site.__loaded = true;
		return arguments.siteName ?: site.name ?: getFileFromPath( site.siteConfigFile ).replaceNoCase( '.json', '' );
	}

	/**
	 *
	 */
	function resolveSiteSettings( string name, struct serverInfo, struct serverProps, struct serverJSON, struct defaults, boolean multiSite ) {
		var site = serverJSON.sites[ name ];
		var job = wirebox.getInstance( 'interactiveJob' );

		serverInfo.webroot = site.webroot;
		serverInfo.host = serverProps.host ?: site.host ?: serverJSON.web.host ?: defaults.web.host;
		serverInfo.hostAlias = site.hostAlias ?: serverJSON.web.hostAlias ?: defaults.web.hostAlias;
		serverInfo.default = site.default ?: false;
		// TODO: Make this configurable
		if( multiSite ) {
			// Access log named after site.
			serverInfo.accessLogBaseName = 'access' & '-' & name.reReplace( '[^0-9a-zA-Z-\.@]', '', 'all' );
		} else {
			serverInfo.accessLogBaseName = 'access';;
		}
		serverInfo.accessLogPath = serverInfo.logDir & '/#serverInfo.accessLogBaseName#.txt';

		// Default all the things to make our lives easier
		serverJSON.web = serverJSON.web ?: {};
		defaults.web = defaults.web ?: {};
		[ site, serverJSON.web, defaults.web ].each( (config)=>{
			config[ 'bindings' ] = config.bindings ?: {}
			config.bindings[ 'http' ] = config.bindings.http ?: []
			if( isStruct( config.bindings.http ) ) {
				config.bindings.http = [ config.bindings.http ]
			}
			config.bindings[ 'ssl' ] = config.bindings.ssl ?: []
			if( isStruct( config.bindings.ssl ) ) {
				config.bindings.ssl = [ config.bindings.ssl ]
			}
			config.bindings[ 'ajp' ] = config.bindings.ajp ?: []
			if( isStruct( config.bindings.ajp ) ) {
				config.bindings.ajp = [ config.bindings.ajp ]
			}
		} );

		site.bindings.http.append( serverJSON.web.bindings.http, true ).append( defaults.web.bindings.http, true );
		site.bindings.ssl.append( serverJSON.web.bindings.ssl, true ).append( defaults.web.bindings.ssl, true );
		site.bindings.ajp.append( serverJSON.web.bindings.ajp, true ).append( defaults.web.bindings.ajp, true );
		serverInfo.bindings = site.bindings;

		if( isSimpleValue( serverInfo.hostAlias ) ) {
			serverInfo.hostAlias = serverInfo.hostAlias.listToArray();
		}

		if( !isNull( site.rewrites ) ) {
			throw( 'You cannot set "rewrites" config on a per-site basis as Tuckey Rewrite is servlet-wide. You can use Server Rules for per-site rewrites.' );
		}
		if( !isNull( site.maxRequests ) ) {
			throw( 'You cannot set "maxRequests" config on a per-site basis as it is servlet-wide.' );
		}

		// If the last port we used is taken, remove it from consideration.
		// TODO: if( val( serverInfo.port ) == 0 || !isPortAvailable( serverInfo.host, serverInfo.port ) ) { serverInfo.delete( 'port' ); }

		// If no bindings are provided, default HTTP to enabled (compat)
		var hasModernBindings = serverInfo.bindings.http.len() || serverInfo.bindings.ssl.len() || serverInfo.bindings.ajp.len();
		serverInfo.HTTPEnable = serverProps.HTTPEnable ?: site.HTTP.enable ?: serverJSON.web.HTTP.enable ?: defaults.web.HTTP.enable ?: !hasModernBindings;
		serverInfo.HTTP2Enable = site.HTTP2.enable ?: serverJSON.web.HTTP2.enable ?: defaults.web.HTTP2.enable;

		// Port is the only setting that automatically carries over without being specified since it's random.
		serverInfo['port'] = serverProps.port ?: site.http.port ?: serverJSON.web.http.port ?: serverInfo.port	?: defaults.web.http.port;
		serverInfo.port = val( serverInfo.port );
		// Server default is 0 not null.
		if( serverInfo.port == 0 && serverInfo.HTTPEnable ) {
			serverInfo.port = getRandomPort( serverInfo.host );
		// For backwards compat, if there is a port specified, even if bindings are in use, enable HTTP.s
		} else if( serverInfo.port > 0 ) {
			serverInfo.HTTPEnable = true;
		}

		serverInfo.SSLEnable = serverProps.SSLEnable ?: site.SSL.enable ?: serverJSON.web.SSL.enable ?: defaults.web.SSL.enable;
		serverInfo.SSLPort = serverProps.SSLPort ?: site.SSL.port ?: serverJSON.web.SSL.port ?: defaults.web.SSL.port;

		serverInfo.AJPEnable = serverProps.AJPEnable ?: site.AJP.enable ?: serverJSON.web.AJP.enable ?: defaults.web.AJP.enable;
		serverInfo.AJPPort = serverProps.AJPPort ?: site.AJP.port ?: serverJSON.web.AJP.port ?: defaults.web.AJP.port;
		serverInfo.AJPSecret = site.AJP.secret ?: serverJSON.web.AJP.secret ?: defaults.web.AJP.secret;


		// relative certFile in server.json is resolved relative to the server.json
		if( isDefined( 'serverJSON.web.SSL.certFile' ) ) { serverJSON.web.SSL.certFile = fileSystemUtil.resolvePath( serverJSON.web.SSL.certFile, site.serverConfigFileDirectory ); }
		if( isDefined( 'site.SSL.certFile' ) ) { site.SSL.certFile = fileSystemUtil.resolvePath( site.SSL.certFile, site.siteConfigFileDirectory ); }
		// relative certFile in config setting server defaults is resolved relative to the web root
		if( len( defaults.web.SSL.certFile ?: '' ) ) { defaults.web.SSL.certFile = fileSystemUtil.resolvePath( defaults.web.SSL.certFile, serverInfo.webroot ); }
		serverInfo.SSLCertFile = serverProps.SSLCertFile ?: site.SSL.certFile ?: serverJSON.web.SSL.certFile ?: defaults.web.SSL.certFile;

		// relative keyFile in server.json is resolved relative to the server.json
		if( isDefined( 'serverJSON.web.SSL.keyFile' ) ) { serverJSON.web.SSL.keyFile = fileSystemUtil.resolvePath( serverJSON.web.SSL.keyFile, site.serverConfigFileDirectory ); }
		if( isDefined( 'site.SSL.keyFile' ) ) { site.SSL.keyFile = fileSystemUtil.resolvePath( site.SSL.keyFile, site.siteConfigFileDirectory ); }
		// relative trayIcon in config setting server defaults is resolved relative to the web root
		if( len( defaults.web.SSL.keyFile ?: '' ) ) { defaults.web.SSL.keyFile = fileSystemUtil.resolvePath( defaults.web.SSL.keyFile, serverInfo.webroot ); }
		serverInfo.SSLKeyFile = serverProps.SSLKeyFile ?: site.SSL.keyFile ?: serverJSON.web.SSL.keyFile ?: defaults.web.SSL.keyFile;
		serverInfo.SSLKeyPass = serverProps.SSLKeyPass ?: site.SSL.keyPass ?: serverJSON.web.SSL.keyPass ?: defaults.web.SSL.keyPass;

		// relative certFile in server.json is resolved relative to the server.json
		if( isDefined( 'serverJSON.web.SSL.clientCert.CACertFiles' ) ) {
			if( isSimpleValue( serverJSON.web.SSL.clientCert.CACertFiles ) ) {
				serverJSON.web.SSL.clientCert.CACertFiles = listToArray( serverJSON.web.SSL.clientCert.CACertFiles );
			}
			serverJSON.web.SSL.clientCert.CACertFiles = serverJSON.web.SSL.clientCert.CACertFiles.map( (f)=>fileSystemUtil.resolvePath( f, site.serverConfigFileDirectory ) );
		}
		if( isDefined( 'site.SSL.clientCert.CACertFiles' ) ) {
			if( isSimpleValue( site.SSL.clientCert.CACertFiles ) ) {
				site.SSL.clientCert.CACertFiles = listToArray( site.SSL.clientCert.CACertFiles );
			}
			site.SSL.clientCert.CACertFiles = site.SSL.clientCert.CACertFiles.map( (f)=>fileSystemUtil.resolvePath( f, site.siteConfigFileDirectory ) );
		}
		// relative certFile in config setting server defaults is resolved relative to the web root
		if( len( defaults.web.SSL.clientCert.CACertFiles ) ) {
			if( isSimpleValue( defaults.web.SSL.clientCert.CACertFiles ) ) {
				defaults.web.SSL.clientCert.CACertFiles = listToArray( defaults.web.SSL.clientCert.CACertFiles );
			}
			defaults.web.SSL.clientCert.CACertFiles = defaults.web.SSL.clientCert.CACertFiles.map( (f)=>fileSystemUtil.resolvePath( f, serverInfo.webroot ) );
		} else {
			defaults.web.SSL.clientCert.CACertFiles = [];
		}
		serverInfo.clientCertCACertFiles = site.SSL.clientCert.CACertFiles ?: serverJSON.web.SSL.clientCert.CACertFiles ?: defaults.web.SSL.clientCert.CACertFiles;

		if( !isNull( serverJSON.web.SSL.clientCert.CATrustStoreFile ) ) {
			serverJSON.web.SSL.clientCert.CATrustStoreFile = fileSystemUtil.resolvePath( serverJSON.web.SSL.clientCert.CATrustStoreFile, site.serverConfigFileDirectory );
		}
		if( !isNull( site.SSL.clientCert.CATrustStoreFile ) ) {
			site.SSL.clientCert.CATrustStoreFile = fileSystemUtil.resolvePath( site.SSL.clientCert.CATrustStoreFile, site.siteConfigFileDirectory );
		}
		if( len( defaults.web.SSL.clientCert.CATrustStoreFile ) ) {
			defaults.web.SSL.clientCert.CATrustStoreFile = fileSystemUtil.resolvePath( defaults.web.SSL.clientCert.CATrustStoreFile, serverInfo.webroot );
		}
		serverInfo.clientCertCATrustStoreFile = site.SSL.clientCert.CATrustStoreFile ?: serverJSON.web.SSL.clientCert.CATrustStoreFile ?: defaults.web.SSL.clientCert.CATrustStoreFile;
		serverInfo.clientCertCATrustStorePass = site.SSL.clientCert.CATrustStorePass ?: serverJSON.web.SSL.clientCert.CATrustStorePass ?: defaults.web.SSL.clientCert.CATrustStorePass;

		serverInfo.clientCertMode = site.SSL.clientCert.mode ?: serverJSON.web.SSL.clientCert.mode ?: defaults.web.SSL.clientCert.mode;
		serverInfo.clientCertSSLRenegotiationEnable = site.security.clientCert.SSLRenegotiationEnable ?: serverJSON.web.security.clientCert.SSLRenegotiationEnable ?: defaults.web.security.clientCert.SSLRenegotiationEnable;


		var profileReason = 'config setting server defaults';
		// Try to set a smart profile if there's not one set
		if( !trim( defaults.profile ).len() ) {
			var thisIP = '';
			// Try and get the IP we're binding to
			try{
				thisIP = getAddressByHost( serverInfo.host ).getHostAddress();
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
				profileReason = 'profile property in "box_server_profile" env var';
			} else {
				profileReason = 'profile property in server.json';
			}
		}

		if( len( site.profile ?: '' ) ) {
			profileReason = 'site config';
		}

		if( !isNull( serverProps.profile ) ) {
			profileReason = 'profile argument to server start command';
		}
		serverInfo.profile = serverProps.profile ?: site.profile ?: serverJSON.profile ?: defaults.profile;

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

		serverInfo.blockCFAdmin = serverProps.blockCFAdmin ?: site.blockCFAdmin ?: serverJSON.web.blockCFAdmin ?: defaults.web.blockCFAdmin;
		serverInfo.blockSensitivePaths = site.blockSensitivePaths ?: serverJSON.web.blockSensitivePaths ?: defaults.web.blockSensitivePaths;
		serverInfo.blockFlashRemoting = site.blockFlashRemoting ?: serverJSON.web.blockFlashRemoting ?: defaults.web.blockFlashRemoting;
		serverInfo.allowedExt = site.allowedExt ?: serverJSON.web.allowedExt ?: defaults.web.allowedExt;
		serverInfo.useProxyForwardedIP = site.useProxyForwardedIP ?: serverJSON.web.useProxyForwardedIP ?: defaults.web.useProxyForwardedIP;

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
		serverInfo.directoryBrowsing = serverProps.directoryBrowsing ?: site.directoryBrowsing ?: serverJSON.web.directoryBrowsing ?: defaults.web.directoryBrowsing;

		// If there isn't a default for this already
		if( !isBoolean( defaults.web.fileCache.enable ) ) {
			if( serverInfo.profile == 'production' ) {
				defaults.web.fileCache.enable = true;
			} else {
				defaults.web.fileCache.enable = false;
			}
		}

		serverInfo.fileCacheEnable	= site.fileCache.enable ?: serverJSON.web.fileCache.enable ?: defaults.web.fileCache.enable;
		serverInfo.fileCacheTotalSizeMB	= site.fileCache.totalSizeMB ?:serverJSON.web.fileCache.totalSizeMB ?: defaults.web.fileCache.totalSizeMB;
		serverInfo.fileCacheMaxFileSizeKB = site.fileCache.maxFileSizeKB ?:serverJSON.web.fileCache.maxFileSizeKB ?: defaults.web.fileCache.maxFileSizeKB;

		job.start( 'Setting site [#name#] Profile to [#serverInfo.profile#]' );
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
			job[ 'add#( serverInfo.fileCacheEnable ? 'Success' : '' )#Log' ]( 'File Caching #( serverInfo.fileCacheEnable ? 'en' : 'dis' )#abled' );
		job.complete( serverInfo.verbose );

		serverInfo.SSLForceRedirect = site.SSL.forceSSLRedirect ?: serverJSON.web.SSL.forceSSLRedirect ?: defaults.web.SSL.forceSSLRedirect;
		serverInfo.HSTSEnable = site.SSL.HSTS.enab ?: serverJSON.web.SSL.HSTS.enable ?: defaults.web.SSL.HSTS.enable;
		serverInfo.HSTSMaxAge = site.SSL.HSTS.maxAge ?: serverJSON.web.SSL.HSTS.maxAge ?: defaults.web.SSL.HSTS.maxAge;
		serverInfo.HSTSIncludeSubDomains = site.SSL.HSTS.includeSubDomains ?: serverJSON.web.SSL.HSTS.includeSubDomains ?: defaults.web.SSL.HSTS.includeSubDomains;

		serverInfo.basicAuthEnable = site.security.basicAuth.enable ?: serverJSON.web.security.basicAuth.enable ?: defaults.web.security.basicAuth.enable ?: serverJSON.web.basicAuth.enable ?: defaults.web.basicAuth.enable;
		serverInfo.basicAuthUsers = site.security.basicAuth.users ?: serverJSON.web.security.basicAuth.users ?: defaults.web.security.basicAuth.users ?: serverJSON.web.basicAuth.users ?: defaults.web.basicAuth.users;
		// If there are no users, basic auth is NOT enabled
		if( !serverInfo.basicAuthUsers.count() ) {
			serverInfo.basicAuthEnable = false;
		}

		serverInfo.clientCertEnable	= site.security.clientCert.enable ?: serverJSON.web.security.clientCert.enable ?: defaults.web.security.clientCert.enable;
		serverInfo.clientCertTrustUpstreamHeaders =	site.security.clientCert.trustUpstreamHeaders ?: serverJSON.web.security.clientCert.trustUpstreamHeaders ?: defaults.web.security.clientCert.trustUpstreamHeaders;

		// Default missing values
		serverJSON.web.security.clientCert.subjectDNs = serverJSON.web.security.clientCert.subjectDNs ?: '';
		serverJSON.web.security.clientCert.issuerDNs = serverJSON.web.security.clientCert.issuerDNs ?: '';
		site.security.clientCert.subjectDNs = site.security.clientCert.subjectDNs ?: '';
		site.security.clientCert.issuerDNs = site.security.clientCert.issuerDNs ?: '';

		// Convert all strings to arrays
		if( isSimpleValue( serverJSON.web.security.clientCert.subjectDNs ) ) {
			if( len( serverJSON.web.security.clientCert.subjectDNs ) ) {
				serverJSON.web.security.clientCert.subjectDNs = [ serverJSON.web.security.clientCert.subjectDNs ];
			} else {
				serverJSON.web.security.clientCert.subjectDNs = [];
			}
		}
		if( isSimpleValue( site.security.clientCert.subjectDNs ) ) {
			if( len( site.security.clientCert.subjectDNs ) ) {
				site.security.clientCert.subjectDNs = [ site.security.clientCert.subjectDNs ];
			} else {
				site.security.clientCert.subjectDNs = [];
			}
		}
		if( isSimpleValue( defaults.web.security.clientCert.subjectDNs ) ) {
			if( len( defaults.web.security.clientCert.subjectDNs ) ) {
				defaults.web.security.clientCert.subjectDNs = [ defaults.web.security.clientCert.subjectDNs ];
			} else {
				defaults.web.security.clientCert.subjectDNs = [];
			}
		}
		if( isSimpleValue( serverJSON.web.security.clientCert.issuerDNs ) ) {
			if( len( serverJSON.web.security.clientCert.issuerDNs ) ) {
				serverJSON.web.security.clientCert.issuerDNs = [ serverJSON.web.security.clientCert.issuerDNs ];
			} else {
				serverJSON.web.security.clientCert.issuerDNs = [];
			}
		}
		if( isSimpleValue( site.security.clientCert.issuerDNs ) ) {
			if( len( site.security.clientCert.issuerDNs ) ) {
				site.security.clientCert.issuerDNs = [ site.security.clientCert.issuerDNs ];
			} else {
				site.security.clientCert.issuerDNs = [];
			}
		}
		if( isSimpleValue( defaults.web.security.clientCert.issuerDNs ) ) {
			if( len( defaults.web.security.clientCert.issuerDNs ) ) {
				defaults.web.security.clientCert.issuerDNs = [ defaults.web.security.clientCert.issuerDNs ];
			} else {
				defaults.web.security.clientCert.issuerDNs = [];
			}
		}

		// Combine server defaults AND any settings in server.json
		serverInfo.clientCertSubjectDNs	= serverJSON.web.security.clientCert.subjectDNs
			.append( site.security.clientCert.subjectDNs, true )
			.append( defaults.web.security.clientCert.subjectDNs, true );
		serverInfo.clientCertIssuerDNs = serverJSON.web.security.clientCert.issuerDNs
			.append( site.security.clientCert.issuerDNs, true )
			.append( defaults.web.security.clientCert.issuerDNs, true );

		serverInfo.authEnabled = serverInfo.basicAuthEnable || serverInfo.clientCertEnable;
		serverInfo.securityRealm = site.security.realm ?: serverJSON.web.security.realm ?: defaults.web.security.realm;
		serverInfo.authPredicate = site.security.authPredicate ?: serverJSON.web.security.authPredicate ?: defaults.web.security.authPredicate;

		serverInfo.welcomeFiles = serverProps.welcomeFiles ?: site.welcomeFiles ?: serverJSON.web.welcomeFiles ?: defaults.web.welcomeFiles;
		// Clean up spaces in welcome file list
		serverInfo.welcomeFiles = serverInfo.welcomeFiles.listMap( ( i )=>trim( i ) );

		serverInfo.caseSensitivePaths = site.caseSensitivePaths ?: serverJSON.web.caseSensitivePaths ?: defaults.web.caseSensitivePaths;

		// Global aliases are always added on top of server.json (but don't overwrite)
		serverInfo.aliases = defaults.web.aliases.map( (a,p)=>fileSystemUtil.resolvePath( p, serverInfo.webroot ) );
		serverInfo.aliases.append( ( serverJSON.web.aliases ?: {} ).map( (a,p)=>{
			return fileSystemUtil.resolvePath( p, site.serverConfigFileDirectory );
		} ), true );
		serverInfo.aliases.append( ( site.aliases ?: {} ).map( (a,p)=>{
			return fileSystemUtil.resolvePath( p, site.siteConfigFileDirectory );
		} ), true );

		// Combine global and server-specific mime types
		serverInfo.mimeTypes = defaults.web.mimeTypes.append( serverJSON.web.mimeTypes ?: {}, true );
		serverInfo.mimeTypes = defaults.web.mimeTypes.append( site.mimeTypes ?: {}, true );

		// Global errorPages are always added on top of server.json (but don't overwrite the full struct)
		// Aliases aren't accepted via command params
		serverInfo.errorPages = defaults.web.errorPages;
		serverInfo.errorPages.append( serverJSON.web.errorPages ?: {} );
		serverInfo.errorPages.append( site.errorPages ?: {} );

		serverInfo.accessLogEnable = site.accessLogEnable ?: serverJSON.web.accessLogEnable ?: defaults.web.accessLogEnable;
		serverInfo.GZIPEnable = site.GZIPEnable ?: serverJSON.web.GZIPEnable ?: defaults.web.GZIPEnable;
		serverInfo.gzipPredicate = site.gzipPredicate ?: serverJSON.web.gzipPredicate ?: defaults.web.gzipPredicate;

		serverInfo.webRules = [];

		//ssl hsts
		if(serverInfo.SSLEnable && serverInfo.HSTSEnable){
			serverInfo.webRules.append(
				"set(attribute='%{o,Strict-Transport-Security}', value='max-age=#serverInfo.HSTSMaxAge##(serverInfo.HSTSIncludeSubDomains ? '; includeSubDomains' : '')#')"
			);
		}

		//ssl force redirect
		if(serverInfo.SSLEnable && serverInfo.SSLForceRedirect){
			serverInfo.webRules.append(
				"not secure() and method(GET) -> { set(attribute='%{o,Location}', value='https://%{LOCAL_SERVER_NAME}:#serverinfo.SSLPort#%{REQUEST_URL}%{QUERY_STRING}'); response-code(301) }"
			);
		}

		//ajp enabled with secret
		if( serverInfo.AJPEnable && len( serverInfo.AJPSecret ) ){
			var charBlock = find( "'", serverInfo.AJPSecret ) ? '"' : "'";
			serverInfo.webRules.append(
				"equals(%p, #serverInfo.AJPPort#) and not equals(%{r,secret}, #charBlock##serverInfo.AJPSecret##charBlock#) -> set-error(403)"
			);
		}

		if( site.keyExists( 'rules' ) ) {
			if( !isArray( site.rules ) ) {
				throw( message="'site.#name#.rules' key in your server.json must be an array of strings.", type="commandException" );
			}
			serverInfo.webRules.append( site.rules, true);
		}

		if( serverJSON.keyExists( 'web' ) && serverJSON.web.keyExists( 'rules' ) ) {
			if( !isArray( serverJSON.web.rules ) ) {
				throw( message="'rules' key in your server.json must be an array of strings.", type="commandException" );
			}
			serverInfo.webRules.append( serverJSON.web.rules, true);
		}
		if( site.keyExists( 'rulesFile' ) ) {
			if( isSimpleValue( site.rulesFile ) ) {
				site.rulesFile = site.rulesFile.listToArray();
			}
			serverInfo.webRules.append( site.rulesFile.reduce((predicates,fg)=>{
				fg = fileSystemUtil.resolvePath( fg, site.siteConfigFileDirectory );
				return predicates.append( wirebox.getInstance( 'Globber' ).setPattern( fg ).matches().reduce( (predicates,file)=>{
						if( lCase( file ).endsWith( '.json' ) ) {
							return predicates.append( deserializeJSON( fileRead( file ) ), true );
						} else {
							return predicates.append( fileRead( file ).listToArray( chr(13)&chr(10) ), true );
						}
					}, [] ), true );
			}, []), true );
		}
		if( serverJSON.keyExists( 'web' ) && serverJSON.web.keyExists( 'rulesFile' ) ) {
			if( isSimpleValue( serverJSON.web.rulesFile ) ) {
				serverJSON.web.rulesFile = serverJSON.web.rulesFile.listToArray();
			}
			serverInfo.webRules.append( serverJSON.web.rulesFile.reduce((predicates,fg)=>{
				fg = fileSystemUtil.resolvePath( fg, site.serverConfigFileDirectory );
				return predicates.append( wirebox.getInstance( 'Globber' ).setPattern( fg ).matches().reduce( (predicates,file)=>{
						if( lCase( file ).endsWith( '.json' ) ) {
							return predicates.append( deserializeJSON( fileRead( file ) ), true );
						} else {
							return predicates.append( fileRead( file ).listToArray( chr(13)&chr(10) ), true );
						}
					}, [] ), true );
			}, []), true );
		}
		if( defaults.keyExists( 'web' ) && defaults.web.keyExists( 'rules' ) ) {
			serverInfo.webRules.append( defaults.web.rules, true);
		}

		if( defaults.keyExists( 'web' ) && defaults.web.keyExists( 'rulesFile' ) ) {
			var defaultsRulesFile = defaults.web.rulesFile;
			if( isSimpleValue( defaultsRulesFile ) ) {
				defaultsRulesFile = defaultsRulesFile.listToArray();
			}
			serverInfo.webRules.append( defaultsRulesFile.reduce((predicates,fg)=>{
				fg = fileSystemUtil.resolvePath( fg, serverInfo.webroot );
				return predicates.append( wirebox.getInstance( 'Globber' ).setPattern( fg ).matches().reduce( (predicates,file)=>{
						if( lCase( file ).endsWith( '.json' ) ) {
							return predicates.append( deserializeJSON( fileRead( file ) ), true );
						} else {
							return predicates.append( fileRead( file ).listToArray( chr(13)&chr(10) ), true );
						}
					}, [] ), true );
			}, []), true);
		}

		// Default CommandBox rules.
		if( serverInfo.blockSensitivePaths ) {
			serverInfo.webRules.append( [
				// track and trace verbs can leak data in XSS attacks
				"disallowed-methods( methods={trace,track} )",
				// Common config files and sensitive paths that should never be accessed, even on development
				"regex( pattern='.*/(box\.json|server\.json|web\.config|urlrewrite\.xml|package\.json|package-lock\.json|Gulpfile\.js)', case-sensitive=false ) -> { set-error(404); done }",
				// Any file or folder starting with a period, unless it's called
				"regex('/\.') and not path-prefix(.well-known) -> { set-error( 404 ); done }",
				// Additional serlvlet mappings in Adobe CF's web.xml
				"path-prefix( { '/JSDebugServlet','/securityanalyzer','/WSRPProducer' } ) -> { set-error( 404 ); done }",
				// java web service (Axis) files
				"regex( pattern='\.jws$', case-sensitive=false ) -> { set-error( 404 ); done }"
			], true );

			if( serverInfo.profile == 'production' ) {
				serverInfo.webRules.append( [
					// Common config files and sensitive paths in ACF and TestBox that may be ok for dev, but not for production
					"regex( pattern='.*/(CFIDE/multiservermonitor-access-policy\.xml|CFIDE/probe\.cfm|CFIDE/main/ide\.cfm|tests/runner\.cfm|testbox/system/runners/HTMLRunner\.cfm)', case-sensitive=false ) -> { set-error(404); done }",
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

		// Remove comments
		serverInfo.webRules = serverInfo.webRules.filter( (r)=>!trim(r).startsWith('##') );
		serverInfo.webRulesText = serverInfo.webRules.toList( CR );

		if( serverInfo.verbose ) {
			job.addLog( "Site name - " & name );
			job.addLog( "Webroot - " & serverInfo.webroot );
			job.addLog( "Site config file - " & site.siteConfigFile );
		}

	}

	/**
	 * Build out all bindings for a site, expanding all possible hosts and defaulting values.
	 * Bindings are array of structs having these keys.
	 * - IP
	 * - port
	 * - host
	 * - type
	 * - site
	 */
	function buildBindings( required struct serverInfo ) {
		var sites = serverInfo.sites;

		// clean slate per start
		serverInfo.listeners = {
			'http' : {},
			'ssl' : {},
			'ajp' : {}
		};
		serverInfo.bindings = {};
		var bindingBuildBasic = ( binding, site )=>{
			var result = {
				hosts = binding.host ?: site.hostAlias ?: '',
				IP = '',
				Port = ''
			}
			if( !len(result.hosts) ) {
				result.hosts = '*'
			}
			if( isSimpleValue(result.hosts) ) {
				result.hosts = result.hosts.listToArray();
			}
			if( len( binding.listen ?: '' ) ) {
				result.Port = listLast( binding.listen, ':' );
				if( listLen( binding.listen, ':'  ) > 1 ) {
					result.IP = listFirst( binding.listen, ':' );
				} else {
					result.IP = '0.0.0.0';
				}
			}
			if( len( binding.port ?: '' ) ) {
				result.Port = binding.port;
			}
			if( len( binding.IP ?: '' ) ) {
				result.IP = binding.IP;
			}
			if( result.IP == '*' || result.IP == '' ) {
				result.IP = '0.0.0.0';
			}
			return result;
		};
		var allBindings = [];
		var defaultSiteName = '';
		sites.each( (siteName,site)=>{
			if( !len( site.hostAlias ) ) {
				site.hostAlias.append( '*' )
			}
			// The legacy bindings use "host" to represent the IP for the binding.
			var IP = getAddressByHost( site.host ).getHostAddress();

			// Backwards compat bindings in web.http, web.ssl, and web.ajp
			if( site.HTTPEnable ) {
				allBindings.append( newBinding( site=siteName, IP=IP, port=site.port, hosts=site.hostAlias, type='http', HTTP2Enable=site.HTTP2Enable ) );
			}

			if( site.SSLEnable ) {
				allBindings.append( newBinding( site=siteName, IP=IP, port=site.SSLPort, hosts=site.hostAlias, type='ssl', SSLCertFile=site.SSLCertFile, SSLKeyFile=site.SSLKeyFile, SSLKeyPass=site.SSLKeyPass ) );
			}

			if( site.AJPEnable ) {
				allBindings.append( newBinding( site=siteName, IP=IP, port=site.AJPPort, hosts=site.hostAlias, type='ajp', AJPSecret=site.AJPSecret ) );
			}

			// Gather bindings of each type for this site
			['http','ssl','ajp'].each( (type)=>{
				// Bindings can be an array
				site.bindings[type].each( (binding)=>{
					var params = bindingBuildBasic( binding, site );
					params.type = type;
					params.site = siteName;
					params.HTTP2Enable=site.HTTP2Enable;
					params.SSLCertFile=binding.certFile ?: '';
					params.SSLKeyFile=binding.keyFile ?: '';
					params.SSLKeyPass=binding.keyPass ?: '';
					params.AJPSecret=binding.secret ?: '';
					if( len( params.port ) ) {
						allBindings.append( newBinding( argumentCollection=params ) );
					}
				} );
			} );

			// TODO: Throw error if more than one site is marked as default?
			if( site.default ?: false && !len( defaultSiteName ) ) {
				defaultSiteName = siteName;
			}

		} );

		[ (b)=>b.IP=='0.0.0.0', (b)=>b.IP!='0.0.0.0' ].each( (filter)=>{
			allBindings
				.filter( filter )
				.each( (binding)=>{

					// Aggregate de-duped listeners
					if( serverInfo.listeners[ binding.type ].keyExists( '0.0.0.0:#binding.port#' ) ) {
						// Use all IP binding, if exists
						var listener = serverInfo.listeners[ binding.type ][ '0.0.0.0:#binding.port#' ];
					} else if( serverInfo.listeners[ binding.type ].keyExists( '#binding.IP#:#binding.port#' ) ) {
						// Use specific IP binding, if exists
						var listener = serverInfo.listeners[ binding.type ][ '#binding.IP#:#binding.port#' ];
					} else {
						// Create a new bindings
						var listener = serverInfo.listeners[ binding.type ][ '#binding.IP#:#binding.port#' ] = {
							'IP' : binding.IP,
							'port' : binding.port
						};
					}
					if( !isNull( binding.HTTP2Enable ) && isBoolean( binding.HTTP2Enable ) ) {
						listener[ 'HTTP2Enable' ] = ( listener.HTTP2Enable ?: false ) || binding.HTTP2Enable;
					}

					if( binding.type == 'ssl' ) {
						listener[ 'certs' ] = [];
						if( !isNull( binding.SSLCertFile ) && len( binding.SSLCertFile ) ) {
							var cert = {}
							cert[ 'certFile' ] = binding.SSLCertFile;

							if( !isNull( binding.SSLKeyFile ) && len( binding.SSLKeyFile ) ) {
								cert[ 'keyFile' ] = binding.SSLKeyFile;
							}

							if( !isNull( binding.SSLKeyPass ) && len( binding.SSLKeyPass ) ) {
								cert[ 'keyPass' ] = binding.SSLKeyPass;
							}
							listener.certs.append( cert );
						}
					}

					// Build out all possible bindings to sites
					binding.hosts.each( (host)=>{
						// TODO: Deal with partial hostname wildcard matches
						var thisHost = ( host == '0.0.0.0' ? '*' : host );
						serverInfo.bindings[ lcase( '#binding.IP#:#binding.port#:#thisHost#' ) ] = binding.filter( (k)=>'type,IP,port,AJPSecret,site'.listFindNoCase(k) ).append( { 'host' : thisHost } );
					} );

				} );

			// If there was a site marked as "default"
			if( len( defaultSiteName ) ) {
				serverInfo.bindings[ lcase( 'default' ) ] = { 'site' : defaultSiteName };
			}

		} );

	}

	/**
	 * Create default binding struct, expanding a bindings for each possible host name
	 */
	struct function newBinding(
			required site,
			IP='0.0.0.0',
			port=80,
			hosts=['*'],
			type='http',
			HTTP2Enable=true,
			SSLCertFile='',
			SSLKeyFile='',
			SSLKeyPass='',
			AJPSecret=''
		) {

		if( IP == '*' ) {
			IP = '0.0.0.0';
		}
		var binding = {
			'site' : site,
			'IP' : IP,
			'port' : port,
			'hosts' : hosts,
			'type' : type,
			'HTTP2Enable' : HTTP2Enable
		}
		if( type == 'ssl' ) {
			binding[ 'SSLCertFile' ] = SSLCertFile;
			binding[ 'SSLKeyFile' ] = SSLKeyFile;
			binding[ 'SSLKeyPass' ] = SSLKeyPass;
		}
		if( type == 'ajp' ) {
			binding[ 'AJPSecret' ] = AJPSecret;
		}
		return binding
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
			menuItem[ 'workingDirectory' ] = menuItem[ 'workingDirectory' ] ?: relativePath;
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
			if( fullPath contains ' ' ) {
				fullPath = '"' & fullPath & '"';
			}
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
		throw( message='Invalid Heap size [#heapSize#]', type="commandException" );
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
		if( isSingleServerMode() && getServers().count() ){

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
		}

		var job = wirebox.getInstance( 'interactiveJob' );
		var locVerbose = serverProps.verbose ?: false;

		// As a convenient shortcut, allow the serverConfigFile to be passed via the name parameter.
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
			// If we found a server.json by conventin and pull the web root from there, let's lock this in so we use it.
			// Otherwise, a server.json pointing to another webroot will cause us to try and put the server.json in the external web root
			serverProps.serverConfigFile = defaultServerConfigFile;
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

		// If CommandBox is in single server mode, set our current values in so the "single server" always represents the last name and web root that was used.
		if( isSingleServerMode() && getServers().count() ){
			if( len( defaultName ) ) {
				serverInfo.name = defaultName;
			} else {
				serverInfo.name = replace( listLast( defaultwebroot, "\/" ), ':', '');
			}
			serverInfo.webroot = defaultwebroot;
			if( !isNull( serverProps.serverConfigFile ) ) {
				serverInfo.serverConfigFile = serverProps.serverConfigFile;
			}
			setServerInfo( serverInfo );
		}

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

		var args = [
			variables.javaCommand,
			'-jar',
			variables.jarPath,
			'-stop',
			'--stop-port',
			val( serverInfo.stopsocket ),
			'-host',
			arguments.serverInfo.host,
			'--background',
			'false'
		];
		var results = { error = false, messages = "" };

		try{
			// Try to stop and set status back

	    	var processBuilder = createObject( "java", "java.lang.ProcessBuilder" );
	    	processBuilder.init( args );
	    	processBuilder.redirectErrorStream( true );
	    	var process = processBuilder.start();
	    	var inputStream = process.getInputStream();
	    	var exitCode = process.waitFor();

	    	var processOutput = toString( inputStream );

	    	if( exitCode > 0 ) {
	    		throw( message='Error stopping server', detail=processOutput );
	    	}

			//execute name=variables.javaCommand arguments=args timeout="50" variable="results.messages" errorVariable="errorVar";
			serverInfo.status 		= "stopped";
			serverInfo.statusInfo 	= {
				'command' : variables.javaCommand,
				'arguments' : args.tolist( ' ' ),
				'result' : processOutput
			};
			setServerInfo( serverInfo );
			results.messages = processOutput;
			return results;
		} catch (any e) {
			serverInfo.status 		= "unknown";
			serverInfo.statusInfo 	= {
				'command' : variables.javaCommand,
				'arguments' : args.tolist( ' ' ),
				'result' : processOutput ?: ''
			};
			setServerInfo( serverInfo );
			return { error=true, messages=e.message & e.detail };
		} finally {
			if( !isNull( process ) ) {
				process.destroy();
			}
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
		if( isSingleServerMode() ){
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
													 getAddressByHost( arguments.host ) );
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
					getAddressByHost( arguments.host ) );
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
	 * Find out what the IP address is for a given host
	 * @host.hint host to test port on such as localsite.com
 	 **/
	function getAddressByHost( required string host ){
		try {
			return java.InetAddress.getByName( arguments.host );
		} catch( java.net.UnknownHostException var e ) {
			// It's possible to have "fake" hosts such as mytest.localhost which aren't in DNS
			// or your hosts file.  Browsers will resolve them to localhost, but the call above
			// will fail with a UnknownHostException since they aren't real
			if( host.listLast( '.' ) == 'localhost' ) {
				return java.InetAddress.getByName( '127.0.0.1' );
			}
			rethrow;
		}
	}

	/**
	 * Find out if a given Process ID (PID) is a running java service
	 * @pidStr.hint PID to test on
 	 **/
	  function isProcessAlive( required pidStr, throwOnError=false ) {
		var result = "";
		try{
			if (fileSystemUtil.isWindows() ) {
				cfexecute(name='cmd', arguments='/c tasklist /FI "PID eq #pidStr#"', variable="result"  timeout="10");
				if (findNoCase("java", result) > 0 && findNoCase(pidStr, result) > 0) return true;
			} else if (fileSystemUtil.isMac() || fileSystemUtil.isLinux() ) {
				cfexecute(name='ps', arguments='-A -o pid,comm', variable="result" , timeout="10");
				var matchedProcesses = reMatchNoCase("(?m)^\s*#pidStr#\s.*java",result);
				if (matchedProcesses.len()) return true;
			}
		} catch ( any e ){
			if( throwOnError ) {
				rethrow;
			}
			rootLogger.error( 'Error checking if server PID was running: ' & e.message & ' ' & e.detail );
		}
		return false;
	}

	/**
	 * Logic to tell if a server is running
	 * @serverInfo.hint Struct of server information
	 * @quick When set to true, only the PID file is checked for on disk. When set to false, the OS is actually asked if the process is still running.
 	 **/
	function isServerRunning( required struct serverInfo, boolean quick=false ){
		if(fileExists(serverInfo.pidFile)){
			var serverPID = fileRead(serverInfo.pidFile);
			if( arguments.quick ) {
				thread action="run" name="check_#serverPID##getTickCount()#" serverPID=serverPID pidFile=serverInfo.pidFile {
					if(!isProcessAlive(attributes.serverPID,true)) {
						fileDelete(attributes.pidFile);
					}
				}
			} else {
				if(!isProcessAlive(serverPID,true)) {
					try {
						fileDelete(serverInfo.pidFile);
					} catch( any e ) {
						// If the file didn't exist, ignore it.
					}
					return false;
				}
			}
			return true;
		}
		return false;
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
			throw( message="The webroot cannot be empty!", type="commandException" );
		}

		servers[ serverID ] = serverInfo;

		// persist back safely
		setServers( servers );

	}

	function calculateServerID( webroot, name ) {

		if( isSingleServerMode() ){
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

		if( isSingleServerMode() && getServers().count() ){
			return getFirstServer();
		}

		if( len( arguments.serverConfigFile ) ){
			var foundServer = getServerInfoByServerConfigFile( arguments.serverConfigFile );
			// If another server used this server.json file but a different name, ignore it.
			if( structCount( foundServer ) && ( !len( arguments.name ) || arguments.name == foundServer.name ) ) {
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

		if( isSingleServerMode() && getServers().count() ){
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

		if( isSingleServerMode() && getServers().count() ){
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
		return getServers()
			.valueArray()
			.map( (s)=>s.name )
			.sort( 'textNoCase' );
	}

	/**
	* Get a server information struct by webrot, if not found it returns an empty struct
	* @webroot.hint The webroot to find
	*/
	struct function getServerInfoByWebroot( required webroot ){

		if( isSingleServerMode() && getServers().count() ){
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
		var statusInfo 	= {
			'command' : '',
			'arguments' : '',
			'result' : ''
		};

		if( !directoryExists( arguments.webroot ) ){
			statusInfo = { 'result':"Webroot does not exist, cannot start :" & arguments.webroot };
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
			'hostAlias'			: [],
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
			'name'					: "",
			'logDir' 				: "",
			'consolelogPath'		: "",
			'accessLogPath'			: "",
			'rewritesLogPath'		: "",
			'trayicon' 				: "",
			'libDirs' 				: "",
			'webConfigDir' 			: "",
			'serverConfigDir' 		: "",
			'serverHomeDirectory'	: "",
			'singleServerHome'		: false,
			'serverHome'			: "",
			'webroot'				: "",
			'webXML' 				: "",
			'webXMLOverride' 		: "",
			'webXMLOverrideActual'	: "",
			'webXMLOverrideForce'	: false,
			'HTTPEnable'			: true,
			'HTTP2Enable'			: true,
			'SSLEnable'				: false,
			'SSLPort'				: 1443,
			'AJPEnable'				: false,
			'AJPPort'				: 8009,
			'SSLCertFile'			: "",
			'SSLKeyFile'			: "",
			'SSLKeyPass'			: "",
			'clientCertCACertFiles'	: [],
			'clientCertMode'		: '',
			'clientCertSSLRenegotiationEnable': false,
			'clientCertEnable'		: false,
			'clientCertTrustUpstreamHeaders': false,
			'clientCertSubjectDNs'	: [],
			'clientCertIssuerDNs'	: [],
			'securityRealm'			: '',
			'clientCertCATrustStoreFile': '',
			'clientCertCATrustStorePass': '',
			'rewritesEnable'		: false,
			'rewritesConfig'		: "",
			'rewritesStatusPath'	: "",
			'rewritesConfigReloadSeconds': "",
			'basicAuthEnable'		: true,
			'authPredicate'	: '',
			'basicAuthUsers'		: {},
			'heapSize'				: '',
			'minHeapSize'			: '',
			'javaHome'				: '',
			'javaVersion'			: '',
			'directoryBrowsing'		: false,
			'JVMargs'				: "",
			'JVMargsArray'			: [],
			'runwarArgs'			: "",
			'runwarArgsArray'		: [],
			'runwarXNIOOptions'		: {},
			'runwarUndertowOptions'	: {},
			'cfengine'				: "",
			'cfengineSource'		: 'defaults',
			'restMappings'			: "",
			'sessionCookieSecure'	: false,
			'sessionCookieHTTPOnly'	: false,
			'engineName'			: "",
			'engineVersion'			: "",
			'WARPath'				: "",
			'serverConfigFile'		: "",
			'aliases'				: {},
			'errorPages'			: {},
			'accessLogEnable'		: false,
			'accessLogBaseName'		: '',
			'accessLogBaseDir'		: '',
			'GZipEnable'			: true,
			'GZipPredicate'			: '',
			'rewritesLogEnable'		: false,
			'trayOptions'			: {},
			'trayEnable'			: true,
			'dockEnable'			: true,
			'dateLastStarted'		: '',
			'openBrowser'			: true,
			'openBrowserURL'		: '',
			'preferredBrowser'		: '',
			'profile'				: '',
			'customServerFolder'	: '',
			'welcomeFiles'			: '',
			'maxRequests'			: '',
			'caseSensitivePaths'	: '',
			'exitCode'				: 0,
			'rules'					: [],
			'rulesFile'				: '',
			'blockCFAdmin'			: false,
			'blockSensitivePaths'	: false,
			'blockFlashRemoting'	: false,
			'allowedExt'			: '',
			'pidfile'				: '',
			'predicateFile'			: '',
			'trayOptionsFile'		: '',
			'SSLForceRedirect'		: false,
			'HSTSEnable'			: false,
			'HSTSMaxAge'			: 0,
			'HSTSIncludeSubDomains'	: false,
			'AJPSecret'				: '',
			'mimeTypes'				: {},
			'sites'					: [:],
			'listeners'				: {
										'http' : {},
										'ssl' : {},
										'ajp' : {}
									},
			'bindings'				: {},
			'mimeTypes'				: {},
			'RunwarAppenderLayout'	: '',
			'RunwarAppenderLayoutOptions'	: {},
			'startTimeout'			: 0,
			'useProxyForwardedIP'	: false,
			'webRules'				: [],
			'runwarJarPath'			: '',
			'multiContext'			: false,
			'ModCFMLSharedKey'		: '',
			'ModCFMLEnable'			: '',
			'ModCFMLCreateVDirs'	: '',
			'ModCFMLMaxContexts'	: '',
			'ModCFMLRequireSharedKey' : '',
			'JVMProperties'			: [],
			'fileCacheEnable'		: false,
			'fileCacheMaxFileSizeKB' : 0,
			'fileCacheTotalSizeMB' : 0,
			'defaultBaseURL'		: '',
			'authEnabled'			: '',
			'appFileSystemPath'		: '',
			'serverInfoJSON'		: '',
			'customHTTPStatusEnable': true,
			'processName'			: '',
			'webRulesText'			: ''
		};
	}

	struct function newSiteInfoStruct() {
		return newServerInfoStruct().filter( (k,v)=>listFindNoCase( 'sslkeyfile,useproxyforwardedip,clientcertsubjectdns,basicauthenable,casesensitivepaths,blocksensitivepaths,basicauthusers,hstsenable,sslport,webroot,webrules,errorpages,clientcertcatruststorepass,clientcerttrustupstreamheaders,http2enable,sslcertfile,accesslogenable,securityrealm,clientcertcatruststorefile,filecachetotalsizemb,sslenable,ajpport,blockflashremoting,sslforceredirect,filecachemaxfilesizekb,ajpenable,host,welcomefiles,clientcertmode,blockcfadmin,verbose,allowedext,authpredicate,httpenable,gzipenable,hstsmaxage,aliases,authenabled,mimetypes,filecacheenable,clientcertcacertfiles,clientcertsslrenegotiationenable,clientcertenable,gzippredicate,clientcertissuerdns,hstsincludesubdomains,port,sslkeypass,directorybrowsing,ajpsecret,profile,webRulesText,hostAlias', k ) );
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
	function completeProperty( required directory, all=false, asSet=false, paramSoFar='' ) {
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
			props = JSONService.addProp( props, '', '', {
				'web' : {
					'bindings' : {
						'HTTP' : {
							'listen' : '',
							'IP' : '',
							'port' : '',
							'host' : ''
						},
						'SSL' : {
							'listen' : '',
							'IP' : '',
							'port' : '',
							'host' : '',
							// TODO: Allow multipe certs specified in the same binding
							'certFile' : '',
							'keyFile' : '',
							'keyPass' : '',
							'clientCert' : {
								'mode' : '',
								'CACertFiles' : '',
								'CATrustStoreFile' : '',
								'CATrustStorePass' : ''
							}
						},
						'AJP' : {
							'listen' : '',
							'IP' : '',
							'port' : '',
							'host' : '',
							'secret' : ''
						}
					}
				}
			} );

			// Suggest server scripts
			props = JSONService.addProp( props, '', '', {
				'scripts' : {
					'preServerStart' : '',
					'onServerInstall' : '',
					'onServerInitialInstall' : '',
					'onServerStart' : '',
					'onServerStop' : '',
					'preServerForget' : '',
					'postServerForget' : ''
				}
			} );

			// Add in complete for sites
			if( len( paramSoFar ) ) {
				// Parse what they've typed so far
				var bracketNotationSoFar = JSONService.toBracketNotation( paramSoFar );
				var tokenizedSoFar = JSONService.tokenizeProp( paramSoFar );
				// Only if they've typed sites.something so far and appear to have completed the site n
				var siteNameSoFar = tokenizedSoFar[2] ?: '';
				if( tokenizedSoFar.len() > 1 && lcase( bracketNotationSoFar ).startsWith( '[ "sites" ]' )
					&& ( tokenizedSoFar.len() > 2
					|| paramSoFar.endsWith('.')
					|| siteNameSoFar.endsWith(']')
						|| ( len( siteNameSoFar ) > 2 && siteNameSoFar.startsWith('"') && siteNameSoFar.endsWith('"') ) ) ) {
					evaluate( "local.dummy#bracketNotationSoFar#=true" );
					if( isStruct( dummy ) && dummy.keyExists( 'sites' ) && isStruct( dummy.sites )  && dummy.sites.count() ) {
						var siteName = dummy.sites.keyArray().first();
						var userTyped = tokenizedSoFar[1] & ( siteNameSoFar contains '[' ? '' : '.' ) & siteNameSoFar;
						var siteProperties = getDefaultServerJSON().web;
						siteProperties.default=false;
						props = JSONService.addProp( props, userTyped, '[ "sites" ][ "#siteName#" ]', { 'sites' : { '#siteName#' : siteProperties } } );
					}
				}
			}
		}
		if( asSet ) {
			props = props.map( function( i ){ return i &= '='; } );
		}

		return props;
	}

	/**
	* Dynamic completion for server names, sorted by last started
	*/
	function serverNameComplete() {

		return getservers()
			.valueArray()
			.sort( (a,b)=>{
				if( len( a.dateLastStarted ) && len( b.dateLastStarted ) ) {
					return dateDiff( 's', a.dateLastStarted, b.dateLastStarted );
				} else {
					return len( b.dateLastStarted ) - len( a.dateLastStarted );
				}
			} )
			.map( (s,i)=>return { name : s.name, group : 'Server Names', sort : i } );
	}


	/**
	* Loads config settings from env vars or Java system properties
	*/
	function loadOverrides( serverJSON, serverInfo, boolean verbose=false ){
		var debugMessages = [];
		var job = wirebox.getInstance( 'interactiveJob' );
		var overrides={};

		// Look for individual BOX settings to import.
		var processVarsUDF = function( envVar, value, string source ) {
			// Loop over any that look like box_server_xxx
			if( envVar.len() > 11 && reFindNoCase( 'box[_\.]server[_\.]', left( envVar, 11 ) ) ) {
				// proxy_host gets turned into proxy.host
				// Note, the asssumption is made that no config setting will ever have a legitimate underscore in the name
				var name = right( envVar, len( envVar ) - 11 ).replace( '_', '.', 'all' );
				debugMessages.append( 'Overridding [#name#] with #source# [#envVar#]' );
				JSONService.set( JSON=overrides, properties={ '#name#' : value }, thisAppend=true );
			}
		};

		// Get all OS env vars
		var envVars = system.getenv();
		for( var envVar in envVars ) {
			processVarsUDF( envVar, envVars[ envVar ], 'OS environment variable' );
		}

		// Get all System Properties
		var props = system.getProperties();
		for( var prop in props ) {
			processVarsUDF( prop, props[ prop ], 'system property' );
		}

		// Get all box environemnt variable
		var envVars = systemSettings.getAllEnvironmentsFlattened();
		for( var envVar in envVars ) {
			processVarsUDF( envVar, envVars[ envVar ], 'box environment variable' );
		}

		if( overrides.keyExists( 'profile' ) ) {
			serverInfo.envVarHasProfile=true
		}

		if( verbose && debugMessages.len() ) {
			job.start( 'Overriding server.json values from env vars' );
			debugMessages.each( (l)=>job.addLog( l ) );
	    	job.complete( verbose );
		}
		JSONService.mergeData( serverJSON, overrides );
	}



	/**
	* Nice wrapper to run a server script
	*
	* @scriptName Name of the server script to run
	* @directory The web root
	* @ignoreMissing Set true to ignore missing server scripts, false to throw an exception
	* @interceptData An optional struct of data if this server script is being fired as part of an interceptor announcement.  Will be loaded into env vars
	*/
	function runScript( required string scriptName, string directory=shell.pwd(), boolean ignoreMissing=true, interceptData={} ) {
			if( !isNull( interceptData.serverJSON ) ){
				var serverJSON = interceptData.serverJSON;
			} else if( !isNull( interceptData.serverInfo.name ) && len( interceptData.serverInfo.name ) ){
				var serverDetails = resolveServerDetails( { name=interceptData.serverInfo.name } );
				if( serverDetails.serverIsNew ) {
					return;
				}
				var serverJSON = serverDetails.serverJSON;
				systemSettings.expandDeepSystemSettings( serverJSON );
				loadOverrides( serverJSON, serverDetails.serverInfo, serverDetails.serverInfo.verbose ?: false );
			} else {
				consoleLogger.warn( 'Could not find server for script [#arguments.scriptName#].' );
				return;
			}
			var serverJSONScripts = duplicate( serverJSON.scripts ?: {} );
			getDefaultServerJSON().scripts.each( (k,v)=>{
				// Append existing scripts
				if( serverJSONScripts.keyExists( k ) ) {
					serverJSONScripts[ k ] &= '; ' & v
				// Merge missing ones
				} else {
					serverJSONScripts[ k ] = v;
				}
			} );
			// If there is a scripts object with a matching key for this interceptor....
			if( serverJSONScripts.keyExists( arguments.scriptName ) ) {

				// Skip this if we're not in a command so we don't litter the default env var namespace
				if( systemSettings.getAllEnvironments().len() > 1 ) {
					systemSettings.setDeepSystemSettings( interceptData );
				}

				// Run preXXX package script
				runScript( 'pre#arguments.scriptName#', arguments.directory, true, interceptData );

				var thisScript = serverJSONScripts[ arguments.scriptName ];
				consoleLogger.debug( '.' );
				consoleLogger.warn( 'Running server script [#arguments.scriptName#].' );
				consoleLogger.debug( '> ' & thisScript );

				// Normally the shell retains the previous exit code, but in this case
				// it's important for us to know if the scripts return a failing exit code without throwing an exception
				shell.setExitCode( 0 );

				// ... then run the script! (in the context of the package's working directory)
				var previousCWD = shell.pwd();
				shell.cd( arguments.directory );
				shell.callCommand( thisScript );
				shell.cd( previousCWD );

				// If the script ran "exit"
				if( !shell.getKeepRunning() ) {
					// Just kidding, the shell can stay....
					shell.setKeepRunning( true );
				}

				if( shell.getExitCode() != 0 ) {
					throw( message='Server script returned failing exit code (#shell.getExitCode()#)', detail='Failing script: #arguments.scriptName#', type="commandException", errorCode=shell.getExitCode() );
				}

				// Run postXXX package script
				runScript( 'post#arguments.scriptName#', arguments.directory, true, interceptData );

			} else if( !arguments.ignoreMissing ) {
				consoleLogger.error( 'The script [#arguments.scriptName#] does not exist in this server.' );
			}
	}

	function isSingleServerMode() {
		return configService.getSetting( 'server.singleServerMode', false );
	}


}

