/**
 * Kills all running tasks
 **/
component extends="commandbox.system.BaseCommand" aliases="kill" {

	function run(  ) {
		print.line( "faux-kill!" );
	}

}