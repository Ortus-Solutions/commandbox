<cfsilent>
<!--- I bootstrap CommandBox up, create the shell and get it running.  
I am a CFC because the Railo CLI seems to need a .cfm file to call --->
<!---This file will stay running the entire time the shell is open --->
<cfsetting requesttimeout="999999" />
<!--- Create the shell --->
<cfset shell = new commandbox.system.Shell()>
<!---Display this banner to users--->
<cfsavecontent variable="banner">Welcome to CommandBox!
Type "help" for help, or "help [command]" to be more specific.
  _____                                          _ ____            
 / ____|                                        | |  _ \           
| |     ___  _ __ ___  _ __ ___   __ _ _ __   __| | |_) | _____  __
| |    / _ \| '_ ` _ \| '_ ` _ \ / _` | '_ \ / _` |  _ < / _ \ \/ /
| |___| (_) | | | | | | | | | | | (_| | | | | (_| | |_) | (_) >  < 
 \_____\___/|_| |_| |_|_| |_| |_|\__,_|_| |_|\__,_|____/ \___/_/\_\ v<cfoutput>#shell.getVersion()#</cfoutput>
</cfsavecontent>
<cfscript>
	// Output the welcome banner
	systemOutput( banner );
	// Running the "reload" command will enter this while loop once
	while( shell.run() ){
		SystemCacheClear( "all" );
		shell = javacast( "null", "" );
		shell = new commandbox.system.Shell();
	}
	system = createObject( "java", "java.lang.System" );
    system.runFinalization();
    system.gc();
</cfscript>
</cfsilent>
