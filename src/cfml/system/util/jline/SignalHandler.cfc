/**
*********************************************************************************
* Copyright Since 2005 ColdBox Platform by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano
* I am a JLine highighter class that handles terminal signals
*/
component {
	property name='shell' inject='shell';
	
	function handle( signal ) {
		if( signal.toString() == 'INT' ) {
			shell.getMainThread().interrupt();
		}
	}
	
}