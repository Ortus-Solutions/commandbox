/**
 * Install a new top-level command namespace
 **/
component  persistent="false" extends="cli.BaseCommand" aliases="" excludeFromHelp=false {

	/**
	 * @path.hint The path of the namespace to install
	 **/
	function run( required string path )  {
		print.redLine( 'Not implemented' );
		
	}

	
}