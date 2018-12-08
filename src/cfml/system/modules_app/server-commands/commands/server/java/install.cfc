/**
 * Install a version of Java for your servers to use.
 * .
 * {code:bash}
 * server java install openjdk11
 * {code}
 **/
component aliases='java install' {

	// DI
	property name="javaService" inject="JavaService";

	/**
	* @ID Full name of the Java install you wish to remove
	* @verbse Show verbose installation information
	*/
	function run(
		required string ID,
		boolean verbose=false
	){
		try {
			javaService.installJava( ID, verbose );	
		} catch( endpointException var e ) {
			error( e.message, e.detail ?: '' );
		}
		
		command( 'server java list' ).run();
	}


}