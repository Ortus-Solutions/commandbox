/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Grant Copley
*
* I contain helpful methods for REPL parsing.
*
*/
component accessors="true" singleton {

	property name="formatterUtil" inject="Formatter";
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
	* Adds one or more lines at once
	**/
	function addCommandLines( string command ) {
		for( var line in listToArray( command, chr(10)&chr(13) ) ) {
			addCommandLine( line );
		}
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
	* @executor.hint the executor context to attempt evaluation
	**/
	function evaluateCommand( required executor, required directory ) {
			var cfml = getCommandPreparedForEvaluation();
			return executor.eval( cfml, arguments.directory );
	}

	/**
	* Serializes output
	**/
	function serializeOutput( result ) {
		// null
		if( isNull( result ) ){
			return;
		// string
		} else if( isSimpleValue( result ) ) {
			return result;
		// CFC, possibly Java object too (though I think that's a bug)
		} else if( isObject( result ) ) {
			return '[Object #getMetaData( result ).name#]';
		// Serializable types
		} else if( isArray( result ) || isStruct( result ) || isQuery( result ) ) {
			return formatterUtil.formatJson( serializeJson( result ) );
		// Yeah, I give up
		} else {
			return '[#result.getClass().getName()#]';
		}
	}


	/**
	* Removes comments from command
	**/
	function stripComments( string command ) {
		return reReplaceNoCase( arguments.command, "//[^""']*$|/\*.*\*/", "", "all" );
	}

}
