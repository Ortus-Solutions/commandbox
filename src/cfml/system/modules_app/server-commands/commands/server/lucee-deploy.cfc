/**
 * Copy a file to the deploy folder of a local Lucee server
 * .
 * {code:bash}
 * server lucee-deploy myFile.lex
 *
 * server lucee-deploy https://domain.com/path/to/Lucee-core-patch.lco
 * {code}
 * 
 * Override the name of the server with the servername parameter
 * {code:bash}
 * server lucee-deploy myFile.lex myServer
 * {code}
 * 
 * - Otherwise, if this command is being run inside of a server-related interceptor, capture the name of the server from the intercept data and use that server
 * - otherwise, look for any Lucee server whose webroot points to the current working directory of the shell and use the first found
 * - Otherwise, look for a LUCEE_DEPLOY_DIRECTORY env var and use this as the deploy directory (can be relative or absolute)
 *
 **/
component {

	property name="ServerService" inject="ServerService";

	/**
	 * @deployable Relative or absolute path or HTTP URL to an lco or lex file
	 * @deployable.optionsFileComplete true
	 * @serverName The name of the server to deploy to
	 * @serverName.optionsUDF serverNameComplete
	 **/
	function run( required string deployable, string serverName='' ) {

		var luceeDeployDirectory = "";

		var serverInfo                    = {};
		var LUCEE_DEPLOY_DIRECTORY                  = systemSettings.getSystemSetting( "LUCEE_DEPLOY_DIRECTORY", "" );
		var interceptData_serverInfo_name = systemSettings.getSystemSetting( "interceptData.SERVERINFO.name", "" );

		if ( configService.getSetting( "server.singleServerMode", false ) && serverService.getServers().count() ) {
			serverInfo  = serverService.getFirstServer();
			luceeDeployDirectory = serverInfo.serverHomeDirectory & "/WEB-INF/lucee-server/deploy/";
			// If we're running inside of a server-related package script, use that server
		} else if( serverName.len() ) {			
			serverInfo = serverService.getServerInfoByName( serverName );
			if ( !( serverInfo.CFengine contains "lucee" ) ) {
				error(
						"Server [#serverName#] is of type [#serverInfo.cfengine#] and not a Lucee server."
					);
			}
			luceeDeployDirectory = serverInfo.serverHomeDirectory & "/WEB-INF/lucee-server/deploy/";
		} else if ( interceptData_serverInfo_name != "" ) {
			print.yellowLine( "Using interceptData to load server [#interceptData_serverInfo_name#]" );
			serverInfo = serverService.getServerInfoByName( interceptData_serverInfo_name );
			if ( !( serverInfo.CFengine contains "lucee" ) ) {
				variables.print
					.redLine(
						"Server [#interceptData_serverInfo_name#] is of type [#serverInfo.cfengine#] and not a Lucee server.  Ignoring."
					);
				return;
			}
			luceeDeployDirectory = serverInfo.serverHomeDirectory & "/WEB-INF/lucee-server/deploy/";
		} else {
			// Look for the first Lucee server using the current working directory as its web root
			var webroot = getCWD();
			var servers = serverService.getServers();
			for ( var serverID in servers ) {
				var thisServerInfo = servers[ serverID ];
				if (
					fileSystemUtil.resolvePath(
						path           = thisServerInfo.webroot,
						forceDirectory = true
					) == webroot
					&& thisServerInfo.CFengine contains "lucee"
				) {
					serverInfo  = thisServerInfo;
					luceeDeployDirectory = serverInfo.serverHomeDirectory & "/WEB-INF/lucee-server/deploy/";
					print.yellowLine( "Found server [#serverInfo.name#] in current directory." );
					break;
				}
			}
			if ( !serverInfo.count() ) {
				var serverDetails = serverService.resolveServerDetails( {} );
				serverInfo        = serverDetails.serverInfo;
				if ( !serverDetails.serverIsNew && ( serverInfo.CFengine contains "lucee" ) ) {
					luceeDeployDirectory = serverInfo.serverHomeDirectory & "/WEB-INF/lucee-server/deploy/";
				} else if ( !serverDetails.serverIsNew ) {
					variables.print
						.redLine(
							"Server [#serverInfo.name#] in [#webroot#] is of type [#serverInfo.cfengine#] and not an Lucee server.  Ignoring."
						);
				}
			}

		}
		if ( !len( luceeDeployDirectory ) && LUCEE_DEPLOY_DIRECTORY != "" ) {
			variables.print
				.yellowLine( "Using LUCEE_DEPLOY_DIRECTORY environment variable to deploy [#LUCEE_DEPLOY_DIRECTORY#]" );
			luceeDeployDirectory = resolvepath( path=LUCEE_DEPLOY_DIRECTORY, forceDirectory=true );
		}

		if ( !len( luceeDeployDirectory ) ) {
			error(
					"No Lucee server found in [#getCWD()#]. Specify the server you want by setting the name of your server into the LUCEE_DEPLOY_DIRECTORY environment variable."
				);
		}

		if( deployable.left(4) != 'http' ) {
			// Make relative paths absolute
			deployable = resolvePath( deployable );
		}

		print.line().greenLine( "Deploying ")
		 .yellowLine( "   [#deployable#] ")
		 .line( "to ")
		 .yellowLine( "   [#luceeDeployDirectory#]" );

		directoryCreate( luceeDeployDirectory, true, true );
		
		// handles HTTP as well as local file paths
		fileCopy( deployable, luceeDeployDirectory );
	}

	function serverNameComplete() {
		return serverService
			.serverNameComplete();
	}

}
