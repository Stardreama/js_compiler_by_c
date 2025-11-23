// Missing closing parenthesis in for statement should fail parsing

for (var i = 0; i < 3; i++ {
  var sum = i;
}
