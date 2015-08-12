/**
* CommandBox CLI
* Copyright since 2012 by Ortus Solutions, Corp
* www.ortussolutions.com/products/commandbox
* ---
* Custom DocBox strategy for CommandBox commands and namespaces
*/
component extends="docbox.strategy.api.HTMLAPIStrategy"{

	/**
	* The output directory
	*/
	property name="outputDir" type="string";

	/**
	* The project title to use
	*/
	property name="projectTitle" default="Untitled" type="string";

	// Static variables.
	variables.static.TEMPLATE_PATH	= "/strategy/commandbox/resources/templates";
	variables.static.ASSETS_PATH 	= "/docbox/strategy/api/resources/static";

	/**
	* Constructor
	* @outputDir The output directory
	* @projectTitle The title used in the HTML output
	*/
	function init( required outputDir, string projectTitle="Untitled" ){
		super.init( argumentCollection=arguments );
		return this;
	}

	/**
	* Run this strategy
	* @qMetaData The metadata
	*/
	function run( required query qMetadata ){

		queryAddColumn( arguments.qMetadata, 'command' );
		queryAddColumn( arguments.qMetadata, 'namespace' );
		var index = 1;
		for( var thisRow in arguments.qMetadata ){
			var thisCommand 	= listAppend( thisRow.package, thisRow.name, '.' );
			thisCommand 		= replaceNoCase( thisCommand, thisRow.currentMapping, '', 'one'  );
			thisCommand 		= listChangeDelims( thisCommand, ' ', '.'  );
			var thisNamespace 	= listDeleteAt( thisCommand, listLen( thisCommand, ' ' ), ' ' );
			
			querySetCell( arguments.qMetadata, "command", thisCommand, index );
			querySetCell( arguments.qMetadata, "namespace", thisNamespace, index );
			index++;
		}

		// copy over the static assets
		directoryCopy( expandPath( variables.static.ASSETS_PATH ), getOutputDir(), true );

		//write the index template
		var args = {
			path 		 = getOutputDir() & "/index.html", 
			template 	 = "#variables.static.TEMPLATE_PATH#/index.cfm", 
			projectTitle = getProjectTitle()
		};
		writeTemplate( argumentCollection=args )
			// Write overview summary and frame
			.writeOverviewSummaryAndFrame( arguments.qMetaData )
			// Write packages
			.writePackagePages( arguments.qMetaData );

		return this;
	}

	/**
	* writes the overview-summary.html
	* @qMetaData The metadata
	*/
	function writeOverviewSummaryAndFrame( required query qMetadata ){
		var qPackages = new Query( dbtype="query", md=arguments.qMetadata, sql="
			SELECT DISTINCT package, namespace
			FROM md
			ORDER BY package" )
			.execute()
			.getResult();

		// overview summary
		writeTemplate(
			path			= getOutputDir() & "/overview-summary.html",
			template		= "#variables.static.TEMPLATE_PATH#/overview-summary.cfm",
			projectTitle 	= getProjectTitle(),
			qPackages 		= qPackages
		);

		//overview frame
		writeTemplate(
			path			= getOutputDir() & "/overview-frame.html",
			template		= "#variables.static.TEMPLATE_PATH#/overview-frame.cfm",
			projectTitle	= getProjectTitle(),
			qMetadata 		= arguments.qMetadata
		);

		return this;
	}

	/**
	* writes the package summaries
	* @qMetaData The metadata
	*/
	function writePackagePages( required query qMetadata ){
		var currentDir = 0;
		var qPackage = 0;
		var qClasses = 0;
		var qInterfaces = 0;

		// done this way as ACF compat. Does not support writeoutput with query grouping.
		include "#variables.static.TEMPLATE_PATH#/packagePages.cfm";

		return this;
	}

	/**
	* builds the class pages
	* @qPackage the query for a specific package
	* @qMetaData The metadata
	*/
	function buildClassPages( 
		required query qPackage,
		required query qMetadata 
	){
		for( var thisRow in arguments.qPackage ){
			var currentDir 	= variables.outputDir & "/" & replace( thisRow.package, ".", "/", "all" );
			var safeMeta 	= structCopy( thisRow.metadata );

			// Is this a class
			if( safeMeta.type eq "component" ){
				var qSubClass = getMetaSubquery( 
					arguments.qMetaData, 
					"UPPER( extends ) = UPPER( '#thisRow.package#.#thisRow.name#' )", 
					"package asc, name asc" 
				);
				var qImplementing = QueryNew("");
			} else {
				//all implementing subclasses
				var qSubClass = getMetaSubquery(
					arguments.qMetaData, 
					"UPPER(fullextends) LIKE UPPER('%:#thisRow.package#.#thisRow.name#:%')", 
					"package asc, name asc"
				);
				var qImplementing = getMetaSubquery(
					arguments.qMetaData, 
					"UPPER(implements) LIKE UPPER('%:#thisRow.package#.#thisRow.name#:%')", 
					"package asc, name asc"
				);
			}

			// write it out
			writeTemplate(
				path			= currentDir & "/#thisRow.name#.html",
				template		= "#variables.static.TEMPLATE_PATH#/class.cfm",
				projectTitle 	= variables.projectTitle,
				package 		= thisRow.package,
				name 			= thisRow.name,
				qSubClass 		= qSubClass,
				qImplementing 	= qImplementing,
				qMetadata 		= qMetaData,
				metadata 		= safeMeta,
				command 		= thisRow.command
			);
		}

		return this;
	}

}