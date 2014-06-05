component extends="commandbox.system.BaseCommand" excludeFromHelp=true {
	
	function run()  {
		
		print.line()
			.yellowLine( 'The artifacts command will allow you to control your artifacts cache.' )
			.yellowLine( 'From Listing its content to removing and purging.' )
			.line().line();

	}
}