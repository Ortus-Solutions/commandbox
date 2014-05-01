<cfsilent>
<cfset _shellprops = { version:'0.1' } >
<cfsetting requesttimeout="9999" />
<cfsavecontent variable="_shellprops.help">Welcome to CommandBox!
Type "help" for help, or "[command] help" to be more specific.
   ____     ____       __    __       __    __       ____        __      _   ______     ______      ____     __     __  
  / ___)   / __ \      \ \  / /       \ \  / /      (    )      /  \    / ) (_  __ \   (_   _ \    / __ \   (_ \   / _) 
 / /      / /  \ \     () \/ ()       () \/ ()      / /\ \     / /\ \  / /    ) ) \ \    ) (_) )  / /  \ \    \ \_/ /   
( (      ( ()  () )    / _  _ \       / _  _ \     ( (__) )    ) ) ) ) ) )   ( (   ) )   \   _/  ( ()  () )    \   /    
( (      ( ()  () )   / / \/ \ \     / / \/ \ \     )    (    ( ( ( ( ( (     ) )  ) )   /  _ \  ( ()  () )    / _ \    
 \ \___   \ \__/ /   /_/      \_\   /_/      \_\   /  /\  \   / /  \ \/ /    / /__/ /   _) (_) )  \ \__/ /   _/ / \ \_  
  \____)   \____/   (/          \) (/          \) /__(  )__\ (_/    \__/    (______/   (______/    \____/   (__/   \__) 
</cfsavecontent>
<cfscript>
	systemOutput(_shellprops.help);
	shell = new Shell();
	while (shell.run()) {
		SystemCacheClear("all");
		shell = javacast("null","");
		shell = new Shell();
	}
	system = createObject("java","java.lang.System");
        system.runFinalization();
        system.gc();
</cfscript>
</cfsilent>
