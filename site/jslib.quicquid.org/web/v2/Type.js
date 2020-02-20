/** Object and Types **/

Ext.namespace('org.quicquid');

org.quicquid.Type = function () {

  function mkType(type,value) {return {_type:type,_value:value};};

  function getType(o) {return o._type;}
  function getValue(o) {return o._value;}

  function expand2obj(e) {
    var o = expand(e);

    if (Ext.type(o)=="array")  return o.map(expand2obj);

    if (Ext.type(o)=="object") {
      for (var p in o)
		o[p] = toObj(o[p]);
      return o;
    }

    throw new Error("Cannot expand " + o);
  }

  function str2obj(inp) {return toObj(parseType(inp));}

  function toObj(t) {
      switch(t._type) {
      case "/type/string":
      case "/type/number": return t._value;
      case "/type/number/percent": return t._value/100;
      case "/type/number/currency/eur": return Money.eur(t._value);
      case "/type/number/currency/gbp": return Money.gbp(t._value);
      case "/type/number/currency/usd": return Money.usd(t._value);
      default: throw new Error("Unknown typed object "+t._type+" "+t._value);
      };
    };

  function expand(o) {
    if (Ext.type(o)=="array")  return o.map(expand);
    if (Ext.type(o)=="string") return parseType(o);
    if (Ext.type(o)=="number") return mkType("/type/number",o);
    if (Ext.type(o)=="object") return exObj(o);

    throw new Error("Cannot expand " + o);
  };

  function exObj(o) {
    //BUG
    if (o._ && o.__) throw new Error("An obj can have only _ or __");

    if (o._) {
      var e = o._;
      delete o._;
      o = extend([e,o]);
    }

    for (var p in o)
      if (p.charAt(0)!="_")
	o[p] = expand(o[p]);

    return o;
  };

  function extend(arr) {
    function join(base,o) {return Ext.apply(base,o);}

    return arr.map(expand).reduce(join,{});
  };

  function parseType(inp) {
    var float = "(([+-]?\\d+(\\.\\d*)?)|([+-]?(\\d*\\.)?\\d+))";

    function tr(pat) {return "^\\s*"+pat+"\\s*$"};

    var parsers = [
		   function(s) {
		     var m = s.match(tr("£\\s*"+float));
		     if (m==null) return null;
		     return mkType("/type/number/currency/gbp",parseFloat(m[1]));
		   }
		   ,function(s) {
		     var m = s.match(tr("\\$\\s*"+float));
		     if (m==null) return null;
		     return mkType("/type/number/currency/usd",parseFloat(m[1]));
		   }
		   ,function(s) {
		     var m = s.match(tr("€\\s*"+float));
		     if (m==null) return null;
		     return mkType("/type/number/currency/eur",parseFloat(m[1]));
		   }
		   ,function(s) {
		     var m = s.match(tr(float+"\\s*%"));
		     if (m==null) return null;
		     return mkType("/type/number/percent",parseFloat(m[1]));
		   }
		   ,function (s) {
		     var m = s.match(tr("(mailto\\:)?(.+@.+\\..+)"));
		     if (m==null) return null;
		     return mkType("/type/string/emailAddress",m[2]);
		   }
		   ];

    for (var i=0;i<parsers.length;i++) {
      var r = parsers[i](inp);
      if (r) return r;
    }

    return mkType("/type/string",inp);

    //throw new Error("Unparsable value '" + inp + "'");
  };

  // Public Methods
  return {expand2obj:expand2obj,expand:expand,parseType:parseType,getType:getType,getValue:getValue,toObj:toObj,str2obj:str2obj};

}();




