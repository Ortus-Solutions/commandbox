<cfsilent>
<!---
*********************************************************************************
 Copyright Since 2014 CommandBox by Ortus Solutions, Corp
 www.coldbox.org | www.ortussolutions.com
********************************************************************************
@author Brad Wood, Luis Majano, Denny Valliant

I bootstrap CommandBox up, create the shell and get it running.
I am a CFM because the CLI seems to need a .cfm file to call
This file will stay running the entire time the shell is open
--->
<cfset variables.wireBox = application.wireBox>
<cfsetting requesttimeout="999999" />
<!---Display this banner to users--->
<cfsavecontent variable="banner">
  _____                                          _ ____
 / ____|                                        | |  _ \
| |     ___  _ __ ___  _ __ ___   __ _ _ __   __| | |_) | _____  __
| |    / _ \| '_ ` _ \| '_ ` _ \ / _` | '_ \ / _` |  _ < / _ \ \/ /
| |___| (_) | | | | | | | | | | | (_| | | | | (_| | |_) | (_) >  <
 \_____\___/|_| |_| |_|_| |_| |_|\__,_|_| |_|\__,_|____/ \___/_/\_\ v@@version@@

Welcome to CommandBox!
Type "help" for help, or "help [command]" to be more specific.
</cfsavecontent>
<cfscript>
	system 	= createObject( "java", "java.lang.System" );
	args 	= system.getProperty( "cfml.cli.arguments" );

	// Verify if we can run CommandBox Java v. 1.7+
	if( findNoCase( "1.6", server.java.version ) ){
		systemOutput( "The Java Version you have (#server.java.version#) is not supported by CommandBox. Please install a Java JRE/JDK 1.7+" );
		sleep( 5000 );
		abort;
	}

	// Check if we are called with an inline command
	if( !isNull( args ) && trim( args ) != "" ){
		// Create the shell
		shell = wireBox.getInstance( name='Shell', initArguments={ asyncLoad=false } );
		// Call passed command
		shell.callCommand( args );
		// flush console
		shell.getReader().flush();
	} else {
		// Create the shell
		shell = wireBox.getInstance( 'Shell' );
		// Output the welcome banner
		systemOutput( replace( banner, '@@version@@', shell.getVersion() ) );
		// Running the "reload" command will enter this while loop once
		while( shell.run() ){
			// Clear all caches: template, ...
			SystemCacheClear( "all" );
			shell = javacast( "null", "" );
			
			// reload wirebox
			wireBox.shutdown();
			new wirebox.system.ioc.Injector( 'commandbox.system.config.WireBox' );
			variables.wireBox = application.wireBox;
			
			// startup a new shell
			shell = wireBox.getInstance( 'Shell' );
		}
	}

    system.runFinalization();
    system.gc();
</cfscript>
</cfsilent>