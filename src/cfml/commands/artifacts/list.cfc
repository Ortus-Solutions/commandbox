/**
 * Lists all packages in the cache
 **/
component persistent="false" extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {

	function run(  ) {
		print.line( "List packages!" );
	}

}