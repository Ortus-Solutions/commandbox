/**
 * Opens a package's homepage URL if found
 * .
 * {code:bash}
 * package homepage
 * {code}
 * .
 * Via alias
 * {code:bash}
 * homepage
 * {code}
 **/
component extends="commandbox.system.BaseCommand" aliases="homepage" excludeFromHelp=false {
	
	property name="packageService" inject="PackageService";
	
	/**
	 * run
	 **/
	function run(){
		
		// package check
		if( !packageService.isPackage( getCWD() ) ) {
			return error( '#getCWD()# is not a package!' );
		}
		
		var boxJSON = packageService.readPackageDescriptor( getCWD() );
		
		if( len( boxJSON.homepage ) and isValid( "URL", boxJSON.homepage ) ){
			print.greenLine( "Opening: #boxJSON.homepage#" );
			runCommand( "browse " & boxJSON.homepage );
		} else {
			print.redLine( "The 'homepage' set in the descriptor is not valid: " & boxJSON.homepage );
		}
		
	}

}