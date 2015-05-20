/**
*********************************************************************************
* Copyright Since 2005 ColdBox Platform by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Grant Copley
*
* I contain helpful methods for REPL parsing.
*
*/
component accessors="true" singleton {

	instance = {};

	/**
	 * Constructor
 	**/
	function init() {
		return this;
	}

	/**
	* Clears existing command lines and signal we are starting a new command.
	**/
	function startCommand() {
		instance.CFMLCommandLines = [];
	}

	/**
	* Returns an array with each line of the command seperated
	**/
	function getCommandLines() {
		return instance.CFMLCommandLines;
	}

	/**
	* Returns all commands lines as a single string.
	**/
	function getCommandAsString() {
		var command = arrayToList( getCommandLines(), chr(10) );
		command = stripComments( command );
		return command;
	}

	/**
	* Adds an additional line for the command we are parsing.
	**/
	function addCommandLine( string command ) {
		instance.CFMLCommandLines.append( arguments.command );
	}

	/**
	* Returns true if the command is complete and is ready to be executed.
	**/
	function isCommandComplete() {
		var cfml = getCommandAsString();
		cfml = reReplaceNoCase( cfml, "[""'].*[""']", """""", "all" );

		var numberOfCurlyBrackets = reMatchNoCase( "[{}]", cfml ).len();
		var numberOfParenthesis = reMatchNoCase( "[\(\)]", cfml ).len();
		//var numberOfDoubleQuotations = reMatchNoCase( """", cfml ).len();
		//var numberOfSingleQuotations = reMatchNoCase( "'", cfml ).len();
		var numberOfNonTerminatingEqualSigns = reMatchNoCase( "=\s*$", cfml ).len();
		var numberOfMultilineCommentBlocks = reMatchNoCase( "^\s*/\*|\*/", cfml ).len();
		var numberOfHashSigns = reMatchNoCase( "##", cfml ).len();
		if ( numberOfCurlyBrackets % 2 == 0 && numberOfParenthesis % 2 == 0 && numberOfNonTerminatingEqualSigns == 0 && numberOfHashSigns % 2 == 0 && numberOfMultilineCommentBlocks % 2 == 0 ) {
			return true;
		}
		return false;
	}

	/**
	* Returns command as string with certain charaters removed that prevent evaluation.
	**/
	function getCommandPreparedForEvaluation() {
		var cfml = getCommandAsString();
		cfml = reReplaceNoCase( cfml, ";", "", "all" );
		return cfml;
	}

	/**
	* Returns serialized evaluation of command if possible.
	**/
	function evaluateCommand() {
		if ( !isCommandComplete() ) {
			throw ( type="CommandNotComplete", message = "The command is not complete." );
		}
		try {
			var cfml = getCommandPreparedForEvaluation();
			var evaluated = evaluate( cfml );
			return serializeJson( evaluated );
		} catch (any var e) {
			return "";
		}
	}

	/**
	* Removes comments from command
	**/
	function stripComments( string command ) {
		return reReplaceNoCase( arguments.command, "//[^""']*$|/\*.*\*/", "", "all" );
	}

}
