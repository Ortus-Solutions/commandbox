/**
 * Uninstall a version of Java that you don't need any longer.
 * You must use the FULL name of the version to remove any ambiguity.
 * .
 * {code:bash}
 * server java uninstall openjdk9_jre_x64_windows_hotspot_jdk-9.0.4+11
 * {code}
 **/
component aliases='java uninstall' {

	// DI
	property name="javaService" inject="JavaService";

	/**
	* @ID Full name of the Java install you wish to remove
	* @ID.optionsUDF	javaVersionComplete
	*/
	function run(
		required string ID
	){
		if( !javaService.javaInstallExists( ID ) ) {
			error(
				'[#ID#] is not a valid java install. Please use the full name that shows in the "server java list" command.',
				'Valid names are [#javaService.listJavaInstalls().keyList()#]'
			);
		}

		javaService.uninstallJava( ID );

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