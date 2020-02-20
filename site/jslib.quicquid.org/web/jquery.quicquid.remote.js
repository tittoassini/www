/* global jQuery */
/* jslint browser:true, nomen: true, laxbreak:true */
/*
* Quicquid API, implements a broker/router directly in JavaScript.
*
* TODO: might use promises rather than callbacks, as in Robust Composition,
*  see http://waterken.sourceforge.net/, http://waterken.sourceforge.net/web_send/
* or events as in flapjax.
* BUG: if connection is lost keep pestering the server wasting a lot of cpu time.
*/
(function($) {
  
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
  
  /* TODO: add parser
  // Code already in QuicQuid format, to be quoted verbatim.
  function Q(q) {
  this.q=q;
}
  Q.prototype.toJSON = function() {return this.q;};
  function q(term) {
  return new Q(term);
}*/
  
  /** Local Broker/Router **/
  var asks = [];
  var answers = [];
  
  function connect(answer,ask,bindings) {
    console.log("CONNECT",answer,ask,bindings);
    setTimeout(function() {
      answer.success([bindings,
                      function (bs) {setTimeout(function(){ask.success(bs);},0);}]);},0);
  };
  
  /**
  * We expect a parameters object with properties:
  * success :: Function, the success callback.
  * query   :: Term    , the query.
  */
  function chk(o) {
    if (o && o.success && $.isFunction(o.success) && o.query) return;
    console.dir(o);
    throw new Error("Invalid ask/answer parameter.");
  };
  
  // TODO : no removal, no timeouts, inefficient.
  function answer(answer) {
    chk(answer);
    answers.push(answer);
    $.each(asks,function(k,ask) {
      var bindings = unify({},answer.query,ask.query);
      if (bindings) connect(answer,ask,bindings);
    });
  };
  
  function ask(ask) {
    chk(ask);
    asks.push(ask);
    $.each(answers,function(k,answer) {
      var bindings = unify({},answer.query,ask.query);
      if (bindings) connect(answer,ask,bindings);
    });
  };
  
  /**
  * @param query::Term
  * @return :: EventStream
  */
  function askE(query) {
    var events = receiverE();
    var callback = function(e) {
      console.log("isDetached",events.isDetached);
      events.sendEvent(e);
    };
    ask({query:query,success:callback});
    return events;
  };
  
  /**
  * Queries that match the 'from' pattern are rewritten to the 'to' pattern.
  */
  function redirectAsk(from,toBroker,to) {
    console.log("redirectAsk",from,toBroker,to);
    answer({query:from,success:function(bs){
      var bindings = bs[0];
      var k = bs[1];
      toBroker.ask({query:substitute(bindings,to),success:function(bs){
        k(bs);
      }});
    }});
  };
  
  function substitute(bindings,term) {
    if (term instanceof App) return a(substitute(bindings,term.f),substitute(bindings,term.o));
    
    if (term instanceof Var) return bindings[term.name] ? bindings[term.name] : term;
    
    if ($.isArray(term)) return term.map(function (v) {return substitute(bindings,v);});
    
    if ('object' === typeof term) {
      var o = {};
      $.each(term,function(n,v) {o[n]=substitute(bindings,v);});
      return o;
    }
    
    return term;
  };
  
  function unify(bindings,answer,ask) {
    if (answer instanceof App && ("variable" === answer.f) && ask instanceof Var) {
      return unify(bindings,answer.o,ask.name);
    };
    
    if (answer instanceof App && ask instanceof App) {
      var nbs = unify(bindings,answer.f,ask.f);
      if (nbs) return unify(nbs,answer.o,ask.o);
      return false;
    };
    
    if ($.isArray(answer) && $.isArray(ask)) {
      if (answer.length !== ask.length) return false;
      
      var bs = bindings;
      for (var i=0;i<=answer.length;i++) {
        bs = unify(bs,answer[i],ask[i]);
        if (! bs) return false;
      };
      return bs;
    };
    
    if (answer instanceof Var) {
      var v = bindings[answer.name];
      
      if (v === undefined) {
        bindings[answer.name]=ask;
        return bindings;
      };
      
      return unify(bindings,v,ask);
    };
    
    if ('object' === typeof answer && 'object' === typeof ask) {
      var bs = bindings;
      for (p in answer) {
        if (answer.hasOwnProperty(p)) {
          bs = unify(bs,answer[p],ask[p]);
          if (! bs) return false;
        };
      };
      return bs;
    };
    
    if (answer === ask) return bindings;
    
    return false;
  };
  
  function channel(netURL,process) {
    console.log("channel(netURL="+netURL+","+process+")");
    
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
    };
    
    // BUG: Clients that use libraries that call ajax won't work, a better solution is to patch directly jquery.
    // Client ajax calls have to go through this function.
    // the processing of the results of all ajax calls seems to be queued
    // So: if there is a pending long call to the server, a call to, say freebase, will be performed immediately
    // BUT the result won't be returned before the previous call is completed, possibly long after it.
    var jqueryAjax = $.ajax;
    
    // NOTE: change standard ajax function
    $.ajax = function (pars) {
      console.log("QQ AJAX",pars);
      jqueryAjax(pars);
      forceCall=true;
    };
    
    /* Perform a JSONP call, keep connection open, enforce timeout
    * @param params = {success::Function,error::Function,<timeout::MilliSecs>}
    */
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
      
      // BUG: On the second call ajaxSettings is set to an empty object!!!!
      console.log("ajax pars",pars,$,$.ajaxSettings);
      if (isUndefined($.ajaxSettings.type)) console.error("BAD ",$,$.ajaxSettings);
      jqueryAjax(pars);
      if (isUndefined($.ajaxSettings.type)) console.error("BAD ",$,$.ajaxSettings);
      console.log("Performed call",$.ajaxSettings);
      
      if (isDefined(params.timeout)) setTimeout(pars.error,params.timeout);
    };
    
    // The outgoing messages waiting to be sent.
    var msgsToSend = [];
    
    // NOTE: we assume that push is an atomic operation
    function write1(msg) {msgsToSend.push(msg);}
    
    var currentCalls=0;
    function received(data) {console.log("Received: ",data);--currentCalls;}
    
    var forceCall=false;
    var oks=0,bads=0;
    
    var channelID;
    
    // The main function that take care of connecting to the remote quicquid server, send the outgoing messages and receive new incoming messages.
    function deliver() {
      
      /**
      Receive and deliver messages received from the remote server.
      data: An array of messages.
      */
      function success(data, textStatus) {
        oks++;
        received([data,textStatus]);
        
        if (! (data instanceof Array)) {
          var err = data.message ? data.message : "unknown error";
          console.error("Error received from server: "+err);
          return;
        };
        
        // Convert msgs to terms and pass them to processing function.
        //console.log("received " + data.length + " msgs.");
        for (var i=0;i<data.length;i++) process(json2term(data[i]));
      }
      
      // ?TODO: in case of error, retry sending messages
      function error(req,textStatus,errorThrown) {
        received([req,textStatus,errorThrown]);
        bads++;
        console.log("BADS:",bads);
        console.log("error",req,textStatus,errorThrown);
      };
      
      // TODO : FIX THIS
      var openConn = (currentCalls === 0) || forceCall || (msgsToSend.length>0);
      if (openConn) {
        console.log("currentCalls=",currentCalls,"forceCall="
                    ,forceCall,"msgs",msgsToSend.length,"open=",openConn);
        
        forceCall=false;
        currentCalls++;
        
        // NOTE: we rely on 'splice' being an atomic operation
        var msgs = msgsToSend.splice(0,Math.max(msgsToSend.length,100));
        //var msgs = [];
        console.log("Converting",msgs);
        var data = {namespace:channelID,messages:$.toJSON(msgs)};
        console.log("Converted",$.toJSON(msgs));
        
        // TODO: use POST when on same domain
        // NOTE: timeout must be > maxAllowedHoldingTime
        jcall({url: netURL+"deliver",data:data,success:success,error: error,timeout:45000});
      };
      
      // Keep going
      // TODO: fine tune.
      setTimeout(deliver,50);
    };
    
    // Get namespace
    jcall({url: netURL+"namespace"
           ,data:{}
           ,success:function (data) {
             console.log("Connected to QuicQuid with id:"+data);
             channelID=data;
             setTimeout(deliver,1000);
           }
           ,error:function(req,textStatus,errorThrown) {
             console.error("Cannot connect to QuicQuid");
             //alert("I cannot connect to QuicQuid.\n\nTry to reload this page in a few minutes.");
           }
           ,timeout:15000});
    
    return {write1:write1};
  };
  
  /*
  * The default remote broker, supports ask calls only.
  * PROB: can create multiple channels to the same remote broker.
  * @param url, optional url of the broker entry point.
  * redirectAsk("global ?X",$.quicquid.remote("http://127.0.0.1:8080/api"),"?X")
  */
  function remote(url) {
    var callBacks={};
    
    // Counter used to create unique endpoint/channel identifiers.
    // NOTE: easily guessable.
    var counter=0;
    
    /** Process communication channel messages
    *  Messages format:
    *  (cb bindings) cbID
    *  (call term)   cbID
    **/
    function process(msg) {
      console.log("RECEIVED MSG:",msg);
      var k = msg.f.f;
      if ("cb"==k) {
        var ask = callBacks[msg.o];
        if (isDefined(ask)) {
          console.log("DELIVERING MSG:",$.toJSON(msg.f.o));
          setTimeout(function(){ask.success(msg.f.o)},0);
                               }
                     return;
                     }
                     console.error("Unknown message or missing call back");
          console.dir(msg);
        };
        
        var netURL = url ? url : ((("https:" === document.location.protocol) || ("http:" === document.location.protocol)) ? "http://code.quicquid.org" : "http://127.0.0.1:8080")+"/api/";
        var ch = channel(netURL,process);
        
        function ask(ask) {
          console.log("remote ask",ask);
          chk(ask);
          var cbID = ""+(++counter);
          var msg = a(a("call",ask.query),cbID);
          callBacks[cbID]=ask;
          ch.write1(msg);
        };
        return {ask:ask};
      };
      
      // External API
      $.quicquid = {ask:ask,askE:askE,answer:answer,redirectAsk:redirectAsk,substitute:substitute,a:a,v:v,remote:remote};
      
      
    })(jQuery);
    
    
