/**
 * Runs a package script, by name.  Scripts are stored in box.json.
 * .
 * {code:bash}
 * run-script myScript
 * {code}
 * .
 * Positional parameters can be passed and will be available as environment variables inside the script as ${1}, ${2}, etc
 * .
 * {code:bash}
 * run-script myScript param1 param2
 * {code}
 * .
 * .
 * Named parameters can be passed and will be available as environment variables inside the script as ${name1}, ${name2}, etc
 * Note in this case, ALL parameters much be named including the scriptName param to the command.
 * .
 * {code:bash}
 * run-script scriptName=myScript name1=value1 name2=value2
 * {code}
 * .
 **/
component aliases="run-script" {

	property name="packageService" inject="PackageService";

	/**
	 * @scriptName Name of the script to run
	 * @scriptName.optionsUDF scriptNameComplete
	 **/
	function run( required string scriptname ){

		// package check
		if( !packageService.isPackage( getCWD() ) ) {
			error( '#getCWD()# is not a package!' );
		}

		// Add any additional arguments as env vars for the script to access
		arguments
			.filter( ( k, v ) => k != 'scriptName' )
			.each( ( k, v ) => {
				// Decrement positional params so they start at 1
				if( isNumeric( k ) && k > 1 ) {
					k -= 1;
				}
				systemSettings.setSystemSetting( k, v );
			} );

		packageService.runScript( scriptName=arguments.scriptName, ignoreMissing=false );

	}

	function scriptNameComplete() {
		var boxJSON = packageService.readPackageDescriptor( shell.pwd() );
		return boxJSON.scripts.keyArray();
	}

}
