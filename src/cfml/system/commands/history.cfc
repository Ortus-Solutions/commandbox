/**
 * Displays command history for the user.  Use the clear flag to clear the history.
 *
 * history
 * 
 **/
component extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {
	
	/**
	 * @clear.hint Erase your history.  
	 **/
	function run( Boolean clear=false ) {
		// Get the Java JLine.History object
		history = shell.getReader().getHistory();
		// Flush out anything in the buffer
		history.flush();

		// Clear the history?		
		if( arguments.clear ) {
		
			history.clear();
			print.greenLine( 'History cleared.' );
			
		// Default behavior is just to display history
		} else {
			
			var historyIterator = history.iterator();
			while( historyIterator.hasNext() ) {
				print.line( listLast( historyIterator.next(), ':' ) );
			}
			
		} // end clear?
		
	}


}