<p align="center">
	<img src="https://www.ortussolutions.com/__media/coldbox-185-logo.png">
	<br>
	<img src="https://www.ortussolutions.com/__media/wirebox-185.png" height="125">
	<img src="https://www.ortussolutions.com/__media/cachebox-185.png" height="125" >
	<img src="https://www.ortussolutions.com/__media/logbox-185.png"  height="125">
</p>

<p align="center">
	Copyright Since 2005 ColdBox Platform by Luis Majano and Ortus Solutions, Corp
	<br>
	<a href="https://www.coldbox.org">www.coldbox.org</a> |
	<a href="https://www.ortussolutions.com">www.ortussolutions.com</a>
</p>

----

# cbproxies

The `cbproxies` module is a raw library that allows you to build Java dynamic proxies to several key classes that allows your BoxLang or CFML code to do concurrency, streaming, and much more.  The `BaseProxy` can also be used so you can extend the module and create your own concrete dynamic proxies that extend the `BaseProxy`.

## BaseProxy

This object is the cornerstone for creatning dynamic proxies that can be used synchronously / asynchronously and keep the engine environment for you.  Every proxy needs to be created by the following code:

```js
proxy = new cbproxies.models.BiConsumer()
```

Each `BaseProxy` has the following base constructor `init()`:

```js
/**
 * Constructor
 *
 * @target         The target function to be applied via dynamic proxy to the required Java interface(s)
 * @debug          Add debugging messages for monitoring
 * @loadAppContext By default, we load the Application context into the running thread. If you don't need it, then don't load it.
 */
function init(
	required target,
	boolean debug          = false,
	boolean loadAppContext = true
)
```

* `target` - This can be a closure/function that is stored in the proxy that will later be used by the implemented dynamic proxy call.
* `debug` - Boolean flag that will enable debuging to console on certain key base proxy areas or by the implementing proxy.
* `loadAppContext` - This will load up the application context into the proxies scope.  This will allow the Java implementation to talk to anything within the BoxLang or CFML engine: scopes, databases, queries, orm, etc.

## Available Proxies

Here is a table of the available proxies in this module:

| Proxy Name 			| Java Class |
| ---------- 			| ---------- |
| `BiConsumer` 			| `java.util.function.BiConsumer` |
| `BiFunction` 			| `java.util.function.BiFunction` |
| `BinaryOperator` 		| `java.util.function.BinaryOperator` |
| `Callable` 			| `java.util.concurrent.Callable` |
| `Comparator` 			| `java.util.Comparator` |
| `Consumer` 			| `java.util.function.Consumer` |
| `Function` 			| `java.util.function.Function` |
| `FutureFunction` 		| `java.util.function.FutureFunction` |
| `Predicate` 			| `java.util.function.Predicate` |
| `Runnable` 			| `java.lang.Runnable` |
| `Supplier` 			| `java.util.function.Supplier` |
| `ToDoubleFunction` 	| `java.util.function.ToDoubleFunction` |
| `ToIntFunction` 		| `java.util.function.ToIntFunction` |
| `ToLongFunction` 		| `java.util.function.ToLongFunction` |

## System Requirements

* [Boxlang](https://www.boxlang.io/) 1+
* Adobe 2023+
* Lucee 5

********************************************************************************
Copyright Since 2005 ColdBox Framework by Luis Majano and Ortus Solutions, Corp
www.ortussolutions.com
********************************************************************************

### HONOR GOES TO GOD ABOVE ALL

Because of His grace, this project exists. If you don't like this, then don't read it, its not for you.

>"Therefore being justified by faith, we have peace with God through our Lord Jesus Christ:
By whom also we have access by faith into this grace wherein we stand, and rejoice in hope of the glory of God.
And not only so, but we glory in tribulations also: knowing that tribulation worketh patience;
And patience, experience; and experience, hope:
And hope maketh not ashamed; because the love of God is shed abroad in our hearts by the
Holy Ghost which is given unto us. ." Romans 5:5

### THE DAILY BREAD

 > "I am the way, and the truth, and the life; no one comes to the Father, but by me (JESUS)" Jn 14:1-12
