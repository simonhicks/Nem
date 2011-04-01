{printable_array, eq, expect, expect_error} = require('../src/helpers')
{Reader} = require('../src/reader')
{puts} = require 'sys'

new_rdr = (c) -> new Reader(c)
parse = (code) ->
  new_rdr(code).read()

# number literal
expect("simple integers", true, ->
  eq(parse("1")[0], ["NUMBER", 1]) && eq(parse("12")[0], ["NUMBER", 12])
)
expect("exponents", true, ->
  eq(parse("1123e2")[0], ["NUMBER", 112300]) && eq(parse("1.234e-2")[0], ["NUMBER", 0.01234]) &&
  eq(parse("1123E2")[0], ["NUMBER", 112300]) && eq(parse("1.234E-2")[0], ["NUMBER", 0.01234])
)
expect("floats", true, ->
  eq(parse("1.01")[0], ["NUMBER", 1.01]) && eq(parse("12.00391")[0], ["NUMBER", 12.00391]) && eq(parse("0.000987")[0], ["NUMBER", 0.000987])
)
expect("negative numbers", true, ->
  eq(parse("-1")[0], ["NUMBER", -1]) && eq(parse("-123")[0], ["NUMBER", -123]) && eq(parse("-1.23")[0], ["NUMBER", -1.23])
)
expect("negative exponents", true, ->
  eq(parse("-1e2")[0], ["NUMBER", -100]) && eq(parse("-123e-2")[0], ["NUMBER", -1.23]) && eq(parse("-1.23e2")[0], ["NUMBER", -123]) &&
  eq(parse("-1E2")[0], ["NUMBER", -100]) && eq(parse("-123E-2")[0], ["NUMBER", -1.23]) && eq(parse("-1.23E2")[0], ["NUMBER", -123])
)
expect("hex numbers", true, ->
  eq(parse("0x123abc")[0], ["NUMBER", 0x123abc]) && eq(parse("0X456DEF")[0], ["NUMBER", 0x456DEF])
)

# strings literals
expect("\" string literal", ["STRING", '"asdf"'], ->
  parse('''"asdf"''')[0]
)
expect("\' string literals", ["STRING", '"qwerty.123"'], ->
  parse("'qwerty.123'")[0]
)
expect("strings with ' quotes", '"there\\\'s"', ->
  parse("'there\\'s'")[0][1]
)
expect('strings with " quotes', '"it\\"s"', ->
  parse('"it\\"s"')[0][1]
)
expect('a more complex string', '"this is a much more\\t\\"complex\\" string...it\\\'s got quotes!"', ->
  parse('"this is a much more\\t\\"complex\\" string...it\\\'s got quotes!"')[0][1]
)

# other literals
expect('a regexp', true, ->
  eq(parse('/asdf/g')[0][1], /asdf/g)
)
expect('a more complex regexp', true, ->
  eq(parse('/as\\\\df/g')[0][1], /as\\df/g)
)
expect('another more complex regexp', true, ->
  eq(parse('/as\\\/df/g')[0][1], /as\/df/g)
)
expect('an uncalled message', ["IDENT", 'method'], ->
  parse('method')[0]
)

# function calls
#
# arg lists are modelled as arrays, with each element in the array representing a single arg.
# each arg is itself a message chain (which is modelled as an array), with each message also
# modelled as an array. For example.
#
# foo(obj.method()) // js
# foo(obj method()) ; nem
#
# obj_msg     = ['IDENT', 'obj']        ; this is a simgle token
# method_msg  = ['IDENT', 'method', []] ; the empty vector represents the empty arg-list
# arg_chain_1 = [obj_msg, method_msg]     ; the first arg is a message chain, which is an array of messages
# arg_list    = [arg_chain_1]             ; the arg list is an array of chains
# foo_msg     = ['IDENT', 'foo', arg_list]
# ast         = [foo_msg]
# => ['IDENT', 'foo', [[['IDENT', 'obj'], ['IDENT', 'method', []]]]] 
expect('calling a message with no arg', ["IDENT", 'func_call', []], ->
  parse('func_call()')[0]
)
expect('calling a message with one arg', ['IDENT', 'foo', [[["NUMBER", 1]]]], ->
  parse('foo(1)')[0]
)
expect('calling a message with one arg', ['IDENT', 'foo', [[["NUMBER", 1]]]], ->
  parse('foo( 1 )')[0]
)
expect('calling a message with two args', ['IDENT', 'foo', [[["STRING", '\"string\"']], [["NUMBER", 1]]]], ->
  parse('foo("string" , 1)')[0]
)
expect('calling a message with args on multiple lines', ['IDENT', 'foo', [[["NUMBER", 1]], [["NUMBER", 2]]]], ->
  parse('''foo( 
    1 , 2
  )''')[0]
)
expect('separating args with a newline', true, ->
  eq(parse('''foo(
    bar
    baz(1, /asdf/g)
  )''')[0], ['IDENT', 'foo', [[['IDENT', 'bar']], [["IDENT", 'baz', [[["NUMBER", 1]], [["REGEXP", /asdf/g]]]]]]])
)

# arrays and objects
expect('arrays', ['IDENT', 'array', [[["NUMBER", 1]], [["NUMBER", 2]], [["NUMBER", 3]]]], ->
  parse('[1, 2 ,3 ]')[0]
)
expect('arrays spread over several lines', ['IDENT', 'array', [[["NUMBER", 1]],[["NUMBER", 0]],[["NUMBER", 1]],[["NUMBER", 0]],[["NUMBER", 1]],[["NUMBER", 0]],[["NUMBER", 1]],[["NUMBER", 0]],[["NUMBER", 1]]]], ->
  parse('''[1,0,1
            0,1,0
            1,0,1]''')[0]
)
expect('objects', true, ->
  eq(parse('''{'foo', 1, bar, 2}''')[0], ['IDENT', 'object', [[['STRING', '"foo"']], [['NUMBER', 1]], [['IDENT', 'bar']], [['NUMBER', 2]]]])
)
expect('objects', true, ->
  eq(parse('''
  {'foo', 1
   bar  , 2}''')[0], ['IDENT', 'object', [[['STRING', '"foo"']], [['NUMBER', 1]], [['IDENT', 'bar']], [['NUMBER', 2]]]])
)

# message chains
expect('chained messages', [['IDENT', 'foo'], ['IDENT', 'bar', []], ['IDENT', 'baz', [[['NUMBER', 1]]]]], ->
  parse('''foo bar() baz(1)''')
)
expect('message chain in parens', [["IDENT", 'foo'], ["IDENT", 'bar', []], ['IDENT', 'baz']], ->
  parse('''(foo bar() baz)''')[0] # notice that this has an extra level of nesting
)
expect('parsing two lines, we only read the first chain', true, ->
  eq(parse('''
  foo bar()
  $('#id') hide()
  '''), [["IDENT", 'foo'], ["IDENT", 'bar', []]])
)

# nested arrays and objects
expect('nested arrays', ["IDENT", 'array', [[["IDENT", 'array', [[['NUMBER', 1]], [['NUMBER', 2]]]]], [['IDENT', 'array', [[['NUMBER', 3]], [['NUMBER', 4]]]]]]], ->
  parse('''
  [[1, 2],
   [3, 4]]
   ''')[0]
)
expect('nested arrays', ["IDENT", 'array', [[["IDENT", 'array', [[['NUMBER', 1]], [['NUMBER', 2]]]]], [['IDENT', 'array', [[['NUMBER', 3]], [['NUMBER', 4]]]]]]], ->
  parse('''
  [
    [ 1 , 2 ],
    [ 3 , 4 ]
  ]
   ''')[0]
)
obj1 = [["IDENT", 'object', [[['IDENT', 'foo']], [['STRING', '"bar"']], [['IDENT', 'baz']], [['NUMBER', 1]]]]]
obj2 = [["IDENT", 'object', [[['IDENT', 'bob']], [['NUMBER', 10]], [['IDENT', 'asd']], [['NUMBER', 123]]]]]
expect('objects in arrays',["IDENT",'array',[obj1,obj2]], ->
  parse('''
  [{foo, "bar", baz, 1},
   {bob, 10 , asd, 123}]
   ''')[0]
)
expect('nested arrays w/o ,', ["IDENT", 'array', [[["IDENT", 'array', [[['NUMBER', 1]], [['NUMBER', 2]]]]], [['IDENT', 'array', [[['NUMBER', 3]], [['NUMBER', 4]]]]]]], ->
  parse('''
  [
    [ 1 , 2 ]
    [ 3 , 4 ]
  ]
   ''')[0]
)
expect('objects in arrays w/o ,',["IDENT",'array',[obj1,obj2]], ->
  parse('''
  [{foo, "bar", baz, 1}
   {bob, 10 , asd, 123}]
   ''')[0]
)
arr1 = [["IDENT",'array', [[['NUMBER', 123]], [['NUMBER', 456]]]]]
arr2 = [['IDENT','array', [[['STRING', '"asdf"']], [['IDENT', 'object',[[['IDENT','blah']],[['STRING', '"blah"']]]]]]]]
expect('arrays in objects', ["IDENT", 'object', [[['IDENT', 'asdf']], arr1, [['STRING', '"qw"']], arr2]],->
  parse('''
  {asdf, [123, 456]
   'qw', ['asdf', {blah, 'blah'}]}
  ''')[0]
)
expect('objects in objects', ['IDENT', 'object', [[['IDENT', 'blah']],[['IDENT','object',[[['IDENT', 'a']],[['IDENT', 's']],[['IDENT', 'd']],[['IDENT', 'f']]]]]]], ->
  parse('''
  {
    blah, {
            a, s
            d, f
          }
  }
  ''')[0]
)

# nested chains
expect('a chain in an array', ['IDENT', 'array', [[['IDENT', 'foo', []],['IDENT','bar'],['IDENT','baz', []]],[['NUMBER', 2]]]], ->
  parse('''
  [foo() bar baz(), 2]
  ''')[0]
)
expect('a chain in an array', ['IDENT', 'array', [[['NUMBER', 1]],[['IDENT', 'foo', []],['IDENT','bar'],['IDENT','baz', []]],[['NUMBER', 2]]]], ->
  parse('''
  [1, foo() bar baz(), 2]
  ''')[0]
)
expect('a chain in a chain', [['IDENT', 'foo'], [['IDENT', 'bar'], ['IDENT', 'baz', []]], ['IDENT', 'blagh']], ->
  parse('''
  foo (bar baz()) blagh
  ''')
)

# arrays/objects in a chain
expect('an array in a chain', [['IDENT', 'array', [[['NUMBER', 1]],[['NUMBER', 2]]]],['IDENT', 'concat', []]], ->
  parse('''
  [1, 2] concat()
  ''')
)
expect('an object in a chain', [["IDENT", 'object', [[['IDENT', 'a']],[['NUMBER', 1]]]], ['IDENT', 'something', []]], ->
  parse('''
  {a, 1} something()
  ''')
)
expect('an array in a chain', [['IDENT', 'do_something'],['IDENT', 'array', [[['NUMBER', 1]],[['NUMBER', 2]]]]], ->
  parse('''
  do_something [1, 2]
  ''')
)
expect('an object in a chain', [['IDENT', 'something', []], ["IDENT", 'object', [[['IDENT', 'a']],[['NUMBER', 1]]]]], ->
  parse('''
  something() {a, 1}
  ''')
)

# arrays/objects as args
expect('an array as an arg', ['IDENT', 'foo',[[['IDENT', 'array', [[['NUMBER', 1]], [['NUMBER', 2]]]]]]], ->
  parse('''
  foo([1,2])
  ''')[0]
)
expect('an object as an arg', ['IDENT', 'foo',[[['IDENT', 'object', [[['STRING', '"a"']], [['NUMBER', 1]]]]]]], ->
  parse('''
  foo({'a', 1})
  ''')[0]
)

# comments
expect('a comment', [['IDENT', 'foo']], ->
  parse('''
  foo ; blah blah blah
  ''')
)
expect('a comment in an arg list', true, ->
  eq(parse('''foo(
    bar             ; this comment should be ignored
    baz(1, /asdf/g) ; so should this one
  )''')[0], ['IDENT', 'foo', [[['IDENT', 'bar']], [["IDENT", 'baz', [[["NUMBER", 1]], [["REGEXP", /asdf/g]]]]]]])
)
expect('a comment before an expression', [['IDENT', 'foo']], ->
  parse('''
  ; blah blah blah
  foo
  ''')
)

# syntax quote
expect('a syntax quote', [['IDENT', 'quote'], ['IDENT', 'Im_bored_of_foo', []], ['IDENT', 'whatever', []]], ->
  parse('''
  `Im_bored_of_foo() whatever()
  ''')
)

# unmatched pair error messages
expect_error('unbalanced parens', "SyntaxError: unclosed parenthesis on line 4", ->
  code = '''
  foo bar baz()
  obj method()
  alert(1 + 2)
  blah(
    do_more_stuff()
    inside the_brackets()
  '''
  new_rdr(code).read_all()
)
expect_error('unbalanced square bracket', "SyntaxError: unclosed array on line 1", ->
  code = '''
  [
    1,2,3
    4,5,6
    '''
  new_rdr(code).read_all()
)
expect_error('unbalanced curly bracket', "SyntaxError: unclosed object on line 1", ->
  code = '''
  {
    foo, 3
    bar, 6
    '''
  new_rdr(code).read_all()
)
expect_error('unbalanced " quote marks', "SyntaxError: unclosed \" on line 1", ->
  code = '''
  "this string isn't closed, but it does have \\"another string\\" inside it
  '''
  new_rdr(code).read_all()
)
expect_error('unbalanced \' quote marks', "SyntaxError: unclosed \' on line 1", ->
  code = '''
  'this string isn\\'t closed, but it does have \\"another string\\" inside it
  '''
  new_rdr(code).read_all()
)

# missing message args
expect_error('missing implied arguments', 'SyntaxError: bad argument list on line 1', ->
  code = '''
  foo(1, ,3)
  '''
  new_rdr(code).read_all()
)
expect_error('missing implied arguments', 'SyntaxError: bad argument list on line 1', ->
  code = '''
  [1, ,3]
  '''
  new_rdr(code).read_all()
)

# bad object field label
expect_error('bad object field', 'SyntaxError: illegal object literal on line 1', ->
  code = '''
  {
    /asdf/, foo
  }
  '''
  new_rdr(code).read_all()
)
# odd number of object args
expect_error('odd number of object arguments', 'SyntaxError: illegal object literal on line 1', ->
  code = '''
  {a, 1, b}
  '''
  new_rdr(code).read_all()
)

# TODO register "implicit consumers" that expect a given minimum number of args... 
#   if they don't have them in brackets, they can just absorb the next N messages in the chain
# TODO convert tokens into "message objects", that can be sent to origin and compiled
# TODO refactor to use 
#   expect (for things that won't appear in the ast like "(")
#   list (with expect() parsers as separators)
#
