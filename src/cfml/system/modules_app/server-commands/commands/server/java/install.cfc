/**
 * Install a version of Java for your servers to use.
 * .
 * {code:bash}
 * server java install openjdk11
 * {code}
 * 
 * Set a Java install to be the default server JRE at the same time you install with --setDefault
 * .
 * {code:bash}
 * server java install openjdk11 --setDefault
 * {code}
 * 
 * Note, the default will be set to exactly what you type, so if you don't type a specific release version
 * then CommadnBox will still check the API for the latest version every time and download on demand.
 *
 * To set a default version of Java and have CommandBox never check again, set a very specific release version
 * .
 * {code:bash}
 * server java install openjdk8_jdk8u192-b12 --setDefault
 * {code}
 * 
 **/
component aliases='java install' {

	// DI
	property name="javaService" inject="JavaService";

	/**
	* @ID Full name of the Java install you wish to remove
	* @id.options openjdk8,openjdk9,openjdk10,openjdk11
	* @verbse Show verbose installation information
	* @setDefault Set this Java install to be the default after installing
	*/
	function run(
		required string ID,
		boolean verbose=false,
		boolean setDefault=false
	){
		try {
			javaService.installJava( ID, verbose );	
		} catch( endpointException var e ) {
			error( e.message, e.detail ?: '' );
		}
		
		if( setDefault ) {
			configService.setSetting( 'server.defaults.jvm.javaVersion', ID );
		}
		
		command( 'server java list' ).run();
	}


}