var Stock = function(config) {Ext.apply(this,config);};

Stock.prototype.as = function(currency) {
  var q = this.quote ? this.quote : Stock.quote(this.googleId);
  return q.as(currency)*this.units;
};

Stock.prototype.link = function() {
    return this.url || (this.googleId ? "http://finance.google.co.uk/finance?q="+encodeURIComponent(this.googleId) : undefined);
};

Stock.values = {"EUREUR":"€1"};

Stock.quote = function(id) {return org.quicquid.Type.str2obj(Stock.values[id]);}

Stock.loadQuotes = function(data) {
		var stocks = data.feed.entry;
		function mkQuote(vals,stk) {
		  console.dir(stk);
		    var v = stk.content.$t.split(":")[1].split(",")[0].trim();
		    if  (v!="#N/A") vals[stk.title.$t] = v;
		    return vals;
		};
		Stock.values = stocks.reduce(mkQuote,Stock.values);
};
