/**
 * Sync local config settings with remote settings for your user
 * Settings will be merged together
 * .
 * {code:bash}
 * config sync push
 * {code}
 * .
 * To completely replace remote settings wtih local settings, use the --overwrite flag
 * .
 * {code:bash}
 * config sync push --overwrite
 * {code}
 *
 **/
component {

	property name="packageService" inject="packageService";
	property name="ConfigService" inject="ConfigService";
	property name="JSONService" inject="JSONService";
	property name="endpointService" inject="endpointService";
	property name="jsondiff" inject="jsondiff";

	/**
	 * @endpointName  Name of custom forgebox endpoint to use
	 * @endpointName.optionsUDF endpointNameComplete
	 * @overwrite Overwrite local settings entirely with remote settings
	 **/
	function run( string endpointName, boolean overwrite=false ) {
		try {

			endpointName = endpointName ?: configService.getSetting( 'endpoints.defaultForgeBoxEndpoint', 'forgebox' );

			try {
				var oEndpoint = endpointService.getEndpoint( endpointName );
			} catch( EndpointNotFound var e ) {
				error( e.message, e.detail ?: '' );
			}

			var forgebox = oEndpoint.getForgebox();
			var APIToken = oEndpoint.getAPIToken();

			if( !len( APIToken ) ) {
				if( endpointName == 'forgebox' ) {
					error( 'You don''t have a Forgebox API token set.', 'Use "forgebox login" to authenticate as a user.' );
				} else {
					error( 'You don''t have a Forgebox API token set.', 'Use "endpoint login endpointName=#endpointName#" to authenticate as a user.' );
				}
			}
			var modules = {};
			var directory = expandPath( '/commandbox' );
			// package check
			if( packageService.isPackage( directory ) ) {
				modules = packageService
					.buildDependencyHierarchy( directory, 1 )
					.dependencies
					.map( (s,p)=>p.version );
			}
			var userData = forgebox.whoami( APIToken );
			var configSettings = {
				'config' : duplicate( ConfigService.getconfigSettings( noOverrides=true ) ),
				'modules' : modules
			};
			var remoteConfig = forgebox.getConfig( userData.username, APIToken );



			var diffDetails = jsondiff.diff(remoteConfig, configSettings )
				.reduce( ( diffDetails, item )=>{
						diffDetails[ item.type ].append( item );
						return diffDetails;
				}, { add : [], remove : [], change : [] } );

			if( diffDetails.remove.len() && overwrite ) {
				print.line().boldRedLine( 'Removed remote settings:' );
				diffDetails.remove.each( ( item )=>print.indented( buildPath( item.path ) & ' = ' ).line( item.old ) )
			}

			if( diffDetails.add.len() ) {
				print.line().boldGreenLine( 'New remote settings:' );
				diffDetails.add.each( ( item )=>print.indented( buildPath( item.path ) & ' = ' ).line( item.new ) )
			}

			if( diffDetails.change.len() ) {
				print.line().boldYellowLine( 'Changed settings:' );
				diffDetails.change.each( ( item )=>{
					print.indentedLine( buildPath( item.path ) & ' = ' )
						.indentedIndentedRed( 'Old Value: ' ).line( item.old )
						.indentedIndentedGreen( 'New Value: ' ).line( item.new );
				} );
			}

			if( !overwrite ) {
				configSettings = JSONService.mergeData( remoteConfig, configSettings );
			}

			if( ( diffDetails.remove.len() && overwrite ) || diffDetails.add.len() || diffDetails.change.len() ) {
				print.line().greenLine( forgebox.setConfig( configSettings, userData.username, APIToken ) );
			} else {
				print.greenLine( "All up to date!" ).line();
			}


		} catch( forgebox var e ) {
			// This can include "expected" errors such as "Email already in use"
			error( e.message, e.detail );
		}

	}

	function buildPath( tokens ) {
		return tokens.reduce( ( path, item )=>{
			if( isNumeric( item ) ) {
				return path & "[#item#]";
			}
			return path.listAppend( item, '.' );
		}, '' );
	}


	function endpointNameComplete() {
		return getInstance( 'endpointService' ).forgeboxEndpointNameComplete();
	}

}
