/*global jQuery */
/*jslint browser:true, nomen: true, laxbreak:true */
/*
 * TODO: use standard JSON functions, see http://waterken.sourceforge.net/
 * TODO: might use promises rather than callbacks, as in Robust Composition, see http://waterken.sourceforge.net/
 */
(function($) {
   String.prototype.isPrefix = function(str) {
     return (this.length<=str.length) && (str.slice(0,this.length)==this);
   };

   function isUndefined(o) {
     return typeof o == "undefined";
   }
   function isDefined(o) {return ! isUndefined(o);}

   /** QuicQuid Terms **/

   // Application
   function App(f,o) {
      this.f=f;this.o=o;
   }

   //BUG: in fact this convert to canonical format
   App.prototype.toJSON = function() {return $.toJSON(this.f)+"("+$.toJSON(this.o)+")";};
   function a(f,o) {
     return new App(f,o);
   }

   // Variables
   function Var(v) {
      this.name=v;
   }
   Var.prototype.toJSON = function() {return "?"+this.name;}; //BUG
   function v(name) {
     return new Var(name);
   }

   // Code already in QuicQuid format, to be quoted verbatim.
   function Q(q) {
      this.q=q;
   }
   Q.prototype.toJSON = function() {return this.q;};
   function q(term) {
     return new Q(term);
   }

   /*
    * Modify in place a JSON representation of a QuicQuid term to the corresponding term.
    */
   function json2term (o) {

   function walk(o,k) {
     var j = o[k];

     if (j && typeof j === 'object') {

       // It is a coded term
       if (j.t) {
	 switch (j.t) {
	   case 'v': return v(j.v);
	   case 'a': return a(walk(j.v,0),walk(j.v,1));
	   case 'o': j = j.v; break; // Traverse the link to the object inside.
	   default: throw new Error("Unknown type "+j.t);
	 }
       }

       for (k in j)
	 if (Object.hasOwnProperty.call(j,k)) j[k]=walk(j,k);

     }

     return j;
   }

   return walk([o],0);
   }



   /** Address handling **/

   var Address = function() {
     // The address assigned to this router, e.g.: "/http/123"
     var localAddr;

     // Counter used to create unique endpoint/channel identifiers
     var counter=0;

     function hasAddr() {return isDefined(localAddr);};
     function setAddr(addr)  {
       localAddr=addr;
       console.log("localAddr",localAddr);
     }

     // TODO: should it be moved to the term section?
     // BUG: these addresses are easy to guess and could easily be targeted.
     function Addr() {
       this.local = ""+(++counter);
     }

     Addr.prototype.toJSON = function() {
       if (! hasAddr()) throw new Error("Cannot generate full address for " + this.local);
       return $.toJSON(localAddr + "/" + this.local);
     };

     function unique() {
       return new Addr();
     }

     // get address in string form
     function solve(addr) {
       return (typeof addr == "string") ? addr : addr.local;
     }

     //  localKey("/http/1234/ag1/123 == "ag1/123" (if local router's address == "/http/1234")
     function localKey(addr) {
       if (!isLocal(addr)) throw new Error("localKey: '" + addr+"' is not a local address!");

       var a = solve(addr);
       if (isLocalForm(a)) return a;

       if (! hasAddr()) throw new Error("localKey: local address is unknown");
       return a.slice(localAddr.length+1);
     }

     function isLocal (addr) {
       var a = solve(addr);
       var r = isLocalForm(a) || (isDefined(localAddr) && localAddr.isPrefix(a));
       //console.log("isLocal("+a+")->"+r+" ",a,typeof a,a[0],isLocalForm(a),(typeof localAddr != "undefined") ? localAddr : "undefined address",typeof localAddr != "undefined" && localAddr.isPrefix(a));
       return r;
     }

     function isLocalForm (addr) {
       return addr.charAt(0)!=="/";
     }


     return {unique:unique,localKey:localKey,isLocal:isLocal,addr:function(){return localAddr;},hasAddr:hasAddr,setAddr:setAddr};

     }();



   /** Local Router **/

     // Current endpoints/channels
     // chans :: Map channelLocalKey -> channelCallBack
     var chans={};

     /* Create a new unique temporary end point (a message receiver)
      * @handler a function that accepts a single parameter corresponding to the message received on the end point
      * @return the end point
      */
     function newEndPoint(handler) {
       var addr = Address.unique();
       chans[Address.localKey(addr)] = handler;
       return addr;
     }


     /**
      * @id the end point id returned by newEndPoint().
      * @return true if there was a end point with the given id, false otherwise
      */
     function delEndPoint(addr) {
       var id = Address.localKey(addr);
       var exists = isDefined(chans[id]);
       if (exists) delete chans[id];
       return exists;
     }

     // The outgoing messages waiting to be sent.
     var msgsToSend = [];

     // The function called when an event takes place
     // TODO: unify with console.warn ...
     // var eventHandlers=[];
   /*
     function fill(v,filler,len) {
       var n = len-(v+"").length;
       for (var i=0;i<n;i++) v = filler + v;
       return v;
     };
     function msgTime() {
       var t = new Date();
       return fill(t.getHours(),' ',2)+":"+fill(t.getMinutes(),'0',2) +"+"+ fill(t.getMilliseconds(),'0',3) + "ms";
     };
    */
     /*
      * Send a message asynchronously to a given end point, if possible.
      * NOTE: no delivery guarantees.
      * @to  the destination end point
      * @msg the msg, a QuicQuid term.
      * @return undefined
      */
     var msgID =0;
     function send(to,body) {
	//console.log("send to:",to,"body:",body);
	$(document).trigger("quicquid.msg",{to:to,body:body,id:++msgID});

        /*
	if (to==="local/router") {
	  if (body && body.type=="subscribeEvents" && Address.isLocal(body.channel)) eventHandlers.push(body.channel);
	  return;
	};
	 */

	if (Address.isLocal(to)) {
	  //console.log("local message to: "+Address.localKey(to));
	  var cb = chans[Address.localKey(to)];

	  // Even local messages are delivered asynchronously.
	  if (cb) setTimeout(function() {cb(body);},0);   // TODO: Decide if we should also send the 'to' field.
	  else console.warn("Could not deliver local message:",to,body);

	} else {
	  //console.log("remote message to: "+to);
	  // NOTE: we assume that push is an atomic operation
	    msgsToSend.push([to,body]);
	}
      }


      /** HTTP Interface **/

      // TODO: what in case of network error/total server failure?

      var netURL = ((("https:" === document.location.protocol) || ("http:" === document.location.protocol)) ? "" : "http://127.0.0.1:8080")+"/api/";
      console.log("Server=",netURL);
      //netURL = "http://net.quicquid.org/api/";
     //netURL = "http://127.0.0.1:8080/api/";

      var currentCalls=0;
      var forceCall=false;
      var oks=0,bads=0;


	// BUG: Clients that use libraries that call ajax won't work, a better solution is to patch directly jquery.
	// Client ajax calls have to go through this function.
        // the processing of the results of all ajax calls seems to be queued
        // So: if there is a pending long call to the server, a call to, say freebase, will be performed immediately
        //     BUT the result won't be returned before the previous call is completed, possibly long after it.
	var jqueryAjax = $.ajax;
	$.ajax = function (pars) {
	  console.log("QQ AJAX",pars);
	  jqueryAjax(pars);
	  forceCall=true;
	};


      /**
       Receive and deliver messages received from the remote server.
       data: An array of messages.
       Every message is an array [to,body] where:
       to  ::String = the full address of the local end point (e.g. <endpoint>.34.12. where .34.12. is the localAddress).
       body::Object = the message body, as a JSON object.
       */
      function success(data, textStatus) {
	oks++;
	received();

	if (! (data instanceof Array)) {
	  var err = data.message ? data.message : "unknown error";
	  console.error("Error received from server: "+err);
	  return;
	}

	// Convert msg bodies to terms and send.
	//console.log("received " + data.length + " msgs.");
	for (var i=0;i<data.length;i++) send(data[i][0],json2term(data[i][1]));

      }

	function received() {
	  --currentCalls;
	}


	// The main function that take care of connecting to the remote quicquid server, send the outgoing messages and receive new incoming messages.
	function deliver() {

          // TODO : FIX THIS
	  var openConn = (currentCalls === 0) || forceCall || (msgsToSend.length>0);
	  //console.log("currentCalls=",currentCalls,"forceCall=",forceCall,"msgs",msgsToSend.length,"open=",openConn);
	  if (openConn) {

	    forceCall=false;
	    currentCalls++;

            // NOTE: we rely on 'splice' being an atomic operation
	    var msgs = msgsToSend.splice(0,Math.max(msgsToSend.length,100));
	    var data = {namespace:Address.addr,messages:$.toJSON(msgs)};

	    // ?TODO: in case of error, retry sending messages
	    function error(req,textStatus,errorThrown) {
	      received();
	      bads++;
	      console.log("BADS:",bads);
	      console.log("error",req,textStatus,errorThrown);
	    };

	    // TODO: use POST when on same domain
	    // NOTE: timeout must be > maxAllowedHoldingTime
	    jcall({url: netURL+"deliver",data:data,success:success,error: error,timeout:45000});

	  }

	  // Keep going
	  setTimeout(deliver,1000); // TODO: fine tune.
	}


   /** Broker API **/

      // sendQuery
      function sendQ(queryType,params) {
	var pars = $.extend({timeout:11000},params);
	var ch = newEndPoint(pars.success);
	send("/dns/org/quicquid/broker",a(queryType,[pars.query,ch]));
	return ch;
      }

      function answer(pars) {
	return sendQ("answer",pars);
      }


   /**
       Register a new persistent query.

       The parameters are passed as an object with the following properties:

       query:: String
       A query, composed by one or more predicates.
       Example: FIX: "match(?X 'IBM') type(?X ?T) name(?T ?TN) name(?X ?N)"

       success::Function(bindings::Object)
       Call back, invoked every time a solution is found.
       Example: k({o:"/freebase.com/en/ibm",name:"International Business Machines"})

       error::
       Thrown if the request is not accepted (e.g. because the parameters are invalid).
       NOT thrown if there are simply no results.

       Returns: a 'connection handle' that can be used to remove the query.

       Example: $.quicquid.ask({query:"and[match[?X,IBM] ,type[?X,?T] ,name[?T,?TN] ,name[?X,?N]]",success:success,error:error,timeout:1000});
       **/
      function ask(pars) {
	return sendQ("ask",pars);
      }


   /*
    * Keep a query running till any of the specified conditions are satisfied and then return all the received answers.
    * minHits, the minimum number of hits required.
    * timeout, the longest time we are willing to wait for an answer.
    * TODO: support generic complete() function
    */
   function askTill(params) {
     //var pars = $.extend({timeout:10000,minHits:10},params);
     var pars = $.extend({minHits:1},params);

     var data = [];
     function k(msg) {
       data.push(msg);
       if (data.length >= pars.minHits) complete();
     }

     var ch = ask({query:pars.query,success:k});

     var done = false;
     function complete () {
       // Avoid to call the callback twice
       if (done) return;

       // TODO: close(ch);
       done=true;
       pars.success(data);
     }

     if (isDefined(pars.timeout)) setTimeout(complete, pars.timeout);
    }


    function jcall(params) {
     // NOTE: beforeSend is not used for GET requests
     var pars = $.extend({global: false,dataType: "jsonp",beforeSend: function(oXhr) {oXhr.setRequestHeader('Connection', 'Keep-Alive');}},params);

     var ok = params.success;
     var bad = params.error;
     var done = false;
     pars.success = function(data, textStatus) {
	 if (done) return;
	 done=true;
	 ok(data, textStatus);
     };
     // NOTE: parameters won't be set in case of a timeout
     pars.error = function(req,textStatus,errorThrown) {
         if (done) return;
         done=true;
	 bad(req,textStatus,errorThrown);
     };

     jqueryAjax(pars);

      if (isDefined(params.timeout)) setTimeout(pars.error,params.timeout);
   };


   // Start the protocol
   var running = false;
   function start () {
     //eventHandler=handler;
     if (running) return;
     else {
       running=true;
       console.log("QuicQuid Started");

       function success(data, textStatus) {
	 Address.setAddr(data);
	 deliver();
       };

       function error(req,textStatus,errorThrown) {
	  alert("I cannot connect to QuicQuid.\n\nTry to reload this page in a few minutes.");
	};

       // Get namespace
       jcall({url: netURL+"namespace",data:{},success:success,error:error,timeout:15000});
     }
   }

   function bind(evt,handler) {
     $(document).bind(evt,handler);
   }

   function unbind(evt,handler) {
     $(document).unbind(evt,handler);
   }

   // External API
   $.quicquid = {start:start,bind:bind,unbind:unbind,newEndPoint:newEndPoint,delEndPoint:delEndPoint,send:send,ask:ask,askTill:askTill,answer:answer,a:a,v:v,q:q};

   //console.log("QUICQUID RELOADED");

 })(jQuery);
