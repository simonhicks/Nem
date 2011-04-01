{expect, flatten, remove, partition} = require('../src/helpers')

expect "flatten should flatten an array", [1,2,3], ->
  flatten([1,[2,[3]]])

expect "remove should remove all instances of the given object", [1,2,3,4], ->
  remove(false, [1,2,false,3,false,4])

expect "partition should split an array into groups", [[1,2],[3,4],[5,6]], ->
  partition(2, [1,2,3,4,5,6])

