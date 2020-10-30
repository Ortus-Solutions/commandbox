/**
 * List the installed Java installations for you to start servers with
 * .
 * {code:bash}
 * server java list
 * {code}
 **/
component aliases='java list' {

	// DI
	property name="javaService"		inject="JavaService";
	property name="packageService"	inject="PackageService";
	property name="java"			inject="commandbox.system.endpoints.java";

	/**
	* 
	*/
	function run(){
		var serverDefaultJvmJavaVersion = ConfigService.getSetting( 'server.defaults.jvm.javaVersion', '' );
		var expandedDefault = java.getDefaultName( serverDefaultJvmJavaVersion );
		var foundDefault = false;
		
		print
			.line()
			.boldCyan( 'Java #server.java.version# (#server.java.vendor#)' );	
		if( !serverDefaultJvmJavaVersion.len() ) {
			print.redText( '   (Default)' );	
		}
		print
			.line()
			.indentedLine( fileSystemUtil.getJREExecutable().reReplace( 'bin[\\/]java(.exe)?$', '' ) )
			.indentedYellowLine( 'This is the Java installation in use by the CLI, it cannot be removed.' );
		
		print.line();
		
		javaService.listJavaInstalls().each( function( slug, jVer ) {
			
			print.boldCyanText( slug );
			// Checking the original string as well as the expanded, since the default java install doesn't have to be from the Java endpoint
			if( serverDefaultJvmJavaVersion == slug || expandedDefault == slug ) {
				print.redText( '   (Default)' );
				foundDefault = true;
			}
			print.line();
			
			var packageDir = jVer.directory & '/' & jVer.name;
			if( packageService.isPackage( packageDir ) ) {
				
				var boxJSON = packageService.readPackageDescriptor( packageDir );
				print
					.indentedLine( boxJSON.author )
					.indentedLine( boxJSON.homepage )
					.line();
			}
		} );
		
		if( serverDefaultJvmJavaVersion.len() && !foundDefault ) {
			print
				.yellowText( 'You have a default Java version set to [' ).boldYellow( serverDefaultJvmJavaVersion ) .yellowLine( '] but it didn''t match any of your installed versions.')
				.yellowLine( 'If you specified a partial version, it might download a new version when it comes avaialble.  If your default version' )
				.yellowLine( 'simply isn''t installed, it will get downloaded automatically the next time you start a server.' )
				.line();
		}
		print
			.yellowLine( 'To set a different default Java version for your servers, run: ')
			.indentedBoldYellow( 'server java setDefault openjdk11' );
		
	}


}