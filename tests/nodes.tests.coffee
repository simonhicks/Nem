{printable_array, eq, expect, expect_error} = require('../src/helpers')
{Origin, Ident} = require('../src/nodes')
{puts} = require 'sys'

o = new Origin()

# basic call chain stuff
expect('compiling an uncalled ident', 'foo', ->
  id = new Ident(o, ['IDENT', 'foo'])
  id.compile()
)
expect('compiling a called ident, without args', 'bar()', ->
  id = new Ident(o, ['IDENT', 'bar', []])
  id.compile()
)
expect('sending and compiling a simple message', 'foo', ->
  o.send(['IDENT', 'foo']).compile()
)
expect('sending and compiling a called message', 'baz()', ->
  o.send(['IDENT', 'baz', []]).compile()
)
expect('compiling a called ident with an arg', 'foo(bar)', ->
  o.send(['IDENT', 'foo', [[['IDENT', 'bar']]]]).compile()
)
expect('compiling a called ident with two args', 'foo(1, 2)', ->
  o.send(['IDENT', 'foo', [[['NUMBER', 1]], [['NUMBER', 2]]]]).compile()
)
expect('sending a message chain', 'foo.bar(baz)', ->
  o.send(['IDENT', 'foo']).send(['IDENT', 'bar', [[['IDENT', 'baz']]]]).compile()
)
expect('sending a longer message chain', 'foo.bar().baz.blagh()', ->
  o.send(['IDENT', 'foo']).send(['IDENT', 'bar', []]).send(['IDENT', 'baz']).send(['IDENT', 'blagh', []]).compile()
)
expect('sending a number to origin', '3', ->
  o.send(['NUMBER', 3]).compile()
)
expect('number.method()', '3.method()', ->
  o.send(['NUMBER', 3]).send(['IDENT', 'method', []]).compile()
)
expect('sending a string literal', '"this is a string"', ->
  o.send(['STRING', '"this is a string"']).compile()
)
expect('sending a regexp literal', '/asdf/g', ->
  o.send(['REGEXP', '/asdf/g']).compile()
)
expect('sending a number to a callchain', 'foo.bar[1]', ->
  o.send(['IDENT', 'foo']).send(['IDENT', 'bar']).send(['NUMBER', 1]).compile()
)
expect('sending a string to a callchain', 'foo.bar["asdf"]', ->
  o.send(['IDENT', 'foo']).send(['IDENT', 'bar']).send(['STRING', '"asdf"']).compile()
)

# dynamic field access
expect('accessing a field using a variable', 'foo[bar]', ->
  o.send(['IDENT', 'foo']).send(['IDENT', 'get', [[['IDENT', 'bar']]]]).compile()
)
expect('accessing a field using a chain', 'foo[bar.baz]', ->
  o.send(['IDENT', 'foo']).send(['IDENT', 'get', [[['IDENT', 'bar'], ['IDENT', 'baz']]]]).compile()
)
expect('implicit this when get is sent to origin', 'this[bar]', ->
  o.send(['IDENT', 'get', [[['IDENT', 'bar']]]]).compile()
)

# code blocks
expect('creating blocks of code', 'foo();\nbar();', ->
  o.send(['IDENT', 'do', [[['IDENT', 'foo', []]], [['IDENT', 'bar', []]]]]).compile()
)
expect('sending a block as a message', 'foo.bar();\nfoo.baz();', ->
  o.send(['IDENT', 'foo']).send(['IDENT', 'do', [[['IDENT', 'bar', []]], [['IDENT', 'baz', []]]]]).compile()
)

# if/else

# if(foo
#   bar()
#   baz()
# )
expect('conditional execution', 'if (foo) {\n  bar();\n  baz();\n}', ->
  o.send(['IDENT', 'if', [[['IDENT', 'foo']], [['IDENT', 'bar', []]], [['IDENT', 'baz', []]]]]).compile()
)
# else(
#   do_something(1, 2)
# )
expect('else...', 'else {\n  do_something(1, 2);\n}', ->
  o.send(['IDENT', 'else', [[['IDENT', 'do_something', [[['NUMBER', 1]], [['NUMBER', 2]]]]]]]).compile()
)

# functions
# function([], alert("Hello World!"))
expect('an anonymous function w/o args', 'function () {\n  alert("Hello World!");\n}', ->
  o.send(['IDENT', 'function', [[['IDENT', 'array', []]], [['IDENT', 'alert', [[['STRING', '"Hello World!"']]]]]]]).compile()
)

# arrays
expect('an array', '[1, 2, 3]', ->
  o.send(['IDENT', 'array', [[['NUMBER', 1]],[['NUMBER', 2]],[['NUMBER', 3]]]]).compile()
)

# function([a, b]
#   alert(a)
#   alert(b)
# )
expect('an anonymous function w/ args', 'function (a, b) {\n  alert(a);\n  alert(b);\n}', ->
  o.send(['IDENT', 'function', [[['IDENT', 'array', [[['IDENT', 'a']], [['IDENT', 'b']]]]], [['IDENT', 'alert', [[['IDENT', 'a']]]]], [['IDENT', 'alert', [[['IDENT', 'b']]]]]]]).compile()
)

# wrapping things so they can be used as expressions
expect('wrapping a function', '(function () {\n  null;\n})', ->
  o.send(['IDENT', 'function', [[['IDENT', 'array',[]]], [['IDENT', 'null']]]]).wrap().compile()
)
expect('wrapping an if in a self calling function', '(function () {\n  if (foo) {\n    bar();\n  };\n})()', ->
  o.send(['IDENT', 'if', [[['IDENT', 'foo']], [['IDENT', 'bar', []]]]]).wrap().compile()
)
expect('wrapping origin returns origin', 'this', ->
  o.wrap().compile()
)
expect('wrapping an array adds parens', '([1, 2, 3])', ->
  o.send(['IDENT', 'array', [[['NUMBER', 1]],[['NUMBER', 2]],[['NUMBER', 3]]]]).wrap().compile()
)
expect('wrapping a number does nothing', '1', ->
  o.send(['NUMBER', 1]).wrap().compile()
)
expect('wrapping a string does nothing', '"asdf"', ->
  o.send(['STRING', '"asdf"']).wrap().compile()
)

# elsif
expect('else if', 'else if (foo) {\n  bar();\n}', ->
  o.send(['IDENT', 'elsif', [[['IDENT', 'foo']], [['IDENT','bar', []]]]]).compile()
)
expect_error('can\'t wrap else if on it\'s own', "CompileError: You can't wrap elsif on its own", ->
  o.send(['IDENT', 'elsif', [[['IDENT', 'foo']], [['IDENT','bar', []]]]]).wrap().compile()
)

# var
expect('a var declaration', 'var a', ->
  o.send(['IDENT', 'var', [[['IDENT', 'a']]]]).compile()
)
expect('multiple var declarations', 'var a, b, c', ->
  o.send(['IDENT', 'var', [[['IDENT', 'a']], [['IDENT', 'b']], [['IDENT', 'c']]]]).compile()
)

# expr messages get sent straight through when sent to origin
expect('expr message', 'blah blah blah', ->
  o.send(['EXPR', 'blah blah blah']).compile()
)
# but they can't be sent to anything else
expect_error('expr message error', 'CompileError: EXPR messages can only be sent to Origin', ->
  o.send(['IDENT', 'foo']).send(['EXPR', 'blah blah blah']).compile()
)


# refactor called Idents to use Ident and CallNode
# 
# TODO
#   add a #wrap method to all nodes
#     should return this if no wrapping is needed
#     should return new CallNode(@parent, new FunctionNode(@parent, this)) otherwise
