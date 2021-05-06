/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I am a helper object that wraps the print helper.  Instead of returning
* text, I accumulate it in a variable that can be retrieved at the end.
*
*/
component accessors="true" extends="Print"{

	// DI
	property name="shell" inject="shell";

	property name="objectID";

	/**
	* Result buffer
	*/
	property name="result";

	function init(){
		variables.result = createObject( 'java', 'java.lang.StringBuilder' ).init( '' );
		setObjectID( createUUID() );
		return this;
	}

	// Force a flush
	function toConsole(){
		// A single instance of print buffer can only dump to the console once at a time, otherwise
		// the shared state in "result" will get output more than once.
		lock name='printBuffer-#getObjectID()#' type="exclusive" timeout="20" {
			var thingToPrint = getResult();
			clear();
		}

		// Once we get the text to print above, we can release the lock while we actually print it.
		variables.shell.printString( thingToPrint );
	}

	// Reset the result
	function clear(){
		variables.result.setLength(0);
	}

	function getResult() {
		return variables.result.toString();
	}

	// Proxy through any methods to the actual print helper
	function onMissingMethod( missingMethodName, missingMethodArguments ){
		// Don't modify the buffer if it's being printed
		lock name='printBuffer-#getObjectID()#' type="readonly" timeout="20" {
			variables.result.append( super.onMissingMethod( arguments.missingMethodName, arguments.missingMethodArguments ) );
			return this;
		}
	}

    /**
     * Outputs a table to the screen
     * @headers An array of column headers, or a query.  When passing a query, the "data" argument is not used.
     * @data An array of data for the table.  Each item in the array may either be
     *            an array in the correct order matching the number of headers or a struct
     *            with keys matching the headers.
     * @includeHeaders A list of headers to include.  Used for query inputs
     */
	function table(
        required any headers,
        any data=[],
        string includeHeaders
    ){
		// Don't modify the buffer if it's being printed
		lock name='printBuffer-#getObjectID()#' type="readonly" timeout="20" {
			variables.result.append( super.table( argumentCollection=arguments ) );
			return this;
		}
	}

}
