// A Simplified Tree View

Ext.namespace('org.quicquid');

org.quicquid.TreeView = function(config) {
    org.quicquid.TreeView.superclass.constructor.call(this, config);
    Ext.apply(this,config);

    // Adjust width
    this.width = this.columns.reduce(function(tot,c) {
				       return tot+c.width;
				     }
				     ,0)+2;
    

    this.tree = new Ext.tree.ColumnTree({
      el : this.element
	  ,width: this.width
	  ,autoHeight:true
	  ,rootVisible:true
	  ,autoScroll:true
	  ,title:this.title
	  ,columns:this.columns
      ,root: this.distr  
	  });    
};

org.quicquid.TreeView.makeTree = function(children) {
  return org.quicquid.TreeView.makeTree2(new Ext.tree.TreeNode({expanded:true}),children);
};

org.quicquid.TreeView.makeTree2 = function(root,children) {
  for (var i=0;i<children.length;i++) {
    var ch = children[i];
    
    ch.uiProvider=Ext.tree.ColumnNodeUI;
    ch.hrefTarget="_blank";
    
    var n;
    if (ch.children) {
      ch.expanded=true;
      ch.singleClickExpand=true;
      n = new Ext.tree.TreeNode(ch);      
      org.quicquid.TreeView.makeTree2(n,ch.children);
      //n.loaded=true;
    } else {
      ch.leaf=true;
      n = new Ext.tree.TreeNode(ch);
    }
    root.appendChild(n);
  }

  return root;
};


Ext.extend(org.quicquid.TreeView,Object, {
  render:function() {this.tree.render();}
  });
