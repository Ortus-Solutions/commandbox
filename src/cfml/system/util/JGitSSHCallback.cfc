/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano
*
* I am a JGit TransportConfigCallback implemented in CFML. I attach an Apache MINA
* sshd based SSH session factory to git+ssh transports so JGit can clone over SSH.
*
* MINA sshd is used instead of JSch. JSch 0.1.55 was last released in 2018, cannot
* read the OpenSSH private key format ("-----BEGIN OPENSSH PRIVATE KEY-----") and
* cannot negotiate ed25519, rsa-sha2-* or curve25519. That meant newer keys and
* newer servers simply failed to authenticate.
*
* JGit normally discovers its SSH implementation via ServiceLoader, which does not
* work under BoxLang, so the session factory is built and attached explicitly here.
*/
component {

	/**
	 * JGit calls this to configure a transport before connecting.
	 *
	 * @transport The JGit Transport being configured.
	 */
	function configure( required any transport ) {

		// Only SSH transports can carry a session factory
		if( !isInstanceOf( arguments.transport, 'org.eclipse.jgit.transport.SshTransport' ) ) {
			return;
		}

		// MINA needs to know where to find keys and ssh config
		var homeDir = createObject( 'java', 'java.io.File' ).init(
			createObject( 'java', 'java.lang.System' ).getProperty( 'user.home' )
		);
		var sshDir = createObject( 'java', 'java.io.File' ).init( homeDir, '.ssh' );

		// Trust any host key, matching the previous JSch StrictHostKeyChecking=no behaviour
		var keyDatabase = createDynamicProxy(
			new commandbox.system.util.JGitAcceptAllServerKeyDatabase(),
			[ 'org.eclipse.jgit.transport.sshd.ServerKeyDatabase' ]
		);

		var builder = createObject( 'java', 'org.eclipse.jgit.transport.sshd.SshdSessionFactoryBuilder' ).init();
		builder.setHomeDirectory( homeDir );
		builder.setSshDirectory( sshDir );
		builder.setServerKeyDatabase( function( home, ssh ) {
			return keyDatabase;
		} );

		// MINA asks us for the identity files to try, so hand it our resolver
		var thisCallback = this;
		builder.setDefaultIdentities( function( keyDirectory ) {
			return thisCallback.getDefaultIdentities( keyDirectory );
		} );

		arguments.transport.setSshSessionFactory(
			builder.build( createObject( 'java', 'org.eclipse.jgit.transport.sshd.JGitKeyCache' ).init() )
		);
	}

	/**
	 * Resolve the private key files MINA should try, in order, for a given .ssh directory.
	 *
	 * MINA/JGit's own default list is id_rsa, id_dsa, id_ecdsa, id_ed25519. We add
	 * "identity" to it, because CommandBox has always documented that it looks for
	 * id_rsa, id_dsa or identity, and MINA would otherwise stop honouring that.
	 *
	 * Only files that actually exist are returned.
	 *
	 * @sshDir The ~/.ssh directory to look in.
	 */
	public array function getDefaultIdentities( required any sshDir ) {
		var keyFileNames = [ 'id_rsa', 'id_dsa', 'id_ecdsa', 'id_ed25519', 'identity' ];
		var keyPaths = [];

		for( var keyFileName in keyFileNames ) {
			var keyFile = createObject( 'java', 'java.io.File' ).init( arguments.sshDir, keyFileName );
			if( keyFile.exists() && keyFile.isFile() ) {
				keyPaths.append( keyFile.toPath() );
			}
		}

		return keyPaths;
	}

}
