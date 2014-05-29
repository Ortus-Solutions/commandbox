/**
*********************************************************************************
* Copyright Since 2005 ColdBox Platform by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
* Main Application Bootstrap
*/
component{

	this.name = "CommandBox CLI";
	this.sessionmanagement = "false";

	// Load java libraries CommandBox leverages
	this.javaSettings = { loadPaths = [ "lib" ], reloadOnChange = false };

	// Move everything over to this mapping which is the "root" of our app
	commandBoxRoot = getDirectoryFromPath( getMetadata( this ).path );
	this.mappings[ '/commandbox' ] 	= commandBoxRoot;
	this.mappings[ '/wirebox' ] 	= commandBoxRoot & '/system/wirebox';
	
	function onApplicationStart(){
		new wirebox.system.ioc.Injector( 'commandbox.system.config.WireBox' );
		return true;
	}

	function onApplicationStop(){
		application.wirebox.shutdown();
	}
	
	function onError( any exception, string eventName ) {
		
		// Try to log this to LogBox
		try {
    		application.wireBox.getLogBox().getRootLogger().error( '#exception.message# #exception.detail ?: ''#', exception.stackTrace );
    	// If it fails no worries, LogBox just probably isn't loaded yet.
		} catch ( Any e ) {}
		
		// Give nicer message to user
		var err = arguments.exception;
    	var CR = chr( 13 );
    	systemOutput( 'BOOM GOES THE DYNAMITE!!', true );
    	systemOutput( 'We''re truly sorry, but something horrible has gone wrong when starting up CommandBox.', true );
    	systemOutput( 'Here''s what we know:.', true );
    	systemOutput( '', true );
    	systemOutput( '#err.message#', true );
    	systemOutput( '', true );
		if( structKeyExists( err, 'detail' ) ) {
    		systemOutput( '#err.detail#', true );
		}
    	systemOutput( '#err.stacktrace#', true );

    	//writeDump(var=arguments.exception, output="console"); 	
    	
		// Give them a chance to read it
		sleep( 30000 );
	}

}