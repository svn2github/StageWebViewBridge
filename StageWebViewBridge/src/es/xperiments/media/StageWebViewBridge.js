/*
Copyright 2011 Pedro Casaubon

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
 */
(function(window)
{
	window.StageWebViewBridge = (function()
	{         
		var callBacks = [];
		var rootPath = "";
		var docsPath = "";
		var sourcePath = "";
		var cached_extensions = [];
		var fileRegex;
		var sendingProtocol = "";
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
			
		};
		var setRootPath = function( aRootPath, aSourcePath, aDocsPath, aCachedExtensions, asendingProtocol )
		{
			sendingProtocol = asendingProtocol;
			cached_extensions = aCachedExtensions;
			fileRegex =new RegExp(( "\(jsfile:\/\)\(\[\\w\-\\\.\\\/%\]\+\("+cached_extensions.join('\|')+"\)\)" ),"gixsm");
			sourcePath = aSourcePath;
			rootPath = aRootPath;
			docsPath = aDocsPath;
		};
		return {
			doCall: doCall,
            call: call,
			getFilePath:getFilePath,
			setRootPath:setRootPath
		};
	})();
})(window);