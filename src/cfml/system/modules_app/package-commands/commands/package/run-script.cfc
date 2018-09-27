/**
 * Runs a package script, by name.  Scripts are stored in box.json.
 * .
 * {code:bash}
 * run-script myScript
 * {code}
 * .
 **/
component aliases="run-script" {

	property name="packageService" inject="PackageService";

	/**
	 * @scriptName Name of the script to run
	 * @scriptName.optionsUDF scriptNameComplete
	 * @directory The path to your package
	 **/
	function run( required string scriptname, string directory='' ){

		// This will make each directory canonical and absolute
		arguments.directory = resolvePath( arguments.directory );

		// package check
		if( !packageService.isPackage( arguments.directory ) ) {
			return error( '#arguments.directory# is not a package!' );
		}

		packageService.runScript( arguments.scriptName, arguments.directory, false );

	}

	function scriptNameComplete() {
		var boxJSON = packageService.readPackageDescriptor( shell.pwd() );
		return boxJSON.scripts.keyArray();
	}

}
