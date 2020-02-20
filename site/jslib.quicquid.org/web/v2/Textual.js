/** 
Simple store of textual entries. 

See also db.js
**/

Ext.namespace('org.quicquid.db');

org.quicquid.db.Textual = function(config) {

    Ext.apply(this, config);
    if (Ext.isEmpty(this.databaseName)) 
    		throw new Error("org.quicquid.db.Textual: missing 'databaseName' parameter: " + config.toString());

    var db = google.gears.factory.create('beta.database', '1.0');
    db.open(this.databaseName);
    try {
    	  //db.execute('DROP TABLE docs');
    	  db.execute('CREATE VIRTUAL TABLE docs USING fts2(content)');
    	} catch (e) {
    	  if (e.message.indexOf("table docs already exists")==-1) throw e; 
    };
    	
    this.add = function (content) {
        if (db.execute('SELECT content FROM docs WHERE content=?',[content]).isValidRow()) return false;
        
        db.execute('INSERT OR REPLACE INTO docs(content) VALUES (?)',[content]);
        return true;
    };

    this.del = function (content) {
        try {db.execute('DELETE FROM docs WHERE content=?',[content]);} catch (e) {return false;}
        return true;        
    };

	this.search = function (content) {
	    var out = db.execute('SELECT content FROM docs WHERE content MATCH ?',[content]);
        return rows2items(out);
   	};   

    function rows2items(rs) {
		var os = [];
        try {
	    	while (rs.isValidRow()) {              
              os.push(rs.fieldByName('content'));
              rs.next();       
            };
            return os;
          } catch(e) {
             throw e; 
          } finally {
             rs.close();
	 	};                     
    };
};
