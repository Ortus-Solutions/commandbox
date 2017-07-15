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
component aliases="homepage" {

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
			openURL( boxJSON.homepage );
		} else {
			print.redLine( "The 'homepage' set in the descriptor is not valid: " & boxJSON.homepage );
		}

	}

}
