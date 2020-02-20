/** 
Document Database 

Each document has one (todo: or more) context(s):
/language/chinese/course/chinesePod/level/newbie/55
/language/chinese/course/chinesePod/lesson/55
/md5/3435254545454
/type/language/haskell/module/literate
/content/utf/...content...

/language = or =!= /language/ ?


A document is returned as a:
-- set of known contexts/ids
-- content: an unicode string (todo: or a binary)

Views (tree nodes, editable docs, tabs) hold references and subscribe to events in the item.
**/

Ext.namespace('org.quicquid.db');

org.quicquid.db.Gears = function(config) {
    Ext.apply(this, config);
    if (Ext.isEmpty(this.databaseName)) throw new Error("org.quicquid.db.Gears: missing 'databaseName' parameter.");

    this.db = google.gears.factory.create('beta.database', '1.0');
    this.db.open(this.databaseName);

    this.create();

    org.quicquid.db.Gears.superclass.constructor.call(this);
};

Ext.extend(org.quicquid.db.Gears, Ext.util.Observable, { 
     reset: function() {
        this.db.execute('DROP TABLE IF EXISTS docs');
        this.create();
    }

    ,create: function() {
        this.db.execute('CREATE TABLE IF NOT EXISTS docs (type,context,name,content,PRIMARY KEY (context,name))');
    }

    ,split: function(path) {
        var parts = path.split('/');
        var name  = parts.pop();
        var context = parts.join('/')+'/';
        return {name:name,context:context};
    }

    ,add : function(type,path,content) {
        var nc = this.split(path);
        this.db.execute('INSERT INTO docs VALUES (?,?,?,?)',[type,nc.context,nc.name,content]);
    }

    ,updateItem : function(item) {
        this.db.execute('INSERT OR REPLACE INTO docs VALUES (?,?,?,?)',[item.getType(),item.getContext(),item.getName(),item.getContent()]);
    }  

   ,getItem : function(path) {
         var nc = this.split(path);
        return this.rows2items(this.db.execute('SELECT * FROM docs WHERE context=? AND name=?',[nc.context,nc.name]))[0];
   }

   ,getContextItems : function(ctxt) { 
        var context = ctxt[ctxt.length-1] == '/' ? ctxt : ctxt + '/';
        return this.rows2items(this.db.execute('SELECT * FROM docs WHERE context=?',[context]));                  
    }

    ,rows2items : function(rs) {
           var os = [];
           try {
	    while (rs.isValidRow()) {              
              os.push(org.quicquid.db.Item.getInstance({db:this,type:rs.fieldByName('type'),context:rs.fieldByName('context'),name:rs.fieldByName('name'),content:rs.fieldByName('content')}));
              rs.next();       
            };
            return os;
          } catch(e) {
             throw e; 
          } finally {
             rs.close();
	  };                     
    }

});

org.quicquid.db.Item = function(config) {
    Ext.apply(this, config);
    org.quicquid.db.Item.superclass.constructor.call(this);
};

Ext.extend(org.quicquid.db.Item, Ext.util.Observable, { 
    getType    : function() {return this.type;}
   ,getPath    : function() {return this.context + this.name;}
   ,getContext : function() {return this.context;}
   ,getName    : function() {return this.name;}
   ,getContent : function() {return this.content;} 
   ,setContent : function(content) {
       this.content = content;
       this.db.updateItem(this);
   } 
});

org.quicquid.db.Item.getInstance = function(config) {
  var tid = config.context + config.name
  var i = this.items[tid];
  if (i) {
    // todo: update if values have changed.
    //i.setDb(config.db);
    //i.setType(config.type);
    //i.setContent(config.content);
  } else {
    i = new org.quicquid.db.Item(config);
    this.items[tid]=i;    
  }
  return i;  
}

org.quicquid.db.Item.items = {}



Ext.data.Node.prototype.getTermPath = function() {return this.attributes.tid;}


org.quicquid.db.TreeLoader = function(config) {
    this.baseAttrs = {}; 
    Ext.apply(this, config);

    this.initDB();

    this.addEvents("beforeload","load","loadexception");

    org.quicquid.db.TreeLoader.superclass.constructor.call(this);
};

Ext.extend(org.quicquid.db.TreeLoader, Ext.util.Observable, { 
     uiProviders : {}
    ,clearOnLoad : true
 
   ,initDB : function() {
     this.db.reset();
     this.db.add('/term'      ,'/language'                 ,'A language: human or otherwise.');
     this.db.add('/term'      ,'/language/haskell'         ,'The Haskell language.');
     this.db.add('/term'      ,'/language/haskell/module'  ,'An Haskell module: plain or literal.');
     this.db.add('/language/haskell/package'      ,'/language/haskell/module/Data'         ,'A namespace for data');
     this.db.add('/language/haskell/module/plain' ,'/language/haskell/module/Data/Example' ,'module Data.Example where\n double = (2*)');
     this.db.add('/language/haskell/package'      ,'/language/haskell/module/System'       ,'System functions');
   }

   ,load : function(node, callback) {

        if (this.clearOnLoad) 
            while(node.firstChild) node.removeChild(node.firstChild);

        if (this.fireEvent("beforeload", this, node, callback) !== false)
          try {
            var items = this.db.getContextItems(node.getTermPath());

            node.beginUpdate();               
	    for (var i=0;i<items.length;i++) {
              var n = this.createNode(this.item2node(items[i]));
              if(n) node.appendChild(n);
            };
            node.endUpdate();
    
            this.fireEvent("load", this, node);
          } catch(e) {
             this.fireEvent("loadexception", this, node);
             throw e;
          }

        this.cb(callback,node);
    }

    ,createNode : function(attr){        
        if(this.baseAttrs) Ext.applyIf(attr,this.baseAttrs);

        if(this.applyLoader !== false) attr.loader = this;

        if(typeof attr.uiProvider == 'string') 
           attr.uiProvider = this.uiProviders[attr.uiProvider] || eval(attr.uiProvider);

        return(attr.leaf ?
                        new Ext.tree.TreeNode(attr) :
                        new Ext.tree.AsyncTreeNode(attr));
    }

    ,cb : function(callback,obj) {if(typeof callback == "function") callback(obj);}     

});







