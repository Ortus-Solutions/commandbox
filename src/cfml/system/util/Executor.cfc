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

	property name="fileSystemUtil" 	inject="FileSystem";

	/**
	* Execute an existing file
	* @template.hint Absolute path to a .cfm to execute
	* @vars.hint Struct of vars to set so the template can access them
	*/
	function runFile( required template, struct vars = {} ){
		arguments.template = fileSystemUtil.makePathRelative( template );

		// Mix the incoming vars into the "variables" scope.
		structAppend( variables, vars );

		savecontent variable="local.out"{
			include "#arguments.template#";
		}
		return local.out;
	}

	/**
	* Execute a snipped of code in the context of a directory
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
		var CFMLFileContents = ( arguments.script ? "<cfscript>" & arguments.code & "</cfscript>" : arguments.codearguments.directory );

		// write out our cfml command
		fileWrite( tmpFileAbsolute, CFMLFileContents );

		try {
			return runFile( tmpFileAbsolute, arguments.vars );
		} catch( any e ){
			rethrow;
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
		} else {
			return variables.__result ?: '';
		}
	}

}