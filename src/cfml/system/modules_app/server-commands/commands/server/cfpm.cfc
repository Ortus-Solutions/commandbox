/**
 * Run cfpm for an Adobe ColdFuson 2021+ server.  If there is more than one server started in the current working
 * directory, this command will search for the first Adobe 2021+ server and use that.
 * If this command is run as part of a server package script, it will applly to the server being started.
 * .
 * Open the cfpm shell
 * .
 * {code:bash}
 * cfpm
 * {code}
 * .
 * This command has no arguments.  Any args passed positionally will be sent along to the cfpm binary
 * .
 * {code:bash}
 * cfpm install feed
 * {code}
 * .
 * If there is more than one Adobe 2021+ server started in a given directory, you can specific the server you want
 * by setting the server name into the CFPM_SERVER environment variable.  Note this works from any directory.
 * Make sure to clear the env var afterwards so it doesn't surprise you on later usage of this command in the same shell.
 * .
 * {code:bash}
 * set CFPM_SERVER=myTestServer
 * cfpm install feed
 * env clear CFPM_SERVER
 * {code}
**/
component aliases='cfpm' {

	property name='serverService' inject='ServerService';

	function run(){

		var serverInfo = {};
		var cfpm_server = systemSettings.getSystemSetting( 'CFPM_SERVER', '' );
		var interceptData_serverInfo_name = systemSettings.getSystemSetting( 'interceptData.SERVERINFO.name', '' );

		if( configService.getSetting( 'server.singleServerMode', false ) && serverService.getServers().count() ){
			serverInfo = serverService.getFirstServer();
		// If we're running inside of a server-related package script, use that server
		} else if( interceptData_serverInfo_name != '' ) {
			print.yellowLine( 'Using interceptData to load server [#interceptData_serverInfo_name#]' );
			serverInfo = serverService.resolveServerDetails( { name=interceptData_serverInfo_name } ).serverInfo;
			if( !(serverInfo.engineName contains 'adobe' && val( listFirst( serverInfo.engineVersion, '.' ) ) >= 2021  ) ){
				print.redLine( 'Server [#interceptData_serverInfo_name#] is of type [#serverInfo.cfengine#] and not an Adobe 2021+ server.  Ignoring.' );
				return;
			}
		// Allow an env var hint to tell us what server to use
		// CFPM_SERVER=servername
		} else if( cfpm_server != '' ) {
			print.yellowLine( 'Using CFPM_SERVER environment variable to load server [#cfpm_server#]' );
			var serverDetails = serverService.resolveServerDetails( { name=cfpm_server } );
			if( serverDetails.serverIsNew ) {
				error( 'Server [#cfpm_server#] specified in CFPM_SERVER environment variable does not exist.' );
				return;
			}
			serverInfo = serverDetails.serverInfo;
			if( !(serverInfo.engineName contains 'adobe' && val( listFirst( serverInfo.engineVersion, '.' ) ) >= 2021  ) ){
				print.redLine( 'Server [#cfpm_server#] is of type [#serverInfo.cfengine#] and not an Adobe 2021+ server.  Ignoring.' );
				return;
			}
		} else {
			// Fallback is to look for the first Adobe 2021+ server using the current working directory as its web root
			var webroot = fileSystemUtil.resolvePath( getCWD() );
			var servers = serverService.getServers();
			for( var serverID in servers ){
				var thisServerInfo = servers[ serverID ];
				if( fileSystemUtil.resolvePath( path=thisServerInfo.webroot, forceDirectory=true ) == webroot
				 && thisServerInfo.engineName contains 'adobe'
				 && val( listFirst( thisServerInfo.engineVersion, '.' ) ) >= 2021 ){
					serverInfo = thisServerInfo;
					print.yellowLine( 'Found server [#serverInfo.name#] in current directory.' );
					break;
				}
			}
			if( !serverInfo.count() ) {
				var serverDetails = serverService.resolveServerDetails( {} );

				if( serverDetails.serverIsNew ) {
					print.redLine( 'No Adobe 2021+ server found in [#getCWD()#]', 'Specify the server you want by setting the name of your server into the CFPM_SERVER environment variable.' );
					return;
				}

				serverInfo = serverDetails.serverInfo;
				if( !(serverInfo.engineName contains 'adobe' && val( listFirst( serverInfo.engineVersion, '.' ) ) >= 2021  ) ){
					print.redLine( 'Server [#serverInfo.name#] in [#getCWD()#] is of type [#serverInfo.cfengine#] and not an Adobe 2021+ server.  Ignoring.' );
					return;
				}
			}

		}

		// ASSERT: At this point, we've found a specific Adobe 2021 server via env var, intercept data, or web root convention.

		var cfpmPath = resolvePath( serverInfo.serverHomeDirectory ) & 'WEB-INF/cfusion/bin/cfpm';

		if( !fileExists( cfpmPath & '.bat' ) ) {
			error( 'cfpm not found at [#cfpmPath#]' );
		}

		if( fileSystemUtil.isWindows() ) {
			var cmd = '"#cfpmPath#.bat"';
		} else {
			var cmd = '#fileSystemUtil.getNativeShell()# "#cfpmPath#.sh"';
		}
		var i = 0;
		while( !isNull( arguments[++i] ) ) {
			cmd &= ' #arguments[i]#';
		}

		// The user's OS may not have a JAVA_HOME set up
		if( systemSettings.getSystemSetting( 'JAVA_HOME', '' ) == '' ) {
			systemSettings.setSystemSetting( 'JAVA_HOME', fileSystemUtil.getJREExecutable().reReplaceNoCase( '(/|\\)bin(/|\\)java(.exe)?', '' ) );
		}
		print.toConsole();
		var output = command( 'run' )
			.params( cmd )
			// Try to contain the output if we're in an interactive job and there are arguments (no args opens the cfpm shell)
			.run( echo=true, returnOutput=( job.isActive() && arguments.count() ) );

		if( job.isActive() && arguments.count() ) {
			print.text( output );
		}

	}

}
