/**
 * Reload CommandBox.  This is a maintenance operation to recreate the shell and reload all commands in
 * the command folders.  Use this if developing commands to quickly reload your changes after modifying
 * the command's CFC file.  All files will be recreated except /system/BootStrap.cfm.
 * .
 * {code:bash}
 * reload
 * {code}
 **/
component aliases="r" excludeFromHelp=true {

	/**
	 * @clearScreen.hint Clears the screen after reload
  	 **/
	function run( Boolean clearScreen=true )  {
		print.boldLine( 'Reloading shell...' );
		shell.reload( arguments.clearScreen );
	}

}
