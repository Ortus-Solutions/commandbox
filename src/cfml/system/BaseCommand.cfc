/**
*********************************************************************************
* Copyright Since 2005 ColdBox Platform by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I am the base command implementation.  An abstract class if you will.
*
*/
component accessors="true" singleton{
	
	// DI
	property name="CR" 				inject="CR@constants";
	property name="formatterUtil" 	inject="Formatter";
	property name="fileSystemUtil" 	inject="FileSystem";
	property name="shell" 			inject="shell";
	property name="print" 			inject="PrintBuffer";
	property name="wirebox" 		inject="wirebox";
	property name="logger" 			inject="logbox:logger:{this}";

	/**
	* Constructor
	*/
	function init() {
		hasErrored = false;
		return this;
	}
	
	// This method needs to be overridden by the concrete class.
	function run() {
		return 'This command CFC has not implemented a run() method.';
	}	
	
	// Convenience method for getting stuff from WireBox
	function getInstance( name, dsl, initArguments={}, targetObject='' ) {
		return wirebox.getInstance( argumentCollection = arguments );
	}
	
	// Called prior to each execution to reset any state stored in the CFC
	function reset() {
		print.clear();
		hasErrored = false;
	}
		
	// Get the result.  This will be called if the run() method doesn't return anything
	function getResult() {
		return print.getResult();
	}
		
	// Returns the current working directory of the shell
	function getCWD() {
		return shell.pwd();
	}
			
	/**
	 * Ask the user a question and wait for response
	 * @message.hint message to prompt the user with
 	 **/
	function ask( required message ) {
		return shell.ask( arguments.message );
	}
		
	/**
	 * Wait until the user's next keystroke
	 * @message.hint An optional message to display to the user such as "Press any key to continue."
 	 **/
	function waitForKey( required message ) {
		return shell.waitForKey( arguments.message );
	}
		
	/**
	 * Ask the user a question looking for a yes/no response
	 * Accepts any boolean value, or "y".
	 * @message.hint The message to display to the user such as "Press any key to continue."
 	 **/
	function confirm( required message ) {
		var answer = ask( "#message# : " );
		if( trim( answer ) == "y" || ( isBoolean( answer ) && answer ) ) {
			return true;
		}
		return false;
		
	}
		
	/**
	 * Run another command by name. 
	 * @command.hint The command to run. Pass the same string a user would type at the shell.
 	 **/
	function runCommand( required command ) {
		return shell.callCommand( arguments.command );
	}

	/**
	 * Use if if your command wants to give contorlled feedback to the user without raising
	 * an actual exception which comes with a messy stack trace.  "return" this command to stop execution of your command
	 * Alternativley, multuple errors can be printed by calling this method more than once prior to returning.
	 * Use clearPrintBuffer to wipe out any output accrued in the print buffer. 
	 * 
	 * return error( "We're sorry, but happy hour ended 20 minutes ago." );
	 *	 
	 * @message.hint The error message to display
	 * @clearPrintBuffer.hint Wipe out the print buffer or not, it does not by default
 	 **/
	function error( required message, clearPrintBuffer=false ) {
		hasErrored = true;
		if( arguments.clearPrintBuffer ) {
			// Wipe 
			print.clear();
		} else {
			// Distance ourselves from whatever other output the command may have given so far.
			print.line().line();
		}
		print.whiteOnRedLine( 'ERROR' )
			.line()
			.redLine( arguments.message )
			.line();
		
	}
	
	/**
	 * Tells you if the error() method has been called on this command.  Useful if you have several validation checks, and then want
	 * to return at the end if one of them failed.
 	 **/
	function hasError() {
		return hasErrored;
	}
				
}