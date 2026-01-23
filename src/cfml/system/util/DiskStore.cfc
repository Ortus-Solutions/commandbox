/**
 * ********************************************************************************
 * Copyright Since 2005 ColdBox Framework by Luis Majano and Ortus Solutions, Corp
 * www.ortussolutions.com
 * ********************************************************************************
 * Author      : Luis Majano
 * Description : I am a disk store, I am not that fancy as I am slower.
 */
component implements="wirebox.system.cache.store.IObjectStore" {

	/**
	 * Constructor
	 *
	 * @cacheProvider The associated cache provider as wirebox.system.cache.ICacheProvider
	 * @cacheProvider.doc_generic wirebox.system.cache.ICacheProvider
	 */
	public DiskStore function init( required any cacheProvider ) {
		// Store Fields
		var fields = "hits,timeout,lastAccessTimeout,created,LastAccessed,isExpired,isSimple";
		var config = arguments.cacheProvider.getConfiguration();

		// Prepare instance
		variables.instance = {
			cacheProvider : arguments.cacheProvider,
			storeID       : createObject( "java", "java.lang.System" ).identityHashCode( this ),
			indexer       : createObject( "component", "commandbox.system.util.MetadataIndexer" ).init( fields )//,
			//converter     : createObject( "component", "wirebox.system.core.conversion.ObjectMarshaller" ).init()
		};

		// Get extra configuration details from cacheProvider's configuration for this diskstore
		// Auto Expand
		if( !structKeyExists( config, "autoExpandPath" ) ) {
			config.autoExpandPath = true;
		}

		// Check directory path
		if( !structKeyExists( config, "directoryPath" ) ) {
			throw(
				message = "The 'directoryPath' configuration property was not found in the cache configuration",
				detail  = "Please check the cache configuration and add the 'directoryPath' property. Current Configuration: #config.toString()#",
				type    = "DiskStore.InvalidConfigurationException"
			);
		}

		// AutoExpand
		if( config.autoExpandPath ) {
			instance.directoryPath = expandPath( config.directoryPath );
		} else {
			instance.directoryPath = config.directoryPath;
		}

		// Check if directory exists else create it
		if( !directoryExists( instance.directoryPath ) ) {
			directoryCreate( instance.directoryPath );
		}

		return this;
	}

	/**
	 * Flush the store to a permanent storage
	 */
	public void function flush() {
	}

	/**
	 * Reap the storage, clean it from old stuff
	 */
	public void function reap() {
	}

	/**
	 * Get this storage's ID
	 */
	public any function getStoreID() {
		return instance.storeID;
	}

	/**
	 * Clear all elements of the store
	 */
	public void function clearAll() {
		directoryDelete( instance.directoryPath, true );

		try {
			directoryCreate( instance.directoryPath, true, true );
		} catch( any e ) {
			sleep( 500 );
			directoryCreate( instance.directoryPath, true, true );
		}
	}

	/**
	 * Get the store's pool metadata indexer structure
	 */
	public any function getIndexer() {
		return instance.indexer;
	}

	/**
	 * Get all the store's object keys
	 */
	public any function getKeys() {
		return instance.indexer.getKeys();
	}

	/**
	 * Get all the store's object keys sorted
	 * @sortType The type of sorting: text, numeric, date
	 * @sortOrder The order of sorting: asc, desc
	 */
	public Array function getSortedKeys(required Any property, Any sortType = text, Any sortOrder = asc) {
		return instance.indexer.getSortedKeys( arguments.property, arguments.sortType, arguments.sortOrder );
	}
	
	/**
	 * Check if an object is in cache.
	 *
	 * @objectKey The key of the object
	 */
	public any function lookup( required any objectKey ) {
		lock name="DiskStore.#instance.storeID#.#arguments.objectKey#" type="readonly" timeout="10" throwonTimeout="true" {
			// Check if object on disk, on indexer and NOT expired
			if( fileExists( getCacheFilePath( arguments.objectKey ) ) ) {
				return true;
			}
			return false;
		}
	}

	/**
	 * Get an object from cache
	 *
	 * @objectKey The key of the object
	 */
	public any function get( required any objectKey ) {
		lock name="DiskStore.#instance.storeID#.#arguments.objectKey#" type="exclusive" timeout="10" throwonTimeout="true" {
			if( lookup( arguments.objectKey ) ) {
				return getQuiet( arguments.objectKey );
			}
		}
	}

	/**
	 * Get an object from cache with no stats
	 *
	 * @objectKey The key of the object
	 */
	public any function getQuiet( required any objectKey ) {
		var thisFilePath = getCacheFilePath( arguments.objectKey );

		lock name="DiskStore.#instance.storeID#.#arguments.objectKey#" type="exclusive" timeout="10" throwonTimeout="true" {
			if( lookup( arguments.objectKey ) ) {
				var fileContents = fileRead( thisFilePath );
				// If file is not JSON, it is corrupted.
				if( isJSON( fileContents ) ) {
					return deserializeJSON( fileContents );
				} else {
					try {
						fileDelete( thisFilePath );
					} catch( any e ) {
						// If the file didn't exist, ignore it. This can happen
						// when two CommandBox instances start at the same time.
					}
				}
			}
		}
	}

	/**
	 * Mark an object for expiration
	 *
	 * @objectKey The object key
	 */
	public void function expireObject( required any objectKey ) {
		lock name="DiskStore.#instance.storeID#.#arguments.objectKey#" type="exclusive" timeout="10" throwonTimeout="true" {
			instance.indexer.setObjectMetadataProperty( arguments.objectKey, "isExpired", true );
		}
	}

	/**
	 * Test if an object in the store has expired or not
	 *
	 * @objectKey The object key
	 */
	public any function isExpired( required any objectKey ) {
		lock name="DiskStore.#instance.storeID#.#arguments.objectKey#" type="readonly" timeout="10" throwonTimeout="true" {
			return instance.indexer.getObjectMetadataProperty( arguments.objectKey, "isExpired" );
		}
	}

	/**
	 * Sets an object in the storage.
	 *
	 * @objectKey         The object key
	 * @object            The object to save
	 * @timeout           Timeout in minutes
	 * @lastAccessTimeout Timeout in minutes
	 * @extras            A map of extra name-value pairs
	 */
	public void function set(
		required any objectKey,
		required any object,
		any timeout           = "",
		any lastAccessTimeout = "",
		any extras            = {}
	) {
		var thisFilePath = getCacheFilePath( arguments.objectKey );

		lock name="DiskStore.#instance.storeID#.#arguments.objectKey#" type="exclusive" timeout="10" throwonTimeout="true" {
			fileWrite( thisFilePath, serializeJSON( arguments.object ) );
		}
	}

	/**
	 * Clears an object from the storage pool
	 *
	 * @objectKey The object key
	 */
	public any function clear( required any objectKey ) {
		var thisFilePath = getCacheFilePath( arguments.objectKey );

		lock name="DiskStore.#instance.storeID#.#arguments.objectKey#" type="exclusive" timeout="10" throwonTimeout="true" {
			// check it
			if( !fileExists( thisFilePath ) ) {
				return false;
			}
			// Remove it
			fileDelete( thisFilePath );

			return true;
		}
	}

	/**
	 * Get the cache's size in items
	 */
	public any function getSize() {
		return instance.indexer.getSize();
	}

	/**
	 * Get the cached file path
	 *
	 * @objectKey The key of the object
	 */
	private any function getCacheFilePath( required any objectKey ) {
		return instance.directoryPath & "/" & hash( arguments.objectKey ) & ".cachebox";
	}

	/**
	 * Create and return a util object
	 */
	private any function getUtil() {
		return createObject( "component", "wirebox.system.core.util.Util" );
	}

	/**
	 * Get cached object metadata struct
	 *
	 * @objectKey The key of the object
	 */
	public Struct function getCachedObjectMetadata(required Any objectKey) {
		return instance.indexer.getObjectMetadata( arguments.objectKey );
	}

}
