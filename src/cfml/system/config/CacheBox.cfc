/********************************************************************************
* Copyright Since 2005 ColdBox Framework by Luis Majano and Ortus Solutions, Corp
* www.ortussolutions.com
********************************************************************************
* The default ColdBox CacheBox configuration object that is used when the cache factory is created by itself
**/
component{
	
	/**
	* Configure CacheBox, that's it!
	*/
	function configure(){
		
		// The CacheBox configuration structure DSL
		cacheBox = {
			
			// Scope registration, automatically register the cachebox factory instance on any CF scope
			// By default it registeres itself on server scope
			scopeRegistration = {
				enabled = true,
				scope   = "application", // server, cluster, session
				key		= "cacheBox"
			},
			
			// The defaultCache has an implicit name "default" which is a reserved cache name
			// It also has a default provider of cachebox which cannot be changed.
			// All timeouts are in minutes
			defaultCache = {
				objectDefaultTimeout = 60,
				objectDefaultLastAccessTimeout = 30,
				useLastAccessTimeouts = true,
				reapFrequency = 2,
				freeMemoryPercentageThreshold = 0,
				evictionPolicy = "LRU",
				evictCount = 1,
				maxObjects = 200,
				objectStore = "ConcurrentSoftReferenceStore"
			},
			
			// Register all the custom named caches you like here
			caches = {
				metadataCache = {
					provider="wirebox.system.cache.providers.CacheBoxProvider",
					properties = {
						objectDefaultTimeout="0",
						objectStore="commandbox.system.util.DiskStore",
						directoryPath='/commandbox/system/mdCache'
					}
				}
			}
		};
	}	

}