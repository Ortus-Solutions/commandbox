/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I am the s3 endpoint.
*/
component accessors="true" implements="IEndpoint" singleton {

    // DI
    property name="CR"                     inject="CR@constants";
    property name="fileEndpoint"           inject="commandbox.system.endpoints.File";
    property name="httpsEndpoint"          inject="commandbox.system.endpoints.HTTPS";
    property name="progressableDownloader" inject="ProgressableDownloader";
    property name="progressBar"            inject="ProgressBar";
    property name="S3Service"              inject="S3Service";
    property name="tempDir"                inject="tempDir@constants";
    property name='wirebox'                inject='wirebox';

    // Properties
    property name="namePrefixes" type="string";

    function init() {
        setNamePrefixes('s3');
        return this;
    }

    public string function resolvePackage(required string package, boolean verbose=false) {
        var job = wirebox.getInstance('interactiveJob');

        var fileName = 'temp#randRange( 1, 1000 )#.zip';
        var fullPath = tempDir & '/' & fileName;

        job.addLog('Downloading [s3:#package#]');

        try {
            // Download File
            var presignedPath = s3Service.generateSignedURL('s3:' & package, verbose);
            if (verbose) {
                job.addLog('Signed URL: ' & presignedPath);
            }
            var result = progressableDownloader.download(
                presignedPath, // URL to package
                fullPath, // Place to store it locally
                function(status) {
                    progressBar.update( argumentCollection = status );
                },
                function(newURL) {
                    job.addLog( "Redirecting to: '#arguments.newURL#'..." );
                }
            );
        } catch( UserInterruptException var e ) {
            rethrow;
        } catch( Any var e ) {
            throw( '#e.message##CR##e.detail#', 'endpointException' );
        };

        // Defer to file endpoint
        return fileEndpoint.resolvePackage( fullPath, arguments.verbose );
    }

    public function getDefaultName(required string package) {
        return httpsEndpoint.getDefaultName(package);
    }

    public function getUpdate(required string package, required string version, boolean verbose=false) {
        return httpsEndpoint.getUpdate(argumentCollection = arguments);
    }

}
