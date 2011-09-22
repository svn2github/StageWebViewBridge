(function(window)
{
	window.StageWebViewBridge = (function()
	{         
		var callBacks = [];
		var rootPath = "";
		var sourcePath = "";
		var cached_extensions = [];
		var fileRegex;
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
			window.location.href='about:[SWVData]'+btoa( JSON.stringify( _serializeObject ) );
		};
		var addCallback = function( name, fn )
		{
			callBacks[ name ] = fn;
		};	
		var getFilePath = function( fileName )
		{
			if( fileRegex.exec(fileName) != null )
			{
				return rootPath+'/'+fileName.split('jsfile:/')[1];
			}
			else
			{
				return sourcePath+'/'+fileName.split('jsfile:/')[1];
			}
			
		};
		var setRootPath = function( path, sPath, cached )
		{
			cached_extensions = cached;
			fileRegex =new RegExp(( "\(jsfile:\/\)\(\[\\w\-\\\.\\\/%\]\+\("+cached_extensions.join('\|')+"\)\)" ),"gixsm");
			sourcePath = sPath;
			rootPath = path;	
		};
		window.onload = function()
		{
			/*call( "getRootPath" , setRootPath );*/
		};
		return {
			doCall: doCall,
            call: call,
			getFilePath:getFilePath,
			setRootPath:setRootPath
		};
	})();
})(window);