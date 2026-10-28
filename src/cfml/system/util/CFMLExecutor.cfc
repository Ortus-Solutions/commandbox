/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I execute cfm templates in isolation
* Do not make this a singleton or cache it unless you
* want to persist its state between executions.  That is because
* the "variables" scope is retained between calls to the "run()" method.
*/
component {

	property name="$fileSystemUtil"	inject="FileSystem";
	property name="$shell"			inject="shell";
	property name="$wirebox"		inject="wirebox";

	/**
	* Execute an existing file
	* @template.hint Absolute path to a .cfm to execute
	* @vars.hint Struct of vars to set so the template can access them
	*/
	function runFile( required template, struct vars = {} ){
		arguments.template = $fileSystemUtil.makePathRelative( template );

		// Mix the incoming vars into the "variables" scope.
		structAppend( variables, vars );

		savecontent variable="local.out"{
			include "#arguments.template#";
		}
		if( len( local.out ) ) {
			return local.out;
		}
		if( !isNull( variables.__result2 ) ) {
			return variables.__result2;
		}
		return;
	}

	/**
	* Execute a snippet of code in the context of a directory
	* @code.hint CFML code to run
	* @script.hint is the CFML code script or tags
	* @directory.hint Absolute path to a directory context to run in
	* @vars.hint Struct of vars to set so the code can access them
	*/
	function runCode( required string code, boolean script=true, required string directory,  struct vars = {} ){

		// Temp file to evaluate
		var tmpFile = createUUID() & ".cfm";
		var tmpFileAbsolute = arguments.directory & "/" & tmpFile;

		// generate cfml command to write to file
		var CFMLFileContents = ( arguments.script ? "<cfscript>variables.__result2 = " & arguments.code & "</cfscript>" : arguments.code );

		// write out our cfml command
		fileWrite( tmpFileAbsolute, CFMLFileContents );

		try {
			return runFile( tmpFileAbsolute, arguments.vars );
		} catch( any e ){

			// generate cfml command to write to file
			local.CFMLFileContents = ( arguments.script ? "<cfscript>" & arguments.code & "</cfscript>" : arguments.code );

			// write out our cfml command
			fileWrite( tmpFileAbsolute, CFMLFileContents );

			return runFile( tmpFileAbsolute, arguments.vars );
		} finally {
			// cleanup
			if( fileExists( tmpFileAbsolute ) ){
				fileDelete( tmpFileAbsolute );
			}
		}
	}

	/**
	* eval
	* @statement.hint A CFML statement to evaluate
	*/
	function eval( required string statement, required string directory ){
		variables.__statement = arguments.statement;
		var cfml = 'savecontent variable="variables.__out" { variables.__result = evaluate( variables.__statement ); }';

		runCode( cfml, true, arguments.directory );

		if( len( variables.__out ) ) {
			return variables.__out;
		} else if ( !isNull( variables.__result ) ){
			return variables.__result;
		} else {
			return;
		}
	}

	function getInstance(){
		return $wirebox.getInstance( argumentCollection = arguments );
	}

	function getCurrentVariables(){
		return variables
			.keyArray()
			.filter( function( i ) {
				return ( !'RUNFILE,EVAL,RUNCODE,$shell,GETINSTANCE,$wirebox,$fileSystemUtil,GETCURRENTVARIABLES,THIS,__RESULT,__STATEMENT,__out'.listFindNoCase( i ) );
			} )
			.map( function( i ) {
				return i.lcase();
			} );
	}

	/**
	 * This method mimics a Java/Groovy assert() function, where it evaluates the target to a boolean value or an executable closure and it must be true
	 * to pass and return a true to you, or throw an `AssertException`
	 *
	 * @target The tareget to evaluate for being true, it can also be a closure that will be evaluated at runtime
	 * @message The message to send in the exception
	 *
	 * @throws AssertException if the target is a false or null value
	 * @return True, if the target is a non-null value. If false, then it will throw the `AssertError` exception
	 */
	boolean function assert( target, message="" ){
		// param against nulls
		arguments.target = arguments.target ?: false;
		// evaluate it
		var results = isClosure( arguments.target ) || isCustomFunction( arguments.target ) ? arguments.target( variables ) : arguments.target;
		// deal it : callstack two is from where the `assert` was called.


		return results ? true : throw( message="Assertion failed", detail=arguments.message, type="commandException" );
	}

}
