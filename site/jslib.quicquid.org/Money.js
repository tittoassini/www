function Money(amount,currency) {
    //if (Ext.isEmpty(Money.convRate(currency))) throw new Error("Unknown currency "+currency);
    
    this.amount   = amount;
    this.currency = currency.toUpperCase();
}

Money.eur = function(amount) {return new Money(amount,"EUR");};

Money.gbp = function(amount) {return new Money(amount,"GBP");};

Money.usd = function(amount) {return new Money(amount,"USD");};

Money.convRate = function(currency) {return Stock.quote(currency.toUpperCase()+"EUR").amount;}

Money.fromTo = function(fromCurrency,toCurrency,amount) {
    return amount*Money.convRate(fromCurrency)/Money.convRate(toCurrency);
};

Money.prototype.as = function(currency) {return Money.fromTo(this.currency,currency,this.amount);};

Money.prototype.asEUR = function() {return this.as("EUR")};
    



