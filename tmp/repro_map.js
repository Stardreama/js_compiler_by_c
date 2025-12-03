function demo(n,t,a){
  return new Promise(function(r){
    var e = c(t.parse(n), o.filter);
    r(Promise.all(e.map(function(x){
      return new Promise(function(n){ a.pinpoint(x).then(n).catch(n); });
    })));
  }.bind(this));
}
