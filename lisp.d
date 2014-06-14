import std.conv;
import std.exception;
import std.stdio;

const char kLPar = '(';
const char kRPar = ')';
const char kQuote = '\'';

enum Type {
  Nil,
  Num,
  Sym,
  Error,
  Cons,
  Subr,
  Expr
}

class LObj {
  struct Cons {
    LObj car;
    LObj cdr;
  }
  struct Expr {
    LObj args;
    LObj bdy;
    LObj env;
  }
  alias Subr = LObj function(LObj);
  union Data {
    int num;
    string str;
    Cons cons;
    Expr expr;
    Subr subr;
  }

  this(Type type) {
    tag = type;
  }
  this(Type type, string str) {
    tag = type;
    data.str = str;
  }
  this(Type type, int num) {
    tag = type;
    data.num = num;
  }
  this(Type type, LObj a, LObj d) {
    tag = type;
    data.cons.car = a;
    data.cons.cdr = d;
  }
  this(Type type, LObj args, LObj bdy, LObj env) {
    tag = type;
    data.expr.args = args;
    data.expr.bdy = bdy;
    data.expr.env = env;
  }
  this(Type type, Subr subr) {
    tag = type;
    data.subr = subr;
  }

  Type tag;
  Data data;
}
LObj kNil;  // Should be initialized in main.

LObj[string] sym_table;
LObj makeSym(string str) {
  if (str == "nil") {
    return kNil;
  }
  if (!(str in sym_table)) {
    sym_table[str] = new LObj(Type.Sym, str);
  }
  return sym_table[str];
}

bool isSpace(char c) {
  return c == '\t' || c == '\r' || c == '\n' || c == ' ';
}

bool isDelimiter(char c) {
  return c == kLPar || c == kRPar || c == kQuote || isSpace(c);
}

string skipSpaces(string str) {
  int i;
  for (i = 0; i < str.length; ++i) {
    if (!isSpace(str[i])) {
      break;
    }
  }
  return str[i..$];
}

LObj makeNumOrSym(string str) {
  int num;
  Exception e = collectException(num = to!int(str));
  if (e) {
    return new LObj(Type.Sym, str);
  }
  return new LObj(Type.Num, num);
}

class ParseState {
  this(LObj o, string n) {
    obj = o;
    next = n;
  }
  LObj obj;
  string next;
}

ParseState readAtom(string str) {
  string next = "";
  for (int i = 0; i < str.length; ++i) {
    if (isDelimiter(str[i])) {
      next = str[i..$];
      str = str[0..i];
    }
  }
  return new ParseState(makeNumOrSym(str), next);
}

ParseState read(string str) {
  str = skipSpaces(str);
  if (str.length == 0) {
    return new ParseState(new LObj(Type.Error, "empty input"), "");
  } else if (str[0] == kRPar) {
    return new ParseState(new LObj(Type.Error, "invalid syntax: " ~ str), "");
  } else if (str[0] == kLPar) {
    return new ParseState(new LObj(Type.Error, "noimpl"), "");
  } else if (str[0] == kQuote) {
    return new ParseState(new LObj(Type.Error, "noimpl"), "");
  }
  return readAtom(str);
}

void main() {
  kNil = new LObj(Type.Nil);
  string line;
  write("> ");
  while ((line = readln()).length > 0) {
    write(read(line).obj.tag);
    write("\n> ");
  }
}
