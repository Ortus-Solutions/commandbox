/**
 * Outputs CommandBox version currently installed
 * .
 * {code:bash}
 * version
 * {code}
 * .
 * Show the CLI Loader version with the --loader flag
 * .
 * {code:bash}
 * version --loader
 * {code}
 * .
 **/
component aliases="ver" {

	/**
	* @loader.hint Show the version of the CLI loader
	*/
	function run( boolean loader=false )  {
		if( arguments.loader ) {
			print.line( 'CLI Loader #shell.getLoaderVersion()#' );
		} else {
			print.line( 'CommandBox #shell.getVersion()#' );
		}
	}

}