/**
* I am the base command implementation-
**/
component {
	
	cr = chr(10);
	
	function init(shell) {
		variables.shell = shell;
		print = new commandbox.system.util.PrintBuffer( shell );
		return this;
	}
	
	function run() {
		return 'This command CFC has not implemented a run() method.';
	}
	
	// Called prior to each execution to reset any state stored in the CFC
	function reset() {
		print.clear();
	}
		
	// Get the result.  This will be called if the run() method doesn't return anything
	function getResult() {
		return print.getResult();
	}
			
	/**
	 * Ask the user a question and wait for response
	 * @message.hint message to prompt the user with
 	 **/
	function ask( required message ) {
		return shell.ask( message );
	}
		
	/**
	 * Wait until the user's next keystroke
	 * @message.hint An optional message to display to the user such as "Press any key to continue."
 	 **/
	function waitForKey( required message ) {
		return shell.waitForKey( message );
	}
		
	/**
	 * Run another command by name. 
	 * @command.hint The command to run. Pass the same string a user would type at the shell.
 	 **/
	function runCommand( required command ) {
		return shell.callCommand( command );
	}
	
	
}