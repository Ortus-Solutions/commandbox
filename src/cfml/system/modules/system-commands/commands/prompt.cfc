/**
 * Set prompt of the shell to your own string.  This defaults to "CommandBox>".  You can revert to the
 * default prompt by using the "reload" command.  Don't forget to include a space at the end of the prompt
 * so it doesn't run up against your text.
 * .
 * {code:bash}
 * prompt "My Cool Shell> "
 * {code}
 **/
component extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {

	/**
	* @prompt.hist The new text to use as the shell prompt
	**/
	function run( required prompt )  {
		shell.setPrompt( arguments.prompt );
	}

}