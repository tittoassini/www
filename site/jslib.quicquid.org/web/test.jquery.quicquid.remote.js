(function($){

   module("QuicQuid API");

   var qq = $.quicquid;

   // Utils
   function asStr(o) {
     //if (o.toJSON) return o.toJSON();
     return $.toJSON(o);//return jsDump.parse(o);
   };

   // Sample agents
   function randomAgent(bs) {
     console.log("randomAgent",bs);
     var bindings  = bs[0];
     var k = bs[1];
     var msg = {};
     msg[bindings.r]=345;
     k(msg);
   };
   qq.answer({query:qq.a("random",qq.a("variable",qq.v("r"))),success:randomAgent});

   function randomAgent2(bs) {
     console.log("randomAgent2",bs);
     var bindings  = bs[0];
     var k = bs[1];
     var msg = {};
     msg[bindings.r.name]=123;
     k(msg);
   };
   qq.answer({query:qq.a("random2",qq.v("r")),success:randomAgent2});

   function lenAgent(bs) {
     console.log("lenAgent",bs);
     var bindings = bs[0];
     var k = bs[1];
     var msg = {};
     msg[bindings.r.name]=bindings.s.length;
     k(msg);
   };
   qq.answer({query:qq.a("org",qq.a("quicquid",qq.a("len",[qq.v("s"),qq.v("r")]))),success:lenAgent});

   function ctest(ask,result) {
     test(ask.toJSON() + " -> " + asStr(result),function () {
     expect(1);
     qq.ask({query:ask,success:function(bindings) {
       console.log("ctest",bindings);
       same(bindings,result);//,"expected: "+asStr(result)+" actual: " + asStr(bindings));
       start();
     }});
     stop(5000);
     });
   };

   function ctestE(ask,result) {
     test(ask.toJSON() + " -> " + asStr(result),function () {
	    expect(1);
	    qq.askE(ask).mapE(function(bindings) {
				console.log("ctestE",bindings);
				same(bindings,result);//,"expected: "+asStr(result)+" actual: " + asStr(bindings));
				start();
			      });
	    stop(5000);
	  });
   };


     /*
   function ctest(ask,result) {
     console.log(ask.toJSON() + " -> " + asStr(result));
     qq.ask({query:ask,success:function(bindings) {
       console.log("ctest",bindings);
     }});
   };*/

   function tmatch(ask,answer,expected) {
     test("match " + asStr(ask) + " with " + asStr(answer),function() {
       expect(1);
       qq.ask({query:ask,success:function(){}});
       qq.answer({query:answer,success:function(bs) {
	 console.log("tmatch answer",bs);
	 same(bs[0],expected);
	 start();
       }});
       stop(1000);
     });
   };


   // Tests
   function sub(bindings,pattern,expected) {
     test("substitute", function() {
       same(qq.substitute(bindings,pattern),expected);
     });
   };

   sub({X:3,y:4},qq.a(qq.v("X"),qq.v("y")),qq.a(3,4));
   sub({X:3,Y:4},qq.v("X"),3);
   sub({X:3,Y:4},[1,2,qq.v("X"),qq.v("Y")],[1,2,3,4]);
   sub({X:'xx',y:4},{a:qq.v("X"),c:17},{a:'xx',c:17});
   sub({X:3,xyz:4},"abc","abc");

   tmatch(qq.a("triple",["ab",33,"cd"]),qq.a("triple",[qq.v("one"),33,qq.v("three")]),{ "one": "ab", "three": "cd" });
   tmatch({type:"text/plain",content:qq.v("txt"),author:"titto"},{type:qq.v("type"),content:qq.v("t"),author:"titto"},{type:"text/plain",t:qq.v("txt")});

   ctestE(qq.a("random",qq.v("y")),{"y":345});
   ctestE(qq.a("random2",qq.v("x")),{"x":123});

   test("redirectAsk", function() {
     qq.redirectAsk (qq.a("safe",qq.a("len",[qq.v("X"),qq.v("Y")]))
		     ,qq
		     ,qq.a("org",qq.a("quicquid",qq.a("len",[qq.v("X"),qq.v("Y")]))));

     expect(1);stop(1000);
       qq.ask({query:qq.a("safe",qq.a("len",["abcd",qq.v("X")])),success:function(bs){
       equals(bs.X,4);
       start();
     }});
   });


   qq.redirectAsk(qq.a("local",qq.v("Z")),qq,qq.v("Z"));
   ctest(qq.a("local",qq.a("random",qq.v("y"))),{"y":345});


   var url = "http://code.quicquid.org/api/";
   //var url;
   qq.redirectAsk(qq.a("global",qq.v("Z")),qq.remote(url),qq.v("Z"));
   ctest(qq.a("global",qq.a(qq.a("parse","baba \"bobo\""),qq.v("x"))),{"x":qq.a("baba","bobo")});

   ctest(qq.a("global",qq.a(qq.a("parse","pup [pap]"),qq.v("x"))),{"x":qq.a("pup",["pap"])});
   var unitxt1 = "æéêø";
   var unitxt2 = "一個勁";
   ctest(qq.a("global",qq.a(qq.a("parse",unitxt1+ "   " +unitxt2),qq.v("xyz"))),{"xyz":qq.a(unitxt1,unitxt2)});

   //function rAsk(query) {
   //  qq.remote.ask({query:qq.a("global",qq.a(qq.a("parse","baba \"bobo\""),qq.v("x"))),success:function(bs) {console.log(bs);}})

})(jQuery);



