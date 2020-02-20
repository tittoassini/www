String.prototype.endsWith = function(str) {return (this.slice(-str.length)==str)}

/*
String.prototype.isPrefix = function(str) {
  return (this.length<=str.length) && (str.slice(0,this.length)==this);
}

String.prototype.between = function(from,to) {
  var f = this.indexOf(from);
  var t = this.indexOf(to);
  if (f==-1 || t ==-1) return "";
  return this.slice(f+from.length,t);
}
*/
