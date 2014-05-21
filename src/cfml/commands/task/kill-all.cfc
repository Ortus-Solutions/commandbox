/**
 * Kills all running tasks
 **/
component extends="commandbox.system.BaseCommand" aliases="kill" excludeFromHelp=false {

	function run(  ) {
		print.line( "faux-kill!" );
	}

}