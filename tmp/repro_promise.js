function demo(n,o,t,a){
  return new Promise(function(r){
    var e = c(t.parse(n), o.filter);
    r(Promise.all(e.map(function(t){
      return new Promise(function(n){
        function r(){n(t);}
        a.pinpoint(t).then(n,r).catch(r);
      });
    })));
  }.bind(this));
}
