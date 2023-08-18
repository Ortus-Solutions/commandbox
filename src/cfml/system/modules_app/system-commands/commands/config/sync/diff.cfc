/**
 * Compare local config settings with remote settings for your user
  * .
 * {code:bash}
 * config sync diff
 * {code}
 * .
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
	 **/
	function run( string endpointName ) {
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
			var remoteConfig = forgebox.getConfig( userData.username, APIToken );
			var configSettings = {
				'config' : duplicate( ConfigService.getconfigSettings( noOverrides=true ) ),
				'modules' : modules
			};


			var diffDetails = jsondiff.diff(remoteConfig, configSettings )
				.reduce( ( diffDetails, item )=>{
						diffDetails[ item.type ].append( item );
						return diffDetails;
				}, { add : [], remove : [], change : [] } );

			if( diffDetails.remove.len() ) {
				print.line().boldBlueLine( 'Remote-only settings:' );
				diffDetails.remove.each( ( item )=>print.indented( buildPath( item.path ) & ' = ' ).line( item.old ) )
			}

			if( diffDetails.add.len() ) {
				print.line().boldGreenLine( 'Local-only settings:' );
				diffDetails.add.each( ( item )=>print.indented( buildPath( item.path ) & ' = ' ).line( item.new ) )
			}

			if( diffDetails.change.len() ) {
				print.line().boldMagentaLine( 'Changed settings:' );
				diffDetails.change.each( ( item )=>{
					print.indentedLine( buildPath( item.path ) & ' = ' )
						.indentedIndentedBlue( 'Remote Value: ' ).line( item.old )
						.indentedIndentedGreen( 'Local Value: ' ).line( item.new );
				} );
			}

			if( !diffDetails.add.len() && !diffDetails.remove.len() && !diffDetails.change.len() ) {
				print.boldGreenLine( "All config settings are identical between remote and local" );
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
