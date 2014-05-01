/**
 * Remove 1 or more packages from the cache
 **/
component persistent="false" extends="cli.BaseCommand" aliases="" excludeFromHelp=false {

	/**
	 * @packages.hint comma-delimited list of packages to remove
	 **/
	function run( required string packages ) {
		print.line( "remove #packages#" );
	}

}