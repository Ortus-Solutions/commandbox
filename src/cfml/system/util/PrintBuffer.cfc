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
	property name="job" inject="interactiveJob";

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
		// If there is an active job, print our output through it
		if( job.getActive() ) {
			job.addLog( thingToPrint );
		} else {
			variables.shell.printString( thingToPrint );
		}
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
		var result = super.onMissingMethod( arguments.missingMethodName, arguments.missingMethodArguments );

		// Don't modify the buffer if it's being printed, exclusive because StringBuilder is not thread-safe
		lock name='printBuffer-#getObjectID()#' type="exclusive" timeout="20" {
			variables.result.append( result );
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
		required any data=[],
        any includedHeaders="",
        any headerNames="",
		boolean debug=false
    ){
		// Don't modify the buffer if it's being printed
		lock name='printBuffer-#getObjectID()#' type="exclusive" timeout="20" {
			variables.result.append( super.table( argumentCollection=arguments ) );
			return this;
		}
	}

	function columns( required array items, formatUDF=(s)=>'' ) {
		// Don't modify the buffer if it's being printed
		lock name='printBuffer-#getObjectID()#' type="exclusive" timeout="20" {
			variables.result.append( super.columns( argumentCollection=arguments ) );
			return this;
		}
	}

	/**
	* Print a struct of structs as a tree
	*
	* @data top level struct
	* @formatUDF A UDF receiving both a string-concatenated prefix of keys, and an array of the same data.  Returns string of special formating for that node of the tree
	*/
	function tree( required struct data, formatUDF=()=>'' ) {
		// Don't modify the buffer if it's being printed
		lock name='printBuffer-#getObjectID()#' type="exclusive" timeout="20" {
			variables.result.append( super.tree( argumentCollection=arguments ) );
			return this;
		}
	}

}
