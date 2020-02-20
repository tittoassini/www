var Taxonomy = function(config) {
  Ext.apply(this,config);

  function mkNode(domain,name) {
    var o = {domain:domain,hrefTarget:"_blank",expanded:true,singleClickExpand:true,uiProvider:Ext.tree.ColumnNodeUI};

    //o[this.columns[0].dataIndex]=name || id;
    o.kind = name || domain;
    return new Ext.tree.TreeNode(o);
  }

  function addPathN(root,pathN) {

    if (pathN.length==0) return;

    var n = root.findChild("domain",pathN[0]);

    if (!n) {
      n = mkNode(pathN[0]);
      root.appendChild(n);
    }

    addPathN(n,pathN.splice(1));

    return root;
  };

  function addPath(root,path) {
    return addPathN(root,path.split("/"));
  }

  this.tree = this.paths.reduce(addPath,mkNode(undefined,"<b>Total</b>"));

  this.tree.cascade(function(node) {
		      if (node.childNodes.length==0) {
			node.leaf=true;
			node.attributes.value=0;
			node.attributes.targetPercent=0;
		      }
		    });

};

// Example: Taxonomy.currency.classify({items:portfolio,key:"currency",sum:"value"});
Taxonomy.prototype.classify = function(config) {

  function classify(tax,entry) {
    var k = entry[config.key];
    if (!Ext.type(k)) throw new Error("No property "+config.key + " in " + entry.name);

    var v = parseFloat(entry[config.sum]);
    if (!Ext.type(v)) throw new Error("No property "+config.sum + " in " + entry.name);

    var n = tax.findByPath(k);
    if (!Ext.type(n)) throw new Error("Unknown value '"+ k + "' for property '"+config.key + "' in " + entry.name);

    if (! n.attributes.value) n.attributes.value = 0;
    n.attributes.value += v;

    return tax;
  };

  function addTotals(node,key) {
    var v = node.attributes[key];

    if (node.isLeaf()) return v;

    var chTotal = node.childNodes.map(function(n) {return addTotals(n,key)}).sum();

    return node.attributes[key] = v ? v + chTotal : chTotal;

  }

  var distr = config.items.reduce(classify,this).tree;

  var total = addTotals(distr,"value");

  addTotals(distr,"targetPercent");

  // Add percentages
  distr.cascade(function(node) {
		  var a = node.attributes;
		  a.percent = (a.value/total*100).toFixed(1);
		});

  // Add diff between target and current
  distr.cascade(function(node) {
		  var a = node.attributes;
		  a.diff = ((a.targetPercent-a.percent)*total/100).toFixed(0);
		});

  return distr;
};

Taxonomy.prototype.findByPath = function(path) {

  function find(root,pathN) {

    if (pathN.length==0) return root;

    var n = root.findChild("domain",pathN[0]);

    if (!n) return;

    return find(n,pathN.splice(1));
  };

  return find(this.tree,path.split("/"));
};

Taxonomy.prototype.addProp = function(propName,paths) {

  function addP(tax,path) {

    var node = tax.findByPath(path);
    if (!node)
      throw new Error("Unknown path '"+ path);

    node.attributes[propName] = paths[path];
  };

  for (var p in paths) addP(this,p);

  return this;
};

Taxonomy.empty = new Taxonomy({name:"Empty",open:true,paths:[]});

Taxonomy.currency = new Taxonomy({name:"Currency",open:false,paths:["EUR","GBP","USD"]});

Taxonomy.euAssets = new Taxonomy({name:"EU Assets",open:false,paths:
				   [
				    "Cash/EUR","Cash/GBP","Cash/USD"
				    ,"Real Estate/Commercial"
				    ,"Commodities/Ex-Timber"
				    ,"Commodities/Timber/Plum Creek Timber"
				    ,"Commodities/Timber/Rayonier"
				    ,"Equity/Developed/UK"
				    ,"Equity/Developed/USA"
				    ,"Equity/Developed/Eurozone"
				    ,"Equity/Developed/Pacific"
				    ,"Equity/Emerging"
				    ,"Alpha"
				    ]}).addProp("targetPercent",
						{
     "Cash":60+4.48,"Real Estate/Commercial":5.76
    ,"Commodities/Ex-Timber":3.41
    ,"Commodities/Timber/Plum Creek Timber":4.27*0.7
    ,"Commodities/Timber/Rayonier":4.27*0.3
    ,"Equity/Developed":19.94-3.41
    ,"Equity/Emerging":3.41
    ,"Alpha":2.13
    }
					);

// Note: it is incorrect to split cash equally across the 3 currencies
// Should take in account the total portfolio split across currencies
// (and also the fact that we are overexposed in GBP because of the house/pension anyway)

Taxonomy.ukAssets = function() {return new Taxonomy({name:"Assets",open:false,paths:
				 [
				  "Cash/EUR","Cash/GBP","Cash/USD"
				  ,"Debt/Real Return/UK"
				  ,"Debt/Public/UK"
				  ,"Debt/Public/Global"
				  ,"Debt/Private"

				  ,"Real Estate/Commercial/UK"
				  ,"Real Estate/Commercial/Foreign"

				  ,"Commodities/Ex-Timber"
				  ,"Commodities/Timber"

				  ,"Equity/UK"
				  ,"Equity/EX-UK/Developed"
				  ,"Equity/EX-UK/Emerging"
				  ]}).addProp("targetPercent",
{
     "Debt/Real Return/UK":6.67,"Debt/Public":20.83+0.83
    ,"Real Estate/Commercial/UK":3.33
    ,"Real Estate/Commercial/Foreign":5

    ,"Commodities/Ex-Timber":10.83
    ,"Commodities/Timber":8.33

    ,"Equity/UK":22.50
    ,"Equity/EX-UK":8+2.5+2+9.17
  }
)};

/*
				  ,"Commodities/Industrial Metals"
				  ,"Commodities/Precious Metals"
				  ,"Commodities/Precious Metals/Gold"
				  ,"Commodities/Agriculture"
				  ,"Commodities/Livestock"

By Type of Investment:

,"Equity/Frontier"

,"Equity/Market Neutral"
,"Equity/Private"

"Equity/Large"
"Equity/Small"

Equity	byArea/Country byStyle byCurrency

Art

Life Insurance

Labour Capital
Social Capital
Intellectual Capital

Investment Area
    Developed
      USA, UK ..
    Emerging
      Taiwan,China,Russia
    Frontier
      Egypt..
*/











