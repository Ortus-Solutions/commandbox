<!---
*********************************************************************************
 Copyright Since 2005 ColdBox Platform by Ortus Solutions, Corp
 www.coldbox.org | www.ortussolutions.com
********************************************************************************
@author Brad Wood, Luis Majano, Denny Valliant

I bootstrap CommandBox up, create the shell and get it running.
I am a CFC because the Railo CLI seems to need a .cfm file to call
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
			// Clear all railo caches: template, ...
			SystemCacheClear( "all" );
			shell = javacast( "null", "" );
			// reload wirebox
			new wirebox.system.ioc.Injector( 'commandbox.system.config.WireBox' );
			// startup a new shell
			shell = wireBox.getInstance( 'Shell' );
		}
	}

    system.runFinalization();
    system.gc();
</cfscript>