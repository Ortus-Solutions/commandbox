/**
 * Outputs CommandBox version currently installed
 * .
 * {code}
 * version
 * {code}
 **/
component extends="commandbox.system.BaseCommand" aliases="ver" excludeFromHelp=false {

	function run()  {
		print.line( 'CommandBox #shell.getVersion()#' );
	}

}