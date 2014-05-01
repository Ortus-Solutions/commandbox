component extends="cli.BaseCommand" excludeFromHelp=true {
	
	function run()  {
		
		print.line();
		print.yellowLine( 'This is a special part of the CLI' );
		print.yellowLine( 'It is the part of the CLI that has my name on it.' );
		print.yellowLine( 'I am excited that we are calling this CommandBox since it' );
		print.yellowLine( 'it seems like we''re putting our code in a box and simply' );
		print.yellowLine( '"commanding" it around like an army general orders his subordinates.' );
		print.yellowLine( 'Hey you function, you get over here!  That''s right, look sharp now!' );
		print.line();
		print.yellowLine( 'That is all for now.  Thanks for reading this.' );
		print.line();
		
		shell.callCommand( "help brad" );

	}
}