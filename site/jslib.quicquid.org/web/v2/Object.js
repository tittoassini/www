function obj2str(obj) {
    var val, output = "";
    
    output += "{";
    
    for (var i in obj) {
	val = obj[i];
	switch (typeof val) {
	case ("object"):
	    if (typeof val.length != "undefined") {
		output += i + ":" + Array.array2str(val) + ",";
	    } else {
		output += i + ":" + obj2str(val) + ",";
	    }
	    break;
	case ("string"):
	    output += i + ":'" + escape(val) + "',";
	    break;
	default:
	    output += i + ":" + val + ",";
	}
    }
    
    output = output.substring(0, output.length-1) + "}";
    return output;
};
 

/*   
Object.prototype.fromString = function(str) {
    eval("var result = " + str);
    return result;
};
*/
