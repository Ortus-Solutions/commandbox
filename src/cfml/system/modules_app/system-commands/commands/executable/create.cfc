/**
 * Create an OS executable file that is an alias to a script.
 * .
 * {code:bash}
 * executable create myExecutable "box myScript.bxs"
 * {code}
 *
 **/
component {
	property name="executableService" inject="ExecutableService@system-commands";

	/**
	 * @alias The name of the executable to create
	 * @commandText The command that the executable will run
	 **/
	function run(
		required string alias,
		required string commandText
		) {

		try {
			var location = command( "!" & (fileSystemUtil.isWindows() ? "where" : "which") ).params( alias ).run( returnOutput=true );
			location = trim( location );
			location = getCanonicalPath( location );
		} catch ( any e ) {
			location = "";
		}

		var scriptLocation = executableService.createAlias( alias, commandText );
		
		if( len( location ) ) {
			print.redLine( "NOTE: Executable alias [#alias#] already exists at [#location#]!  Your module executable alias may not work!" );
		}

		print.line(  "Created executable alias [#alias#] for command [#commandText#] at location [#scriptLocation#]" );
	}

}