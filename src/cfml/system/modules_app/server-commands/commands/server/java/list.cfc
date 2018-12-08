/**
 * List the installed Java installations for you to start servers with
 * .
 * {code:bash}
 * server java list
 * {code}
 **/
component {

	// DI
	property name="javaService" inject="JavaService";
	property name="packageService" inject="PackageService";

	/**
	* 
	*/
	function run(){
		var serverDefaultJvmJavaVersion = ConfigService.getSetting( 'server.defaults.jvm.javaVersion', '' );
		
		print
			.line()
			.boldCyan( 'Java #server.java.version# (#server.java.vendor#)' );	
		if( !serverDefaultJvmJavaVersion.len() ) {
			print.redText( '   (Default)' );	
		}
		print
			.line()
			.indentedLine( fileSystemUtil.getJREExecutable().reReplace( 'bin[\\/]java(.exe)?$', '' ) )
			.indentedYellowLine( 'This is the Java installation in use by the CLI.  it cannot be removed.' );
		
		print.line();
		
		javaService.listJavaInstalls().each( function( slug, jVer ) {
			
			print.boldCyanText( slug );
			if( serverDefaultJvmJavaVersion == slug ) {
				print.redText( '   (Default)' );
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
		
		print
			.yellowLine( 'To set a different default Java version for your servers, run: ')
			.indentedBoldYellow( 'config set server.defaults.jvm.javaVersion=openjdk11' );
		
	}


}