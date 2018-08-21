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
    property name="httpsEndpoint" inject="commandbox.system.endpoints.HTTPS";
    property name="S3Service"     inject="S3Service";

    // Properties
    property name="namePrefixes" type="string";

    function init() {
        setNamePrefixes('s3');
        return this;
    }

    public string function resolvePackage(required string package, boolean verbose=false) {
        var presignedPath = s3Service.generateSignedURL('s3:' & package, verbose);
        return httpsEndpoint.resolvePackage(presignedPath.listRest(':'), verbose);
    }

    public function getDefaultName(required string package) {
        return httpsEndpoint.getDefaultName(package);
    }

    public function getUpdate(required string package, required string version, boolean verbose=false) {
        return httpsEndpoint.getUpdate(argumentCollection = arguments);
    }

}
