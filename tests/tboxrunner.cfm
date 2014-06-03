<cfsilent>
<cfparam name="url.target" 			default="tests.cfml">
<cfparam name="url.railoversion" 	default="4.2">
<cfparam name="url.recurse" 		default="true">
<cfparam name="url.labels"			default="">
<cfparam name="url.reporter"		default="ANTJunit">
<cfscript>
request.webadminpassword="testtest";
// create testbox
if( directoryExists( expandPath("/coldbox/system/testing" ) ) ){
	testBox = new coldbox.system.testing.TestBox();
} else {
	testBox = new testbox.system.testing.TestBox();
}
// clean up
for( key in URL ){
	url[ key ] = xmlFormat( trim( url[ key ] ) );
}
// execute tests
if( len( url.target ) ){
	// directory or CFC, check by existence
	try {
		if( left(url.railoversion,3) EQ "4.1") {
			// using testbox mxunit really, thus TestSuite().testSuite() and ANTJunit vs JUnitxml
		  	results = new mxunit.framework.TestSuite().testSuite().addAll(url.target).run().getResultsOutput('ANTJunit');
		} else if( !directoryExists( expandPath( "/#replace( url.target, '.', '/', 'all' )#" ) ) ){
			results = testBox.run( bundles=url.target, reporter=url.reporter, labels=url.labels );
		} else {
			results = testBox.run( directory={ mapping=url.target, recurse=url.recurse }, reporter=url.reporter, labels=url.labels );
		}
		results = trim(results);
	} catch (any e) {
		results = '<testsuites><testsuite><testcase name="#url.target#" time="0.001" classname="#url.target#"><failure message="#e.message#"><![CDATA[#serializeJSON(e)#]]></failure></testcase></testsuite></testsuites>';
	}
} else {
	results = 'No tests selected for running!';
}
</cfscript></cfsilent><cfset writeOutput(results) />
