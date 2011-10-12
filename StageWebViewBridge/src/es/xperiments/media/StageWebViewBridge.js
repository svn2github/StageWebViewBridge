(function(window)
{
	window.StageWebViewBridge = (function()
	{         
		var callBacks = [];
		var onReadyHandlers = [];
		var cached_extensions = [];
		var DOMContentLoadedCallBack =function(){};
		var devicereadyCallBack = function(){};
		var rootPath = "";
		var docsPath = "";
		var sourcePath = "";
		var fileRegex;
		var currentHandler;
		var ua = navigator.userAgent;
		var pathsReady = false;
		var checker =
		{
		  iphone: ua.match(/(iPhone|iPod|iPad)/) === null ? false:true,
		  android: ua.match(/Android/) === null ? false: navigator.platform.match(/Linux/) == null ? false:true
		};		
		var sendingProtocol = checker.iphone ? 'about:':'tuoba:';		

		var doCall = function( jsonArgs )
		{
			setTimeout(function() { deferredDoCall(jsonArgs); },0 );
		};
	    
		var deferredDoCall = function( jsonArgs )
		{
			var _serializeObject = JSON.parse( atob( jsonArgs ) );
			var method = _serializeObject.method;
			var returnValue = true;
			if( method.indexOf('[SWVMethod]')==-1 )
			{			
				var targetFunction;
				if( method.indexOf('.')==-1)
				{
					targetFunction = window[ method ];
				}
				else
				{
					var splitedPath = method.split('.');
					targetFunction=window;
					for( var i=0; i<splitedPath.length; i++ )
					{
						targetFunction = targetFunction[ splitedPath[ i ] ];
					};
				};
				returnValue = targetFunction.apply(null, _serializeObject.arguments );
			}
			else
			{
				var targetFunction = callBacks[ method ];
				returnValue = targetFunction.apply(null, _serializeObject.arguments );
			};

			if( _serializeObject.callBack !=undefined  )
			{	
				call( _serializeObject.callBack, null, returnValue );  		
			};							
		};
		
		var call = function( )
		{
			var argumentsArray = [];
			var _serializeObject = {};
				_serializeObject.method = arguments[ 0 ];
			if( arguments[ 1 ] !=null ) _serializeObject.callBack = '[SWVMethod]'+arguments[ 0 ];

			if( arguments.length>2)
			{
				for (var i = 2; i < arguments.length; i++)
				{
					argumentsArray.push( arguments[ i ] );
				};
			};

			_serializeObject.arguments = argumentsArray;
			if( _serializeObject.callBack !=undefined ) { addCallback('[SWVMethod]'+arguments[ 0 ], arguments[ 1 ] ); };
			window.location.href=sendingProtocol+'[SWVData]'+btoa( JSON.stringify( _serializeObject ) );
		};
		
		var addCallback = function( name, fn )
		{
			callBacks[ name ] = fn;
		};
		
		var getFilePath = function( fileName )
		{
			if( !pathsReady )
			{
				throw "StageWebViewBridge.getFilePath('"+fileName+"').Paths still not set. Listen to document.deviceready event before access this method.";
			}
			else
			{	
				if( fileName.indexOf('jsfile:') !=-1 )
				{	
					if( fileRegex.exec(fileName) != null )
					{
						return rootPath+'/'+fileName.split('jsfile:/')[1];
					}
					else
					{
						return sourcePath+'/'+fileName.split('jsfile:/')[1];
					};
				};
				if( fileName.indexOf('jsdocfile:') !=-1 )
				{	
					return docsPath+'/'+fileName.split('jsdocfile:/')[1];
				};
			}
		};
		/* fakeEventDispatcher */
		var dispatchFakeEvent = function( name )
		{
			var fakeEvent = document.createEvent("UIEvents");
			fakeEvent.initEvent( name , false,false );
			document.dispatchEvent(fakeEvent);
		};		
		
		/*[Event("ready")]*/
		var ready = function( handler )
		{
			onReadyHandlers.push( handler );
		};
		
		var onReady = function( )
		{
			document.addEventListener('SWVBReady', function()
			{
				currentHandler();
			}, false );
	
			for (var i=0; i<onReadyHandlers.length; i++)
			{
				currentHandler = onReadyHandlers[ i ];
				dispatchFakeEvent("SWVBReady");
			};
		
		};
		
		var getPathsData = function()
		{
			call('getFilePaths', onGetFilePaths );
		};

		var onGetFilePaths = function( data )
		{
			sourcePath = data.sourcePath;
			rootPath = data.rootPath;
			docsPath = data.docsPath;
			cached_extensions =  data.extensions ;
			fileRegex =new RegExp(( "\(jsfile:\/\)\(\[\\w\-\\\.\\\/%\]\+\("+cached_extensions.join('\|')+"\)\)" ),"gixsm");
			pathsReady = true;
			onReady();
			devicereadyCallBack();
		};
		
		/* Assign a callback function that executes the on deviceready */
		var deviceready = function( fn )
		{
			devicereadyCallBack = fn;
		};
		
		/* Assign a callback function that returns an object to the DOMContentLoaded event */
		var domLoaded = function( fn )
		{
			DOMContentLoadedCallBack = fn;
		};
		
		/* Call AS3 to fire StageWebViewBridgeEvent.DOM_LOADED */
		var callDOMContentLoaded = function()
		{
			var _serializeObject = {};
				_serializeObject.method = 'onCallDOMContentLoaded';
				_serializeObject.arguments = [DOMContentLoadedCallBack()];
			document.title = sendingProtocol+'[SWVData]'+btoa( JSON.stringify( _serializeObject ) );			
		};
		
		domLoaded( function() { return null });
		window.addEventListener( 'load', getPathsData, false );
		document.addEventListener('DOMContentLoaded', callDOMContentLoaded, false );
		return {
			doCall: doCall,
            call: call,
			getFilePath:getFilePath,
			ready:ready,
			deviceready:deviceready,
			domLoaded:domLoaded
		};
	})();
})(window);