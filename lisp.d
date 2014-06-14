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

  override string toString() {
    if (tag == Type.Nil) {
      return "nil";
    } else if (tag == Type.Num) {
      return to!string(data.num);
    } else if (tag == Type.Sym) {
      return data.str;
    } else if (tag == Type.Error) {
      return "<error: " ~ data.str ~ ">";
    } else if (tag == Type.Subr) {
      return "<subr>";
    } else if (tag == Type.Expr) {
      return "<expr>";
    }
    return listToString(this);
  }

  private string listToString(LObj obj) {
    string ret = "";
    bool first = true;
    while (obj.tag == Type.Cons) {
      if (first) {
        first = false;
      } else {
        ret ~= " ";
      }
      ret ~= obj.data.cons.car.toString();
      obj = obj.data.cons.cdr;
    }
    if (obj.tag == Type.Nil) {
      return "(" ~ ret ~ ")";
    }
    return "(" ~ ret ~ " . " ~ obj.toString() ~ ")";
  }

  Type tag;
  Data data;
}
LObj kNil;  // Should be initialized in Init().

LObj safeCar(LObj obj) {
  if (obj.tag == Type.Cons) {
    return obj.data.cons.car;
  }
  return kNil;
}

LObj safeCdr(LObj obj) {
  if (obj.tag == Type.Cons) {
    return obj.data.cons.cdr;
  }
  return kNil;
}

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

LObj makeCons(LObj a, LObj d) {
  return new LObj(Type.Cons, a, d);
}

LObj makeExpr(LObj args, LObj env) {
  return new LObj(Type.Expr, safeCar(args), safeCdr(args), env);
}

LObj nreverse(LObj lst) {
  LObj ret = kNil;
  while (lst.tag == Type.Cons) {
    LObj tmp = lst.data.cons.cdr;
    lst.data.cons.cdr = ret;
    ret = lst;
    lst = tmp;
  }
  return ret;
}

LObj pairlis(LObj lst1, LObj lst2) {
  LObj ret = kNil;
  while (lst1.tag == Type.Cons && lst2.tag == Type.Cons) {
    ret = makeCons(makeCons(lst1.data.cons.car, lst2.data.cons.car), ret);
    lst1 = lst1.data.cons.cdr;
    lst2 = lst2.data.cons.cdr;
  }
  return nreverse(ret);
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
    return makeSym(str);
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

ParseState parseError(string e) {
  return new ParseState(new LObj(Type.Error, e), "");
}

ParseState read(string str) {
  str = skipSpaces(str);
  if (str.length == 0) {
    return parseError("empty input");
  } else if (str[0] == kRPar) {
    return parseError("invalid syntax: " ~ str);
  } else if (str[0] == kLPar) {
    return readList(str[1..$]);
  } else if (str[0] == kQuote) {
    ParseState tmp = read(str[1..$]);
    return new ParseState(makeCons(makeSym("quote"), makeCons(tmp.obj, kNil)),
                          tmp.next);
  }
  return readAtom(str);
}

ParseState readList(string str) {
  LObj ret = kNil;
  while (true) {
    str = skipSpaces(str);
    if (str.length == 0) {
      return parseError("unfinished parenthesis");
    } else if (str[0] == kRPar) {
      break;
    }
    ParseState tmp = read(str);
    if (tmp.obj.tag == Type.Error) {
      return tmp;
    }
    ret = makeCons(tmp.obj, ret);
    str = tmp.next;
  }
  return new ParseState(nreverse(ret), str[1..$]);
}

LObj findVar(LObj sym, LObj env) {
  while (env.tag == Type.Cons) {
    LObj alist = env.data.cons.car;
    while (alist.tag == Type.Cons) {
      if (alist.data.cons.car.data.cons.car == sym) {
        return alist.data.cons.car;
      }
      alist = alist.data.cons.cdr;
    }
    env = env.data.cons.cdr;
  }
  return kNil;
}

LObj g_env;  // Should be initialized in Init().

void addToEnv(LObj sym, LObj val, LObj env) {
  env.data.cons.car = makeCons(makeCons(sym, val), env.data.cons.car);
}

LObj eval(LObj obj, LObj env) {
  if (obj.tag == Type.Nil || obj.tag == Type.Num || obj.tag == Type.Error) {
    return obj;
  } else if (obj.tag == Type.Sym) {
    LObj bind = findVar(obj, env);
    if (bind == kNil) {
      return new LObj(Type.Error, obj.data.str ~ " has no value");
    }
    return bind.data.cons.cdr;
  }

  LObj op = safeCar(obj);
  LObj args = safeCdr(obj);
  if (op == makeSym("quote")) {
    return safeCar(args);
  } else if (op == makeSym("if")) {
    if (eval(safeCar(args), env) == kNil) {
      return eval(safeCar(safeCdr(safeCdr(args))), env);
    }
    return eval(safeCar(safeCdr(args)), env);
  } else if (op == makeSym("lambda")) {
    return makeExpr(args, env);
  } else if (op == makeSym("defun")) {
    LObj expr = makeExpr(safeCdr(args), env);
    LObj sym = safeCar(args);
    addToEnv(sym, expr, g_env);
    return sym;
  } else if (op == makeSym("setq")) {
    LObj val = eval(safeCar(safeCdr(args)), env);
    LObj sym = safeCar(args);
    LObj bind = findVar(sym, env);
    if (bind == kNil) {
      addToEnv(sym, val, g_env);
    } else {
      bind.data.cons.cdr = val;
    }
    return val;
  }
  return apply(eval(op, env), evlis(args, env), env);
}

LObj evlis(LObj lst, LObj env) {
  LObj ret = kNil;
  while (lst.tag == Type.Cons) {
    LObj elm = eval(lst.data.cons.car, env);
    if (elm.tag == Type.Error) {
      return elm;
    }
    ret = makeCons(elm, ret);
    lst = lst.data.cons.cdr;
  }
  return nreverse(ret);
}

LObj progn(LObj bdy, LObj env) {
  LObj ret = kNil;
  while (bdy.tag == Type.Cons) {
    ret = eval(bdy.data.cons.car, env);
    bdy = bdy.data.cons.cdr;
  }
  return ret;
}

LObj apply(LObj fn, LObj args, LObj env) {
  if (fn.tag == Type.Error) {
    return fn;
  } else if (args.tag == Type.Error) {
    return args;
  } else if (fn.tag == Type.Subr) {
    return fn.data.subr(args);
  } else if (fn.tag == Type.Expr) {
    return progn(fn.data.expr.bdy,
                 makeCons(pairlis(fn.data.expr.args, args), fn.data.expr.env));
  }
  return new LObj(Type.Error, fn.toString() ~ " is not function");
}

LObj subrCar(LObj args) {
  return safeCar(safeCar(args));
}

LObj subrCdr(LObj args) {
  return safeCdr(safeCar(args));
}

LObj subrCons(LObj args) {
  return makeCons(safeCar(args), safeCar(safeCdr(args)));
}

void Init() {
  kNil = new LObj(Type.Nil);
  g_env = makeCons(kNil, kNil);
  addToEnv(makeSym("car"), new LObj(Type.Subr, &subrCar), g_env);
  addToEnv(makeSym("cdr"), new LObj(Type.Subr, &subrCdr), g_env);
  addToEnv(makeSym("cons"), new LObj(Type.Subr, &subrCons), g_env);
  addToEnv(makeSym("t"), makeSym("t"), g_env);
}

void main() {
  Init();
  string line;
  write("> ");
  while ((line = readln()).length > 0) {
    write(eval(read(line).obj, g_env));
    write("\n> ");
  }
}
