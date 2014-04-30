/**
 * Reload CLI
 **/
component persistent="false" extends="cli.BaseCommand" aliases="cls" {

	/**
	 * @clearScreen.hint clears the screen after reload
  	 **/
	function reload( Boolean clearScreen=true )  {
		shell.reload(clearScreen);
	}

}