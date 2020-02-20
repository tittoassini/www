if (!Array.prototype.filter)
{
  Array.prototype.filter = function(fun /*, thisp*/)
  {
    var len = this.length;
    if (typeof fun != "function")
      throw new TypeError();

    var res = new Array();
    var thisp = arguments[1];
    for (var i = 0; i < len; i++)
    {
      if (i in this)
      {
        var val = this[i]; // in case fun mutates this
        if (fun.call(thisp, val, i, this))
          res.push(val);
      }
    }

    return res;
  };
}

if (!Array.prototype.map)
{
  Array.prototype.map = function(fun /*, thisp*/)
  {
    var len = this.length;
    if (typeof fun != "function")
      throw new TypeError();

    var res = new Array(len);
    var thisp = arguments[1];
    for (var i = 0; i < len; i++)
    {
      if (i in this)
        res[i] = fun.call(thisp, this[i], i, this);
    }

    return res;
  };
}

if (!Array.prototype.reduce)
{
  Array.prototype.reduce = function(fun /*, initial*/)
  {
    var len = this.length;
    if (typeof fun != "function")
      throw new TypeError();

    // no value to return if no initial value and an empty array
    if (len == 0 && arguments.length == 1)
      throw new TypeError();

    var i = 0;
    if (arguments.length >= 2)
    {
      var rv = arguments[1];
    }
    else
    {
      do
      {
        if (i in this)
        {
          rv = this[i++];
          break;
        }

        // if array contains no values, no initial value to return
        if (++i >= len)
          throw new TypeError();
      }
      while (true);
    }

    for (; i < len; i++)
    {
      if (i in this)
        rv = fun.call(null, rv, this[i], i, this);
    }

    return rv;
  };
}


Array.prototype.reduceRecurse = function(fun, initial,childrenProp)
  {
    var len = this.length;

    if (typeof fun != "function")
      throw new TypeError();

    if (arguments.length < 3)
      throw new TypeError();

    var res = this.reduce(fun,initial);

    for (var i=0; i<len; i++) {
      var ch = this[i][childrenProp];

      if (ch) res = ch.reduceRecurse(fun,res,childrenProp);
    }

    return res;
  };

Array.prototype.sum = function() {
  return this.reduce(function(tot,v) {return tot+v},0);
};

Array.prototype.any = function(fun) {

    if (arguments.length < 1)
      throw new TypeError();

    if (typeof fun != "function")
      throw new TypeError();

    for (var i=0; i<this.length; i++)
	if (fun(this[i])) return true;

    return false;
};

Array.prototype.all = function(fun) {

    if (arguments.length < 1)
      throw new TypeError();

    if (typeof fun != "function")
      throw new TypeError();

    for (var i=0; i<this.length; i++)
	if (! fun(this[i])) return false;

    return true;
};

/*
Array.prototype.toString = function() {
    var output = "";
    output += "[";
    for (var i=0; i<arr.length;i++) {
      var val = arr[i];
      switch (typeof val) {
	case ("object"):
          if (typeof val.length != "undefined") {
            output += val.toString() + ",";
          } else {
            output += val.toString() + ",";
          }
                    break;
                case ("string"):
                    output += "'" + escape(val) + "',";
                    break;
                default:
                    output += val + ",";
            }
        }
        output = output.substring(0, output.length-1) + "]";
    return output;
}*/


Array.prototype.fromString = function (str) {
    eval("var result = " + str);
    return result;
};


