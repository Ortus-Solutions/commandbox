/**
 * Run cfpm for an Adobe ColdFuson 2021+ server
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
   **/
component aliases='cfpm' {

	property name='serverService' inject='ServerService';

	function run(){
		
		// Since any args passed in are sent on to cfpm, we can't allow the user to send us details of what server they want.
		// Therefore, this command only works in the web root of the server and if the Adobe server is the default one.
		var serverDetails = serverService.resolveServerDetails( {} );
		
		if( serverDetails.serverIsNew ) {
			error( 'No Server found in [#getCWD()#]' );
		}
		
		var serverInfo = serverDetails.serverInfo;		
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
		 
		command( 'run' )
			.params( cmd )
			.run( echo=true );

	}

}
