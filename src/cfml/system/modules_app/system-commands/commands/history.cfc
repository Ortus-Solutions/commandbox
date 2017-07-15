/**
 * Display the history of all the commands that have been typed into the shell.
 * .
 * {code:bash}
 * history
 * {code}
 * .
 * Use the clear flag to clear the history.
 * .
 * {code:bash}
 * history --clear
 * {code}
 * .
 * There are separate histories for commands, script REPL and tag REPL.
 * Use the "type" paramater to specifiy which history you want to view or clear.
 * .
 * {code:bash}
 * history type=command
 * history type=scriptREPL
 * history type=tagREPL
 * {code}
 * .
 * Clear just the script REPL history
 * .
 * {code:bash}
 * history type=scriptREPL --clear
 * {code}
 *
 **/
component {

	property name="commandHistoryFile"		inject="commandHistoryFile@java";
	property name="REPLScriptHistoryFile"	inject="REPLScriptHistoryFile@java";
	property name="REPLTagHistoryFile"	inject="REPLTagHistoryFile@java";

	/**
	 * @clear.hint Erase your history.
	 * @type.hint The type of history to interact with. Values are "command", "scriptREPL", and "tagREPL"
	 * @type.options command,scriptREPL,tagREPL
	 **/
	function run( boolean clear=false, string type='command' ) {
		// Get the Java JLine.History object
		if( arguments.type == 'scriptREPL' ) {
			var history = variables.REPLScriptHistoryFile;
		} else if( arguments.type == 'tagREPL' ) {
			var history = variables.REPLTagHistoryFile;
		} else {
			var history = variables.commandHistoryFile;
		}

		// Clear the history?
		if( arguments.clear ) {
			history.clear();
			print.greenLine( 'History cleared.' );
			// Flush out anything in the buffer
			history.flush();
		// Default behavior is just to display history
		} else {
			var historyIterator = history.iterator();
			while( historyIterator.hasNext() ) {
				print.line( listRest( historyIterator.next(), ':' ) );
			}

		} // end clear?

	}


}
