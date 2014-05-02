<cfsilent>
<cfset _shellprops = { version:'0.1' } >
<cfsetting requesttimeout="9999" />
<cfsavecontent variable="_shellprops.help">Welcome to CommandBox!
Type "help" for help, or "help [command]" to be more specific.
  _____                                          _ ____            
 / ____|                                        | |  _ \           
| |     ___  _ __ ___  _ __ ___   __ _ _ __   __| | |_) | _____  __
| |    / _ \| '_ ` _ \| '_ ` _ \ / _` | '_ \ / _` |  _ < / _ \ \/ /
| |___| (_) | | | | | | | | | | | (_| | | | | (_| | |_) | (_) >  < 
 \_____\___/|_| |_| |_|_| |_| |_|\__,_|_| |_|\__,_|____/ \___/_/\_\ v1.0.0.@build.number@
</cfsavecontent>
<cfscript>
	systemOutput( _shellprops.help );
	shell = new Shell();
	while( shell.run() ){
		SystemCacheClear( "all" );
		shell = javacast( "null", "" );
		shell = new Shell();
	}
	system = createObject( "java", "java.lang.System" );
    system.runFinalization();
    system.gc();
</cfscript>
</cfsilent>
