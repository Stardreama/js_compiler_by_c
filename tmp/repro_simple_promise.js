function demo(){
  return new Promise(function(r){ r(); }.bind(this));
}
