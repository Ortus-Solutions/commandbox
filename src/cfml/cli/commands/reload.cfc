/**
 * Reload CLI
 **/
component persistent="false" extends="cli.BaseCommand" aliases="" {

	/**
	 * @clearScreen.hint clears the screen after reload
  	 **/
	function run( Boolean clearScreen=true )  {
		print.text( 'Reloading shell...' );
		shell.reload(clearScreen);
	}

}