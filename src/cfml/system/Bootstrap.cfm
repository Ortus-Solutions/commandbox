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
<cfsilent>
	<cfset variables.wireBox = application.wireBox>
	<cfsetting requesttimeout="999999" />
	
	<!---Display this banner to users--->
	<cfsavecontent variable="banner">Welcome to CommandBox!
	Type "help" for help, or "help [command]" to be more specific.
	  _____                                          _ ____
	 / ____|                                        | |  _ \
	| |     ___  _ __ ___  _ __ ___   __ _ _ __   __| | |_) | _____  __
	| |    / _ \| '_ ` _ \| '_ ` _ \ / _` | '_ \ / _` |  _ < / _ \ \/ /
	| |___| (_) | | | | | | | | | | | (_| | | | | (_| | |_) | (_) >  <
	 \_____\___/|_| |_| |_|_| |_| |_|\__,_|_| |_|\__,_|____/ \___/_/\_\ v@@version@@
	</cfsavecontent>
	
	<cfscript>
		system = createObject("java","java.lang.System");
		args = system.getProperty("cfml.cli.arguments");
	
		if(!isNull(args) && trim(args) != "") {
			 wireBox.getInstance( 'Shell' ).callCommand( args );
		} else {
			
			//systemOutput( 'Loading...', true );
			// Create the shell
			shell = wireBox.getInstance( 'Shell' );
			// Output the welcome banner
			systemOutput( replace( banner, '@@version@@', shell.getVersion() ) );
	
			// Running the "reload" command will enter this while loop once
			while( shell.run() ){
				SystemCacheClear( "all" );
				shell = javacast( "null", "" );
				wireBox.clearSingletons();
				shell = wireBox.getInstance( 'Shell' );
			}
		}
	
	    system.runFinalization();
	    system.gc();
	
	</cfscript>
</cfsilent>
