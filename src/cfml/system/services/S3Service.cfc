/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I convert s3 paths (s3://bucket/path) to signed HTTPS urls
*
*/
component accessors="true" singleton {

	property name="configService"   inject="configService";
	property name="systemSettings"  inject="SystemSettings";
	property name="fileSystemUtil"  inject="FileSystem";
	property name='wirebox'         inject='wirebox';

	/**
	* Local URL to query for IAM role
	*/
	property name="iamRolePath" type="string";
	property name="bucketRegionCache" type="struct";

	/**
	* Constructor
	*/
	function init() {
		setIamRolePath('169.254.169.254/latest/meta-data/iam/security-credentials/');
		setBucketRegionCache({});
		return this;
	}

	function onDIComplete() {
	}

	/**
	 * Generate a signed HTTPS URL from a S3 path.
	 *
	 * @s3Path.hint Path to S3 object specified in the format s3://bucket/path/to/object
	 * @verbose.hint Set to true to log additional information
	 **/
	public string function generateSignedURL(
		required string s3Path,
		boolean verbose = false
	){
		var job = wirebox.getInstance('interactiveJob');

		// strip s3 prefix from path, if present
		if (s3Path.left(5) == 's3://') {
			s3Path = s3Path.right(s3Path.len() - 5);
		}

		var bucket = s3Path.listFirst('/').listFirst(':');
		var encodedRegion = s3Path.listFirst('/').listRest(':');
		var objectKey = s3Path.listRest('/');
		var awsSettings = resolveAwsSettings(bucket, verbose);
		var bucketRegion = len(encodedRegion) ? encodedRegion : resolveBucketRegion(bucket, awsSettings.defaultRegion, verbose);

		// if objectKey does not end in `.zip` we have to do a HEAD request to see if the path is valid as is
		// or if .zip should be appended to it - this is for backward compat with https://github.com/pixl8/s3-commandbox-commands
		if (!objectKey.endsWith('.zip')) {
			if (verbose) {
				job.addLog('Validating object key since it does not have a .zip extension');
			}
			var presignedPath = generatePresignedPath('HEAD', bucket, objectKey, bucketRegion, awsSettings.credentials);
			var req = makeHTTPRequest(presignedPath, 'HEAD');
			if (req.status_code == 404) {
				if (verbose) {
					job.addLog('Object key does not exist on S3, appending .zip extension');
				}
				objectKey &= '.zip';
			}
		}

		return generatePresignedPath('GET', bucket, objectKey, bucketRegion, awsSettings.credentials);
	}

	private function generatePresignedPath(method, bucket, objectKey, bucketRegion, credentials) {
		var isoTime = iso8601();
		var host = 's3.#bucketRegion#.amazonaws.com';
		var path = encodeUrl('/#bucket#/#objectKey#', false);

		// query string
		var qs = {
			'X-Amz-Algorithm': 'AWS4-HMAC-SHA256',
			'X-Amz-Credential': credentials.awsKey & '/' & isoTime.left(8) & '/' & bucketRegion & '/s3/aws4_request',
			'X-Amz-Date': isoTime,
			'X-Amz-Expires': 300,
			'X-Amz-SignedHeaders': 'host'
		};
		if (credentials.sessionToken.len()) {
			qs['X-Amz-Security-Token'] = credentials.sessionToken;
		}
		qs = qs.keyArray()
			.sort('text')
			.reduce((r, key) => r.listAppend('#key#=#encodeUrl(qs[key])#', '&'), '');

		// canonical request
		var canonicalRequest = [
			method.uCase(),
			path,
			qs,
			'host:#host#',
			'',
			'host',
			'UNSIGNED-PAYLOAD'
		].toList(chr(10));

		// string to sign
		var stringtoSign = [
			'AWS4-HMAC-SHA256',
			isoTime,
			isoTime.left(8) & '/' & bucketRegion & '/s3/aws4_request',
			hash(canonicalRequest, 'SHA-256').lcase()
		].toList(chr(10));

		// signature
		var signingKey = binaryDecode(hmac(isoTime.left(8), 'AWS4' & credentials.awsSecretKey, 'hmacSHA256', 'utf-8'), 'hex');
		signingKey = binaryDecode(hmac(bucketRegion, signingKey, 'hmacSHA256', 'utf-8'), 'hex');
		signingKey = binaryDecode(hmac('s3', signingKey, 'hmacSHA256', 'utf-8'), 'hex');
		signingKey = binaryDecode(hmac('aws4_request', signingKey, 'hmacSHA256', 'utf-8'), 'hex');
		var signature = hmac(stringToSign, signingKey, 'hmacSHA256', 'utf-8').lcase();

		qs &= '&X-Amz-Signature=' & signature;
		return 'https://' & host & path & '?' & qs;
	}

	private function resolveBucketRegion(bucket, defaultRegion, verbose=false) {
		if (verbose) {
			var job = wirebox.getInstance('interactiveJob');
			job.addLog('Resolving bucket region');
		}

		if (!bucketRegionCache.keyExists(bucket)) {
			var args = {
				urlPath: 'https://s3.#defaultRegion#.amazonaws.com',
				method: 'HEAD',
				redirect: false,
				headers: {
					'Host': '#bucket#.s3.amazonaws.com'
				}
			};
			var req = makeHTTPRequest(argumentCollection = args);
			bucketRegionCache[bucket] = req.responseheader['x-amz-bucket-region'];
		}

		return bucketRegionCache[bucket];
	}

	private function resolveAwsSettings(bucket, verbose=false) {
		var endpointSettings = configService.getSetting('endpoint.s3', {});

		var settings = {
			defaultRegion: endpointSettings.aws_default_region ?: systemSettings.getSystemSetting('AWS_DEFAULT_REGION', ''),
			profile: endpointSettings.aws_profile ?: systemSettings.getSystemSetting('AWS_PROFILE', 'default'),
			configFile: endpointSettings.aws_config_file ?: systemSettings.getSystemSetting('AWS_CONFIG_FILE', '~/.aws/config'),
			credentialsFile: endpointSettings.aws_shared_credentials_file ?: systemSettings.getSystemSetting('AWS_SHARED_CREDENTIALS_FILE', '~/.aws/credentials')
		};

		if (!settings.defaultRegion.len()) {
			var configFilePath = fileSystemUtil.resolvePath(settings.configFile);
			var region = getProfileString(configFilePath, settings.profile, 'region');
			settings.defaultRegion = len(region) ? region : 'us-east-1';
		}

		var endpointSettingsPerBucket = endpointSettings.keyExists(bucket) && isStruct(endpointSettings[bucket]) ? endpointSettings[bucket] : endpointSettings;
		settings.credentials = resolveCredentials(endpointSettingsPerBucket, settings.credentialsFile, settings.profile, verbose);

		return settings;
	}

	private function resolveCredentials(endpointSettings, credentialsFile, profile, verbose=false) {
		var job = wirebox.getInstance('interactiveJob');

		// check CommandBox endpoint settings for AWS credentials
		if (verbose) {
			job.addLog('Checking for AWS credentials in CommandBox settings: `endpoint.s3`')
		}
		var credentials = {
			awsKey: endpointSettings.aws_access_key_id ?: '',
			awsSecretKey: endpointSettings.aws_secret_access_key ?: '',
			sessionToken: endpointSettings.aws_session_token ?: ''
		}
		if (len(credentials.awsKey) && len(credentials.awsSecretKey)) {
			if (verbose) {
				job.addSuccessLog('AWS Credentials found in endpoint settings')
			}
			return credentials;
		}

		// check for AWS credentials in environment
		if (verbose) {
			job.addLog('Checking for AWS credentials in environment variables and Java system properties')
		}
		var credentials = {
			awsKey: systemSettings.getSystemSetting('AWS_ACCESS_KEY_ID', ''),
			awsSecretKey: systemSettings.getSystemSetting('AWS_SECRET_ACCESS_KEY', ''),
			sessionToken: systemSettings.getSystemSetting('AWS_SESSION_TOKEN', ''),
		};
		if (len(credentials.awsKey) && len(credentials.awsSecretKey)) {
			if (verbose) {
				job.addSuccessLog('AWS Credentials found in environment variables')
			}
			return credentials;
		}


		// check for an AWS credentials file for current user
		if (verbose) {
			job.addLog('Checking for AWS credentials in #credentialsFile#')
		}
		var credentialsFilePath = fileSystemUtil.resolvePath(credentialsFile);
		var credentials = {
			awsKey: getProfileString(credentialsFilePath, profile, 'aws_access_key_id'),
			awsSecretKey: getProfileString(credentialsFilePath, profile, 'aws_secret_access_key'),
			sessionToken: getProfileString(credentialsFilePath, profile, 'aws_session_token')
		};
		if (len(credentials.awsKey) && len(credentials.awsSecretKey)) {
			if (verbose) {
				job.addSuccessLog('AWS Credentials found in #credentialsFile#')
			}
			return credentials;
		}

		// check for IAM role
		if (verbose) {
			job.addLog('Checking for AWS credentials via IAM Role')
		}
		try {
			var roleName = makeHTTPRequest(urlPath=getIamRolePath(), timeout=1, allowProxy=false).filecontent;
			var req = makeHTTPRequest(urlPath=getIamRolePath() & roleName, timeout=1, allowProxy=false);
			var data = deserializeJSON(req.filecontent);
			var credentials = {
				awsKey: data.AccessKeyId,
				awsSecretKey: data.SecretAccessKey,
				sessionToken: data.Token,
				expires: parseDateTime(data.Expiration)
			};
			if (verbose) {
				job.addSuccessLog('AWS Credentials found via IAM Role: #roleName#')
			}
			return credentials;
		} catch(any e) {
			// pass
		}

		// Credentials unable to be located
		var errorMessage = '
			Could not locate S3 Credentials. Credentials can be set in CommandBox settings under the key `endpoint.s3`
			or by following one of the configuration methods used for configuring the AWS CLI.
			See https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html and in particular
			"Configuration Settings and Precedence".
		'.trim();
		throw(
			errorMessage,
			'S3Exception'
		);
	}

	private function iso8601(dateToFormat = now()) {
		return dateTimeFormat(dateToFormat, 'yyyymmdd', 'UTC') & 'T' & dateTimeFormat(dateToFormat, 'HHnnss', 'UTC') & 'Z';
	}

	private function encodeUrl(urlPath, encodeForwardSlash = true) {
		var result = replacelist(urlEncodedFormat(urlPath, 'utf-8'), '%2D,%2E,%5F,%7E', '-,.,_,~');
		if (!encodeForwardSlash) {
			result = result.replace('%2F', '/', 'all');
		}
		return result;
	}

	private function makeHTTPRequest(urlPath, method='GET', redirect=true, timeout=20, headers={}, allowProxy=true) {
		var req = '';
		var attributeCol = {
			url: urlPath,
			method: method,
			timeout: timeout,
			redirect: redirect,
			result: 'req'
		};

		if (allowProxy) {
			var proxy = configService.getSetting('proxy', {});
			if (proxy.keyExists('server') && len(proxy.server)) {
				attributeCol.proxyServer = proxy.server;
				for (var key in ['port', 'user', 'password'] ) {
					if (proxy.keyExists(key) && len(proxy[key])) {
						attributeCol['proxy#key#'] = proxy[key];
					}
				}
			}
		}

		cfhttp(attributeCollection = attributeCol) {
			for (var key in headers) {
				cfhttpparam(type='header', name=key, value=headers[key]);
			}
		}

		return req;
	}

}
