<cfsilent>
<cfset _shellprops = { version:'0.1' } >
<cfsetting requesttimeout="9999" />
<cfsavecontent variable="_shellprops.help">Live evaluation (with GNU Readline-ish input control)
	Empty line displays and evaluates current buffer.  'version' lists version, 'clear' clears buffer, 'ls' and 'dir' list files, 'exit', 'quit', 'q' exits.  There is tab-completion, hit tab to see all.
	Examples:
		wee=3+4+5
		foo="bar"
		"re" & foo
		server.railo.version
		serialize(server.coldfusion)
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
</cfscript>
</cfsilent>