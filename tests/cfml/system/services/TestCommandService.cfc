component extends="mxunit.framework.TestCase" {
//component extends="testbox.system.testing.TestBox" {

	public void function setUp()  {
		shell = application.wirebox.getInstance( 'Shell' );
		commandService = application.wirebox.getInstance( 'CommandService' );
	}

	public void function testInitCommands()  {
		var commands = commandService.getCommands();
		assertTrue(structKeyExists(commands,"quit"));
	}

	public void function testHelpCommands()  {
		commandChain = commandService.resolveCommand( "coldbox help" );
		assertTrue(commandChain[1].commandString == 'help');
	}
	
	public void function testResolveCommand()  {
		commandChain = commandService.resolveCommand( "help | more" );
		assertTrue(commandChain.len() == 2);
	}
		
	public void function testRunCommandLine()  {
		result = commandService.runCommandLine( "help" );
	}

	/*
	<cfsavecontent variable="command">
	brad test foobar 
	"goo" 
	'doo' 
	 "this is a test" 
	      test\"er 
	      12\=34
	</cfsavecontent>
		<!---
	<cfsavecontent variable="command">
	brad test 
	param=1 
	arg="no"
	 me='you' 
	  arg1="brad wood" 
	  arg2="Luis \"The Dev\" Majano" 
	  test  =  		 mine 	 
	   tester   	=  	 'YOU' 	
	     tester2   	=  	 "YOU2"
	</cfsavecontent>
		--->
		
		
	#command#<br><br><br>*/

}