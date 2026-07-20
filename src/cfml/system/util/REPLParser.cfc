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
	property name="JSONService" inject="JSONService";
	instance = {};

	/**
	 * Constructor
 	**/
	function init() {
		return this;
	}

	private boolean function hasOpenQuotes( required string command ) {
        var charArray = arguments.command.toCharArray();
        var isQuoteOpen = false;
        var quoteType = "";
        for ( var char in charArray ) {
            if (!isQuoteOpen && ( char == "'" || char == '"' ) ) {
                isQuoteOpen = true;
                quoteType = char;
            }
            else if ( isQuoteOpen && char == quoteType ) {
                isQuoteOpen = false;
            }
        }
        return isQuoteOpen;
    }

	/**
	* Clears existing command lines and signal we are starting a new command.
	**/
	function startCommand() {
		instance.CFMLCommandLines = [];
	}

	/**
	* Returns an array with each line of the command separated
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
		var commandString = getCommandAsString();
		var cfml = reReplaceNoCase( commandString, "[""'].*[""']", """""", "all" );

		var numberOfCurlyBrackets = reMatchNoCase( "[{}]", cfml ).len();
		var numberOfParenthesis = reMatchNoCase( "[\(\)]", cfml ).len();
		var numberOfQuotes = reMatchNoCase( "[""']", commandString ).len();
		var numberOfBrackets = reMatchNoCase( "[\[\]]", cfml ).len();
		var numberOfNonTerminatingEqualSigns = reMatchNoCase( "=\s*$", cfml ).len();
		var numberOfMultilineCommentBlocks = reMatchNoCase( "^\s*/\*|\*/", cfml ).len();
		var numberOfHashSigns = reMatchNoCase( "##", cfml ).len();
		
		if (
			numberOfBrackets % 2 == 0
			&& numberOfCurlyBrackets % 2 == 0
			&& numberOfParenthesis % 2 == 0
			&& numberOfNonTerminatingEqualSigns == 0
			&& numberOfHashSigns % 2 == 0
			&& numberOfMultilineCommentBlocks % 2 == 0
			&& ( numberOfQuotes == 0 || !hasOpenQuotes( commandString ) )
		) {
			return true;
		}
		return false;
	}

	/**
	* Returns command as string with certain characters removed that prevent evaluation.
	**/
	function getCommandPreparedForEvaluation() {
		var cfml = getCommandAsString();
		// Trailing semicolons cause syntax error with evaluate() BIF so remove them and the following still work as expected (returning the value)
		// REPL> foo = 'bar';
		cfml = reReplaceNoCase( cfml, ";$", "" );
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
			return '[NULL]';
		// binary
		} else if( isBinary( result ) ) {
			return result;
		// empty string
		} else if( isSimpleValue( result ) && !len( result ) ) {
			return '[EMPTY STRING]';
		// XML doc OR XML String
		} else if( isXML( result ) ) {
			return formatterUtil.formatXML( result );
		// string
		} else if( isSimpleValue( result ) ) {

			if( isJSON( result ) ) {
				var parsed = deserializeJSON( result );
				if( isStruct( parsed ) || isArray( parsed ) ) {
					return formatterUtil.formatJson( json=result, ANSIColors=JSONService.getANSIColors() );
				}
			}

			return result;

		// CFC, possibly Java object too (though I think that's a bug)
		} else if( isObject( result ) ) {
			var md = getMetaData( result )
			// Check for class is if the object is a static refence to a class and not an instance
			// structKeyExists() is a workaround for this: https://luceeserver.atlassian.net/browse/LDEV-4259
			if( md.getClass().getName() == 'java.lang.Class' || !structKeyExists( md, 'name' ) ) {
				return '[Class #result.getClass().getName()#]';
			} else {
				return '[Object #md.name#]';
			}
		// Serializable types
		} else if( isArray( result ) || isStruct( result ) || isQuery( result ) ) {
			result = serializeJSON( result, 'struct' );
			return formatterUtil.formatJson( json=result, ANSIColors=JSONService.getANSIColors() );
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
