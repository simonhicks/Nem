{list, ps, action, range, repeat1, choice, sequence, optional, negate, token, repeat0, end_p} = require('../libs/jsparse')
{printable_array, flatten, remove} = require './helpers'
{puts} = require 'sys'

# forward definitions
literal = (state) ->
  literal(state)

non_message_literal = (state) ->
  non_message_literal(state)

expr = (state) ->
  expr(state)

single_form = (state) ->
  single_form(state)

# Convenience functions
linebreak = action(repeat1(choice("\n", "\r")), (ast) -> "\n")

nb_whitespace = action(repeat1(choice(' ', '\t', '\f')), (ast) -> " ")

whitespace = repeat1(choice(nb_whitespace, linebreak))

# parser-combinator convenience functions
splice = (parser) ->
  action sequence('#{', parser, '}'), (ast) ->
    ast[1].unshift('SPLICE')
    ast[1]

unquote = (parser) ->
  action sequence('@{', parser, '}'), (ast) ->
    ast[1].unshift('UNQUOTE')
    ast[1]

possible_splice = (parser) ->
  choice(unquote(parser), splice(parser), parser)

# Number literals
zero = action "0", (ast) -> 0

decimal_digit = range("0", "9")

non_zero_digit = range("1", "9")

decimal_digits = repeat1(decimal_digit)

decimal_integer_literal = sequence(optional("-"), choice( zero, sequence(non_zero_digit, optional(decimal_digits))))

signed_integer = choice(decimal_digits, sequence("+", decimal_digits), sequence("-", decimal_digits))

exponent_indicator = choice("e", "E")

exponent_part = sequence(exponent_indicator, signed_integer)

decimal_1 = sequence(decimal_integer_literal, ".", optional(decimal_digits), optional(exponent_part))

decimal_2 = sequence(".", decimal_digits, optional(exponent_part)) 

decimal_3 = sequence(decimal_integer_literal, optional(exponent_part))

decimal_literal = choice(decimal_1, decimal_2, decimal_3)

hex_digit = choice(range("0", "9"), range("a", "f"), range("A", "F"))

hex_integer_literal = sequence(choice("0x", "0X"), repeat1(hex_digit))

make_number = (ast) ->
  num = eval(remove(false, flatten(ast)).join("").toLowerCase())
  ["NUMBER", num]

numeric_literal = action choice(hex_integer_literal, decimal_literal), make_number


# String literals
single_escape_character = choice("'", "\"", "\\", "b", "f", "n", "r", "t", "v")

non_escape_character = negate(single_escape_character)

character_escape_sequence = choice(single_escape_character, non_escape_character)

hex_escape_sequence = sequence("x", hex_digit, hex_digit)

unicode_escape_sequence = sequence("u", hex_digit, hex_digit, hex_digit, hex_digit)

escape_sequence = choice(hex_escape_sequence, unicode_escape_sequence, character_escape_sequence)

single_string_character = choice(negate(choice("\'", "\\", "\r", "\n")), sequence("\\", escape_sequence))
double_string_character = choice(negate(choice("\"", "\\", "\r", "\n")), sequence("\\", escape_sequence))

single_string_characters = repeat1(single_string_character)
double_string_characters = repeat1(double_string_character)

make_string = (ast) ->
  base = flatten(ast[1]||[]).join("")
  ["STRING", '"' + base + '"']

single_string_literal = sequence("'", optional(single_string_characters), "'")
double_string_literal = sequence('"', optional(double_string_characters), '"')
string_literal = action(choice(single_string_literal, double_string_literal), make_string)


# Regexp literals
regexp_mod_char = choice("g", "i", "m")

regexp_delimiter = token("/")

regexp_char = choice(negate(choice(regexp_delimiter, linebreak, "\\")), sequence("\\", choice("/", "\\")))

make_regexp = (ast) ->
  base = flatten(ast[1]||[]).join('')
  mods = flatten(ast[3]||[]).join('')
  ["REGEXP", new RegExp(base, mods)]

regexp_literal = action(sequence(regexp_delimiter, repeat1(regexp_char), regexp_delimiter, repeat0(regexp_mod_char)), make_regexp)


# Punctuation
open_paren = action sequence("(", optional(whitespace)), (ast) -> null
close_paren = action sequence(optional(whitespace), ")"), (ast) -> null

comma = action sequence(optional(whitespace), ",", optional(whitespace)), (ast) -> null

newline = action sequence(optional(nb_whitespace), linebreak, optional(nb_whitespace)), (ast) -> null

separator = choice(newline, comma)

# Message literals
extra_arg = action sequence(separator, expr), (ast) ->
  ast[0]

bad_arg = action sequence(comma, comma), ->
  throw "bad argument list"

args = action sequence(expr, repeat0(choice(extra_arg, bad_arg))), (ast) ->
  [ast[0]].concat ast[1]

arg_list = sequence(open_paren, optional(args), close_paren)

message_char = negate(choice("#","`",";",",","(",")","[","]","{", "}",'"', "'",whitespace))

uncalled_message = action(repeat1(message_char), (ast) -> 
  ["IDENT", flatten(ast).join('')])

called_message = action(sequence(repeat1(message_char), arg_list), (ast) ->
  arg_list = ast[1][0] || []
  ["IDENT", flatten(ast[0]).join(''), arg_list])

message_literal = choice(called_message, uncalled_message)

# Arrays
open_square = sequence(optional(nb_whitespace), "[", optional(whitespace))

close_square = sequence(optional(whitespace), "]")

array_literal = action(sequence(open_square, optional(args), close_square), (ast) ->
  ["IDENT", 'array', ast[1]])

# Chained messages
chain_part = choice(non_message_literal, message_literal)

extra_literal = action sequence(nb_whitespace,chain_part), (ast) ->
  ast[1]

open_chain = action(sequence(optional(whitespace), chain_part, repeat0(extra_literal)), (ast) ->
  [ast[1]].concat ast[2]
)

chain_in_parens = possible_splice action(sequence(open_paren, choice(open_chain, literal), close_paren), (ast) ->
  ast[0]
)
spliced_chain = splice(open_chain)
unquoted_chain = unquote(open_chain)


# Object literals
open_curly = sequence(optional(nb_whitespace), "{", optional(whitespace))

close_curly = sequence(optional(whitespace), "}")

make_object = (args...) ->
  length = args.length
  unless length % 2 is 0
    throw 'illegal object literal'
  for i in [0...length] by 2
    do (i) ->
      this_arg = args[i][0]
      unless this_arg.constructor is Array and ((this_arg[0] is 'IDENT' and this_arg[1] isnt 'array' and this_arg[1] isnt 'object') or this_arg[0] is 'STRING')
        throw "illegal object literal"
  ["IDENT", 'object', args]

object_literal = action sequence(open_curly, optional(args), close_curly), (ast) ->
  make_object(ast[1]...)


# Special stuff
comment = action sequence(optional(whitespace), ';', repeat0(negate(linebreak))), (ast) -> null

end_of_code = sequence optional(whitespace), end_p

basic_literal = possible_splice(choice(numeric_literal, string_literal, regexp_literal, array_literal, object_literal))
non_message_literal = choice(basic_literal, unquoted_chain, spliced_chain, chain_in_parens)


syntax_quote = (item) ->
  if item.constructor is Array
    if item[0] is 'UNQUOTE'
      item.shift()
      item
    else if item[0] is 'SPLICE'
      item.shift()
      [['IDENT', 'array', [[['STRING', '"IDENT"']], [['STRING', '"splice"']], [['IDENT', 'array', [[['IDENT', 'array', [[item]]]]]]]]]]
    else
      args = (syntax_quote(arg) for arg in item)
      [['IDENT', 'array', args]]
  else if item.constructor is Number
    [['NUMBER', item]]
  else if item.constructor is RegExp
    [['REGEXP', item]]
  else if item.constructor is String
    [['STRING', '"' + item.replace(/"/g, '\\"') + '"']]

literal = action sequence(optional("`"), choice(open_chain, non_message_literal, message_literal)), (ast) ->
  pre_quote = remove false, ast[1]
  if ast[0]
    syntax_quote pre_quote
  else
    pre_quote

expr = action sequence(optional(nb_whitespace), literal, optional(comment)), (ast) ->
  remove false, ast[1]

unclosed_pair = (open_char, message) ->
  action sequence(optional(whitespace), open_char, repeat0(choice(single_form, args, negate(open_char))), end_p), (ast) ->
    throw message

paren_error     = unclosed_pair open_paren , "unclosed parenthesis"
unclosed_array  = unclosed_pair open_square, "unclosed array"
unclosed_object = unclosed_pair open_curly , "unclosed object"

unclosed_string = action choice(sequence("\"", optional(double_string_characters)), sequence("'", optional(single_string_characters))), (ast) ->
  throw "unclosed #{ast[0]}"

error = choice(paren_error, unclosed_array, unclosed_object, unclosed_string)

single_form = action choice(sequence(repeat0(choice(whitespace, comment)), expr), error), (ast) ->
  ast[1]

# this is so we can catch any errors not specifically catered for by the above parsers
# so the user never sees incomprehensible parser errors
anything_else = action sequence(repeat0(negate(end_p)), end_p), (ast) ->
  offending_code = flatten(remove(false, ast)).join("").split("\n")[0]
  throw "illegal form '#{offending_code}'"

exports.Reader = class Reader
  constructor: (code) ->
    @matched = ""
    @chains = []
    @state = ps(code)
    @parse = choice(single_form, anything_else)

  read: ->
    try
      {matched, ast, remaining} = @parse(@state)
    catch err
      line = @matched.split("\n").length
      error_message = err.toString()
      throw "SyntaxError: #{error_message} on line #{line}"
    @state = remaining
    @matched += matched
    @chains.push(ast)
    ast

  read_all: ->
    while not end_of_code(@state)
      @read()
    @chains
