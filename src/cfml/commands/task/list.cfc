/**
 * List all tasks
 **/
component persistent="false" extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {

	function run(  ) {
		print.line( "faux-list!" );
	}

}