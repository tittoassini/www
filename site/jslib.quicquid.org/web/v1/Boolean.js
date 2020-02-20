Boolean.prototype.xor = function(b) {
  return (!this.valueOf() && b) || (this.valueOf() && !b);
} 
