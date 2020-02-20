$(document).ready(function(){

  module("Module Router");

  var r = $.quicquid;
  r.start();

  function isEmpty(v,allowBlank){return v===null || v===undefined || (!allowBlank?v==="":false);}

  function objEq(a, b) {
	var ret = true;

	if ( a && b ) {
		for ( var i in a )
			if ( a[i] != b[i] )
				ret = false;

		for ( i in b )
			if ( a[i] != b[i] )
				ret = false;
	} else
		ret = false;
    return ret;
  };

  function arrOfObjEq(a,b) {
    if ( a && b && a.length != undefined && a.length == b.length ) {
      for ( var i = 0; i < a.length; i++ )
	if (! objEq(a[i],b[i])) return false;
      return true;
    };
    return false;
  };

  test("Server survival",function() {
      expect(1);

      // Try to bring server down
      srv({callback:"f"});
      srv({callback:"f",messages:"["});
      srv({callback:"f",messages:"[",namespace:"XXX"});

      function srv(data) {
	$.ajax({
        global: false
	,url: "http://127.0.0.1:8080/api/deliver"
	,dataType: "jsonp"
	,beforeSend: function(oXhr) {oXhr.setRequestHeader('Connection', 'Keep-Alive');}
	,data: data
	,success: function () {}
	//,error:error
	//,timeout: 2000
	});
	}

      r.ask({query:r.q("random (integer ?R)"),success:function(){ok(true,"server is running");},timeout:3000});
      stop();setTimeout(start,3000);
    });

  test("Test create/delete endpoints", function() {
    var ch1 = r.newEndPoint(function(){});
    ok(r.delEndPoint(ch1),"delete end point");
    ok(! r.delEndPoint(ch1),"delete already-deleted endpoint");
    ok(! r.delEndPoint("random"),"delete non existent endpoint");
  });


  test("Test sending local messages", function() {

    var numTests = 100;
    expect(numTests);

    var doneTests=0;
    function received() {
      if (++doneTests==numTests) {console.timeEnd(t);start();}
    };

    function msg(dest) {
      return {msg:"hi there!",from:dest};
    };

    function handler(rmsg,i) {
	received();
	//console.log("Received",rmsg,"Expected",msg(i));
	isObj(rmsg,msg(i),"received correct message");
    };

    var t = "Sending time";
    console.time(t);

    for (var i=0;i<numTests;i++) {
      var m = msg(i);
      var ch = r.newEndPoint(eval("(function(rmsg){handler(rmsg,"+i+")})"));
      r.send(ch,m);
    };

    stop();
    setTimeout(start, numTests*10 + 2000);
  });



/*
    test("Test remote 'ask'", function() {

	   testAsk("random (integer ?Randy)",[{Randy:}]
      expect(1);

    //?? when is this used?
    function error() {
      ok(false,"no errors received");
    };

    var c=0;
    function askK(rmsg) {
      console.log("askK",rmsg);
      var ans=[{N:"Inter Bus Mach",T:"/en/company",TN:"Company",X:"/en/ibm"},{N:"Inter Bus Mach",T:"/en/thing",TN:"A Thing",X:"/en/ibm"}];
      isObj(rmsg,ans[c++],"received correct ask result");
    };

    r.ask({query:query1,success:askK,error:error,timeout:1000});

    stop();setTimeout(start,3000);
    });


    var query1 = r.q('and[match[?X,IBM],type[?X,?T],name[?T,?TN],name[?X,?N]]');

    test("Test remote 'ask' with multiple results", function() {
    expect(2);

    //?? when is this used?
    function error() {
      ok(false,"no errors received");
    };

    var c=0;
    function askK(rmsg) {
      console.log("askK",rmsg);
      var ans=[{N:"Inter Bus Mach",T:"/en/company",TN:"Company",X:"/en/ibm"},{N:"Inter Bus Mach",T:"/en/thing",TN:"A Thing",X:"/en/ibm"}];
      isObj(rmsg,ans[c++],"received correct ask result");
    };

    r.ask({query:query1,success:askK,error:error,timeout:1000});

    stop();setTimeout(start,3000);
    });



    test("Test 'askTill'", function() {
    expect(1);

    function askTillK(rmsgs) {
      console.log(rmsgs);
      var ans=[{N:"Inter Bus Mach",T:"/en/company",TN:"Company",X:"/en/ibm"},{N:"Inter Bus Mach",T:"/en/thing",TN:"A Thing",X:"/en/ibm"}];
      ok(arrOfObjEq(rmsgs,ans),"received correct askTill result!");
    };

    r.askTill({query:query1,success:askTillK,timeout:1000});

    stop();setTimeout(start,3000);
    });
*/


  /*
  test("Test 'answer' with echo agent", function() {
    expect(1);

    function m(i) {
      return i + " " + i;
    };

    function answerK(rmsg) {
      console.log("echo test received",rmsg);

      var i  = rmsg[0]['in'];
      var o  = rmsg[0]['out'].name; // The name of the variable to return
      var ch = rmsg[1]; // The end point to which the answer should be forwarded

      var reply = {};
      reply[o]= m(i);
      r.send(ch,reply);
    };

    r.answer({query:r.a("echo",[r.v("in"),r.v("out")]),success:answerK});

    //var txt = "text to send";
    var txt = "text=æéêø  一個勁";
    function askSuccess(rmsg) {
      console.log("askSuccess",rmsg,txt);
      isObj(rmsg,{r:m(txt)},"received correct answer result");
    };


    r.ask({query:r.a("echo",[txt,r.v("r")]),success:askSuccess});

    stop();setTimeout(start,5000);
    });


  test("Test 'answer' with numeric argument", function() {
    expect(1);

    function handler(rmsg) {
      console.log(rmsg);

      var f  = $.trim(rmsg[0].formula);
      var v  = rmsg[0].value.name; // The name of the variable to return
      var ch = rmsg[1]; // The end point to which the answer should be forwarded

      try {
	var val = eval(f);
	if (! isEmpty(val) && val.toString()!=f) {
	  var reply = {};
	  reply[v] = val;
	  r.send(ch,reply);
	};
      } catch (e) {}
    };

    r.answer({query:r.q("calc[?formula,?value]"),success:handler});

    function success(rmsg) {
      console.log(rmsg);
      isObj(rmsg,{r:8},"received correct answer result");
    };
    r.ask({query:r.q('calc["3+5",?r]'),success:success});

    stop();setTimeout(start,5000);
    });
      */

    // Exercise support for javascript agents development
    // Publish a javascript module
    // Publish another versions of the same module
    // Search for a module
    // Load a module
    // and test that it works locally

});

