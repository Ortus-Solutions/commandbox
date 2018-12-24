/**
 * Set a default version of Java for your servers to use.
 * .
 * {code:bash}
 * server java setDefault openjdk11
 * {code}
 * 
 * install the Java version at the same time with --setDefault
 * .
 * {code:bash}
 * server java setDefault openjdk11 --install
 * {code}
 * 
 * Note, the default will be set to exactly what you type, so if you don't type a specific release version
 * then CommadnBox will still check the API for the latest version every time and download on demand.
 *
 * To set a default version of Java and have CommandBox never check again, set a very specific release version
 * .
 * {code:bash}
 * server java setDefault openjdk8_jdk8u192-b12
 * {code}
 * 
 **/
component aliases='java setDefault' {

	// DI
	property name="javaService" inject="JavaService";

	/**
	* @ID Full name of the Java install you wish to remove
	* @ID.optionsUDF	javaVersionComplete
	* @verbse Show verbose installation information
	* @install Install this version of Java at the same time
	*/
	function run(
		required string ID,
		boolean verbose=false,
		boolean install=false
	){
		configService.setSetting( 'server.defaults.jvm.javaVersion', ID );

		if( install ) {
			try {
				javaService.installJava( ID, verbose );	
			} catch( endpointException var e ) {
				error( e.message, e.detail ?: '' );
			}
		}
		
		command( 'server java list' ).run();
	}

	/**
	* Complete java versions
	*/	
	function javaVersionComplete() {
		return javaService
			.listJavaInstalls()
			.keyArray()
			.map( ( i ) => {
				return { name : i, group : 'Java Versions' };
			} );
	}

}