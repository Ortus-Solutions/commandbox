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

	/**
	* Result buffer
	*/
	property name="result" default="";

	function init(){
		return this;
	}

	// Force a flush
	function toConsole(){
		variables.shell.printString( getResult() );
		clear();
	}

	// Reset the result
	function clear(){
		variables.result = '';
	}

	// Proxy through any methods to the actual print helper
	function onMissingMethod( missingMethodName, missingMethodArguments ){
		variables.result &= super.onMissingMethod( arguments.missingMethodName, arguments.missingMethodArguments );
		return this;
	}

}