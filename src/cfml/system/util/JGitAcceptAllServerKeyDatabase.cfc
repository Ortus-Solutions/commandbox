/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano
*
* I am a ServerKeyDatabase for the Apache MINA sshd library that trusts any server
* (host) key presented to us.
*
* This preserves the behaviour of the old JSch based factory, which set
* StrictHostKeyChecking=no, so existing users who clone from hosts not present in
* their known_hosts file are not suddenly blocked or prompted.
*
* This is a CFML implementation of a Java interface supplied by a jar. A BoxLang
* class cannot use `implements` for a jar supplied interface, so it is instantiated
* through createDynamicProxy() instead.
*/
component {

	/**
	 * Return any known keys for the server. We do not persist server keys, so we
	 * always report that we know nothing and let accept() make the decision.
	 *
	 * @host     The host name being connected to.
	 * @address  The resolved address of the host.
	 * @config   The ServerKeyDatabase configuration.
	 */
	function lookup( required any host, required any address, required any config ) {
		return [];
	}

	/**
	 * Decide whether to trust the key the server presented. We accept every key so
	 * that host key verification never blocks a clone.
	 *
	 * @host         The host name being connected to.
	 * @address      The resolved address of the host.
	 * @key          The server key that was presented.
	 * @config       The ServerKeyDatabase configuration.
	 * @credentials  The credentials provider, if any.
	 */
	function accept( required any host, required any address, required any key, required any config, required any credentials ) {
		return true;
	}

}
