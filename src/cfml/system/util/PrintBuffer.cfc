/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I am a helper object that wraps the print helper.  Instead of returning
* text, I accumulate it in a variable that can be retreived at the end.
*
*/
component accessors="true" extends="Print"{

	// DI
	property name="shell" inject="shell";
	
	property name="objectID";

	/**
	* Result buffer
	*/
	property name="result" default="";

	function init(){
		setObjectID( createUUID() );
		return this;
	}

	// Force a flush
	function toConsole(){
		// A single instance of print buffer can only dump to the console once at a time, otherwise
		// the shared satate in "result" will get output more than once.
		lock name='printBuffer-#getObjectID()#' type="exclusive" timeout="20" {
			var thingToPrint = getResult();
			clear();
		}
		  	
		// Once we get the text to print above, we can release the lock while we actually print it.
		variables.shell.printString( thingToPrint );
	}

	// Reset the result
	function clear(){
		variables.result = '';
	}

	// Proxy through any methods to the actual print helper
	function onMissingMethod( missingMethodName, missingMethodArguments ){
		// Don't modify the buffer if it's being printed
		lock name='printBuffer-#getObjectID()#' type="readonly" timeout="20" {
			variables.result &= super.onMissingMethod( arguments.missingMethodName, arguments.missingMethodArguments );
			return this;
		}
	}

}
