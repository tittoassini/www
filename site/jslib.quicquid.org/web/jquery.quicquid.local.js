/*global jQuery */
/*jslint browser:true, nomen: true, laxbreak:true */
/*
 * Local version of the quicquid API, implements a broker/router directly in JavaScript.
 *
 * TODO: might use promises rather than callbacks, as in Robust Composition,
 *  see http://waterken.sourceforge.net/, http://waterken.sourceforge.net/web_send/
 */
(function($) {

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

   /** Local Broker/Router **/
   var asks = [];
   var answers = [];

   function connect(answer,ask,bindings) {
     setTimeout(function() {answer.success([bindings,function (bs) {setTimeout(function(){ask.success(bs)},0);}]);},0);
   };

   function chk(o) {
     if (o && o.success && $.isFunction(o.success) && o.query) return;
     throw new Error("Invalid parameters.");
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
    * Queries that match the 'from' pattern are rewritten to the 'to' pattern.
    */
   function redirectAsk(from,to) {
     answer({query:from,success:function(bs){
       console.log("redirectAsk",from,to);
       var bindings = bs[0];
       var k = bs[1];
       ask({query:substitute(bindings,to),success:function(bs){
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

   // External API
   $.quicquid = {ask:ask,answer:answer,redirectAsk:redirectAsk,substitute:substitute,a:a,v:v};


 })(jQuery);


