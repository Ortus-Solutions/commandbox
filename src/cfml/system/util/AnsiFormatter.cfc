/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
*/
component accessors=true {

	property name="printUtil"		inject="print";

	function cleanLine( line ) {

		// Log messages from the CF engine or app code writing directly to std/err out strip off "runwar.context" but leave color coded severity
		// Ex:
		// [INFO ] runwar.context: 04/11 15:47:10 INFO Starting Flex 1.5 CF Edition
		line = reReplaceNoCase( line, '^(\[[^]]*])( runwar\.context: )(.*)', '\1 \3' );

		// Log messages from runwar itself, simplify the logging category to just "Runwar:" and leave color coded severity
		// Ex:
		// [DEBUG] runwar.config: Enabling Proxy Peer Address handling
		// [DEBUG] runwar.server: Starting open browser action
		line = reReplaceNoCase( line, '^(\[[^]]*])( runwar\.[^:]*: )(.*)', '\1 Runwar: \3' );

		// [INFO ] dorkbox.systemTray.SystemTray: Successfully loaded
		line = reReplaceNoCase( line, '^(\[[^]]*])( DorkBox\.[^:]*: )(.*)', '\1 SystemTray: \3' );

		// Log messages from undertow's predicate logger, simplify the logging category to just "Server Rules:" and leave color coded severity
		// Ex:
		// [TRACE] io.undertow.predicate: Predicate [secure()] resolved to false for HttpServerExchange{ GET /CFIDE/main/ide.cfm}.
		// [TRACE] io.undertow.predicate: Path(s) [/CFIDE/main/ide.cfm] MATCH input [/CFIDE/main/ide.cfm] for HttpServerExchange{ GET /CFIDE/main/ide.cfm}.
		line = reReplaceNoCase( line, '^(\[[^]]*])( io\.undertow\.predicate: )(.*)', '\1 Server Rules: \3' );

		// Log messages from undertow's request dumper logger, simplify the logging category to just "Request Dump:"
		// Ex:
		// [TRACE] io.undertow.predicate: Predicate [secure()] resolved to false for HttpServerExchange{ GET /CFIDE/main/ide.cfm}.
		// [TRACE] io.undertow.predicate: Path(s) [/CFIDE/main/ide.cfm] MATCH input [/CFIDE/main/ide.cfm] for HttpServerExchange{ GET /CFIDE/main/ide.cfm}.
		line = reReplaceNoCase( line, '^(\[[^]]*])( io\.undertow\.request\.dump: )(.*)', 'Request Dump: \3' );

		// Log messages from Tuckey Rewrite engine "Rewrite UrlRewriter:"
		// Ex:
		// [DEBUG] org.tuckey.web.filters.urlrewrite.UrlRewriter: processing request for /services/training
		// [DEBUG] org.tuckey.web.filters.urlrewrite.RuleExecutionOutput: needs to be forwarded to /index.cfm/services/training
		line = reReplaceNoCase( line, '^(\[[^]]*])( org\.tuckey\.web\.filters\.urlrewrite\.UrlRewriter: )(.*)', '\1 Rewrite: \3' );
		line = reReplaceNoCase( line, '^(\[[^]]*])( org\.tuckey\.web\.filters\.urlrewrite\.RuleExecutionOutput: )(.*)', '\1 Rewrite Output: \3' );
		line = reReplaceNoCase( line, '^(\[[^]]*])( org\.tuckey\.web\.filters\.urlrewrite\.+)([^:]*: )(.*)', '\1 Rewrite \3\4' );

		// Strip off redundant severities that come from wrapping LogBox appenders in Log4j appenders
		// [INFO ] DEBUG my.logger.name This rain in spain stays mainly in the plains
		line = reReplaceNoCase( line, '^(\[(INFO |ERROR|DEBUG|WARN )] )(INFO|ERROR|DEBUG|WARN)( .*)', '[\3]\4' );

		// Add extra space so [WARN] becomes [WARN ]
		line = reReplaceNoCase( line, '^\[(INFO|WARN)]( .*)', '[\1 ]\2' );

		if( line.startsWith( '[INFO ]' ) ) {
			return reReplaceNoCase( line, '^(\[INFO ] )(.*)', '[#printUtil.boldCyan('INFO ')#] \2' );
		}

		if( line.startsWith( '[ERROR]' ) ) {
			return reReplaceNoCase( line, '^(\[ERROR] )(.*)', '[#printUtil.boldMaroon('ERROR')#] \2' );
		}

		if( line.startsWith( '[DEBUG]' ) ) {
			return reReplaceNoCase( line, '^(\[DEBUG] )(.*)', '[#printUtil.boldGreen('DEBUG')#] \2' );
		}

		if( line.startsWith( '[WARN ]' ) ) {
			return reReplaceNoCase( line, '^(\[WARN ] )(.*)', '[#printUtil.boldYellow('WARN ')#] \2' );
		}

		if( line.startsWith( '[TRACE]' ) ) {
			return reReplaceNoCase( line, '^(\[TRACE] )(.*)', '[#printUtil.boldMagenta('TRACE')#] \2' );
		}

		return line;

	}


}
