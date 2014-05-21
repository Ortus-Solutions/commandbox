/**
 * Remove 1 or more packages from the cache
 **/
component extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {

	/**
	 * @packages.hint comma-delimited list of packages to remove
	 **/
	function run( required string packages ) {
		print.line( "remove #packages#" );
	}

}