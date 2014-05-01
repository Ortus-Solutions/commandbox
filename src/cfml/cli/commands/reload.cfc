/**
 * Reload CLI. This is a maintenance operatin to recreate the shell and reload all commands in the command folder.
 * Use this if developing commands to quickly reload your changes after modifying the command's CFC file.
 **/
component persistent="false" extends="cli.BaseCommand" aliases="r" excludeFromHelp=true {

	/**
	 * @clearScreen.hint Clears the screen after reload
  	 **/
	function run( Boolean clearScreen=true )  {
		print.text( 'Reloading shell...' );
		shell.reload(clearScreen);
	}

}