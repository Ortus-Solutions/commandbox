/**
 * Set prompt of the shell to your own string
 **/
component extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {

	/**
	* @prompt.hist The new text to use as the shell prompt
	**/
	function run( String prompt="" )  {
		shell.setPrompt(prompt);
	}

}