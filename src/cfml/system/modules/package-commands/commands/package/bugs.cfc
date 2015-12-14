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
component extends="commandbox.system.BaseCommand" aliases="bugs" {
	
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
		
		if( len( boxJSON.bugs ) and isValid( "URL", boxJSON.bugs ) ){
			print.greenLine( "Opening: #boxJSON.bugs#" );
			openURL( boxJSON.bugs );
		} else {
			print.redLine( "The 'bugs' set in the descriptor is not valid: " & boxJSON.bugs );
		}
		
	}

}