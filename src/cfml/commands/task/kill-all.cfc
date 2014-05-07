/**
 * Kills all running tasks
 **/
component persistent="false" extends="commandbox.system.BaseCommand" aliases="kill" excludeFromHelp=false {

	function run(  ) {
		print.line( "faux-kill!" );
	}

}