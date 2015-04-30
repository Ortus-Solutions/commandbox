/**
 * Opens a package's bugs URL if found
 * .
 * {code:bash}
 * package bugs
 * {code}
 * .
 * Via alias
 * {code:bash}
 * bugs
 * {code}
 **/
component extends="commandbox.system.BaseCommand" aliases="docs,documentation" excludeFromHelp=false {
	
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
		
		if( len( boxJSON.documentation ) and isValid( "URL", boxJSON.documentation ) ){
			print.greenLine( "Opening: #boxJSON.documentation#" );
			openURL( boxJSON.documentation );
		} else {
			print.redLine( "The 'documentation' set in the descriptor is not valid: " & boxJSON.documentation );
		}
		
	}

}