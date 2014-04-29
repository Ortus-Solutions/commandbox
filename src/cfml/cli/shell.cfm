<cfsilent>
<cfset _shellprops = { version:'0.1' } >
<cfsetting requesttimeout="9999" />
<cfsavecontent variable="_shellprops.help">Welcome to CommandBox!
Type "help" for help, or "[command] help" to be more specific.
  ______      ____     __     __
 (_   _ \    / __ \   (_ \   / _)
   ) (_) )  / /  \ \    \ \_/ /
   \   _/  ( ()  () )    \   /
   /  _ \  ( ()  () )    / _ \
  _) (_) )  \ \__/ /   _/ / \ \_
 (______/    \____/   (__/   \__)
</cfsavecontent>
<cfscript>
	systemOutput(_shellprops.help);
	shell = new Shell();
	while (shell.run()) {
		systemOutput("Reloading shell.");
		SystemCacheClear("all");
		shell = javacast("null","");
		shell = new Shell();
	}
	system = createObject("java","java.lang.System");
        system.runFinalization();
        system.gc();
</cfscript>
</cfsilent>
