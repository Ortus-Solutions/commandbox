<cfparam name="url.version" default="1.0">
<cfparam name="url.path" 	default="#expandPath( "./CommandBox-CommandDocs" )#">
<cfscript>
	docName = "CommandBox-CommandDocs";

	colddoc 	= new ColdDoc();
	strategy 	= new colddoc.strategy.commandbox.HTMLCommandStrategy( url.path, "CommandBox #url.version#" );
	colddoc.setStrategy( strategy );
	source = [
		{ inputDir=expandPath( "/commandbox/commands" ), inputMapping="commandbox.commands" },
		{ inputDir=expandPath( "/commandbox/system/commands" ), inputMapping="commandbox.system.commands" }
	];

	colddoc.generate( source );
</cfscript>

<cfoutput>
<h1>Command Help Done!</h1>
<a href="#docName#/index.html">Go to Docs!</a>
</cfoutput>

