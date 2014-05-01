/**
 * Kills all running tasks
 **/
component persistent="false" extends="cli.BaseCommand" aliases="kill" excludeFromHelp=false {

	function run(  ) {
		print.line( "faux-kill!" );
	}

}