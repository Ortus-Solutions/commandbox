/**
 * Displays command history for the user.  Use the clear flag to clear the history.
 *
 * history
 * 
 **/
component extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {
	
	/**
	 * @clear.hint Erase your history.  
	 * @repl.hint See the repl history or the command history
	 * @tag.hint See the repl tag history or script history
	 **/
	function run( boolean clear=false, boolean repl=false, boolean tag=false ) {
		// Get the Java JLine.History object
		var history = shell.getReader().getHistory();
		// repl History?
		if( arguments.repl ){
			history = arguments.tag ? wirebox.getInstance( "REPLTagHistoryFile@java" ) : wirebox.getInstance( "REPLHistoryFile@java" );
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
				print.line( listLast( historyIterator.next(), ':' ) );
			}
		} // end clear?
		
	}

}