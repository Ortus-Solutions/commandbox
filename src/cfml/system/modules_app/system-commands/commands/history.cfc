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
 * Use the "type" parameter to specify which history you want to view or clear.
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

	property name="commandHistoryFile"		inject="commandHistoryFile@constants";
	property name="REPLScriptHistoryFile"	inject="REPLScriptHistoryFile@constants";
	property name="REPLTagHistoryFile"	inject="REPLTagHistoryFile@constants";

	/**
	 * @clear.hint Erase your history.
	 * @type.hint The type of history to interact with. Values are "command", "scriptREPL", and "tagREPL"
	 * @type.options command,scriptREPL,tagREPL
	 **/
	function run( boolean clear=false, string type='command' ) {
		try {
			// Get the Java JLine.History object
			if( arguments.type == 'scriptREPL' ) {
				shell.setHistory( REPLScriptHistoryFile );
			} else if( arguments.type == 'tagREPL' ) {
				shell.setHistory( REPLTagHistoryFile );
			} else if( arguments.type == 'command' ) {
				shell.setHistory( commandHistoryFile );
			} else {
				error( 'History type [#arguments.type#] is invalid.  Valid types are "command", "scriptREPL", and "tagREPL".' );
			}

			// Clear the history?
			if( arguments.clear ) {
				shell.getReader().getHistory().purge();
				print.greenLine( 'History cleared.' );
				// Flush out anything in the buffer
				shell.getReader().getHistory().save();
			// Default behavior is just to display history
			} else {
				var historyIterator = shell.getReader().getHistory().iterator();
				while( historyIterator.hasNext() ) {
					print.line( listRest( historyIterator.next(), ':' ).trim() );
				}

			} // end clear?

		// Whatever happens in Vegas, stays in Vegas
		} finally {
			shell.setHistory( commandHistoryFile );
		}

	}


}
