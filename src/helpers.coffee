{puts} = require('sys')
{deepEqual} = require('assert')

exports.flatten = flatten = (array) ->
  result = []
  for e in array
    do (e) ->
      if e.constructor is Array
        result = result.concat(flatten(e))
      else
        result.push(e)
  result

exports.remove = remove = (item, array) ->
  result = []
  for e in array
    do (e) ->
      result.push(e) unless e == item
  result

exports.partition = partition = (n, array) ->
  result = []
  i = 0
  while i < array.length
    result.push(array[i...(i + n)])
    i += 2
  result

regex_eq = (re1, re2, verbose=false) ->
  if re1.source == re2.source && re1.global == re2.global && re1.ignoreCase == re2.ignoreCase && re1.multiline == re2.multiline
    true
  else
    puts "re1 = #{re1.toString()}; re2 = #{re2.toString()};" if verbose
    false

exports.printable_array = printable_array = (coll) ->
  strings = []
  for i in coll
    do (i) ->
      if i.constructor is Array
        strings.push printable_array(i)
      else
        strings.push i.toString()
  "[" + strings.join(", ") + "]"


array_eq = (arr1, arr2, verbose=false) ->
  unless arr1.length == arr2.length
    puts "arr1 has #{arr1.length} items but arr2 has #{arr2.length} items" if verbose
    puts "arr1 is #{printable_array(arr1)} and arr2 is #{printable_array(arr2)}" if verbose
    false
  else
    equal = true
    for i in [0...arr1.length]
      do (i) ->
        unless eq(arr1[i], arr2[i], verbose)
          if verbose
            puts "arr1[#{i}] = #{arr1[i]}"
            puts "arr2[#{i}] = #{arr2[i]}"
          equal = false
    equal

strip = (str) ->
  str.replace(/^\s+/, '').replace(/\s+$/, '')

string_eq = (str1, str2, verbose=false) ->
  if strip(str1) == strip(str2)
    true
  else
    puts "str1 = #{str1}; str2 = #{str2};" if verbose 
    false

object_eq = (obj1, obj2, verbose=false) ->
  same = true
  for k,v of obj1
    do (k, v) ->
      unless eq(obj2[k], v, verbose)
        same = false 
        if verbose
          puts "obj1 = #{obj1}"
          puts "obj2 = #{obj2}"
          puts "obj1[#{k}] = #{obj1[k]}"
          puts "obj2[#{k}] = #{obj2[k]}"
  for k,v of obj2
    do (k, v) ->
      unless eq(obj1[k], v, verbose)
        if verbose
          puts "obj1 = #{obj1}"
          puts "obj2 = #{obj2}"
          puts "obj1[#{k}] = #{obj1[k]}"
          puts "obj2[#{k}] = #{obj2[k]}"
        same = false 
  same

exports.eq = eq = (e1,e2, verbose=false) ->
  klass = e1.constructor
  unless e2.constructor == klass
    puts "#{e1} is a #{e1.constructor.name} but #{e2} is a #{e2.constructor.name}" if verbose
    return false
  switch klass
    when Number then e1 == e2
    when Array then array_eq(e1, e2, verbose)
    when RegExp then regex_eq(e1,e2, verbose)
    when String then string_eq(e1, e2, verbose)
    else object_eq(e1, e2)

pass = []
fail = []

exports.expect = expect = (message, expected, callback) ->
  finished = false
  try
    result = callback()
    finished = true
    deepEqual(result, expected)
    pass.push("pass - #{message}")
  catch e
    error_message = if finished then "Result: #{result}" else e.toString()
    fail.push "FAIL - #{message} - #{error_message}"

exports.expect_error = expect_error = (message, arg1, arg2) ->
  if arg1.constructor is String
    expected_message = arg1
    callback = arg2
  else
    expected_message = null
    callback = arg1
  try
    result = callback()
    error_message = "Result: #{result}"
    fail.push "FAIL - #{message} - #{error_message}"
  catch e
    if expected_message && expected_message != e.toString()
      fail.push "FAIL - #{message} - #{e.toString()}"
    else
      pass.push "pass - #{message}"

exports.report = report = (verbose=false) ->
  puts ""
  if verbose
    puts msg for msg in pass
  puts msg for msg in fail
  puts "\n----------------------------------------------------------------\n"
  puts "Pass: #{p = pass.length} Fail: #{f = fail.length} Total: #{p + f}\n"
