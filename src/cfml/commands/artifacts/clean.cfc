/**
 * Clean out the artifacts cache
 **/
component persistent="false" extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {

	function run(  ) {
		print.line( "clean packages!" );
	}

}