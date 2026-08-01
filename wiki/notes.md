
# Common Lisp notes

## Function-valued special variables as effect seams

The display module has to perform a real system effect when it changes the brightness:

```lisp
(defun brightness-write (value)
  (uiop:run-program
   (list "brightnessctl" "set" (format nil "~D%" value))))
```

Calling that procedure directly from every operation would make the operations hard to test: a test of `brightness-set`, `brightness-shift`, or `brightness-reset` would change the actual display. The module instead keeps the procedure in a private function-valued special variable:

```lisp
(defparameter *brightness-writer* #'brightness-write)

(defun brightness-set (value)
  (let ((value (alexandria:clamp (round value) 0 100)))
    (funcall *brightness-writer* value)
    (setf *brightness-current* value)
    value))
```

Production code sees the global value, `#'brightness-write`. A test can establish a temporary dynamic binding:

```lisp
(let ((written nil))
  (let ((display::*brightness-writer*
          (lambda (value) (setf written value))))
    (display:brightness-set 120)
    (assert (= written 100))))
```

`defparameter` proclaims `*brightness-writer*` special. Consequently, its `let` binding is dynamic: code called during the execution of the `let` sees the temporary value even though that code is defined elsewhere. When control leaves the `let`, normally or through a non-local exit, the previous binding is visible again.

This is a small form of dependency injection. The dependency is not threaded through every function's parameter list; it is supplied by the dynamic environment.

### Why not `flet`?

`flet` establishes a lexical function binding. It can affect calls appearing textually inside its body, but it cannot reach into the already-defined body of `brightness-set`. A function object stored in a special variable can be dynamically rebound and invoked with `funcall`, which is exactly what is needed here.

Temporarily replacing a symbol's global `symbol-function` would also work in some testing setups, but it mutates process-wide function state and requires careful restoration. A dynamic special binding is local to the dynamic extent of the test and is restored by the language's binding machinery.

### Why `defparameter` for the writer and `defvar` for the cache?

The distinction is intentional:

- Reevaluating `defparameter` assigns its initializer again. Reloading the module therefore restores the production brightness writer.
- Reevaluating `defvar` does not overwrite an existing binding. The cached brightness can therefore survive an ordinary module reload.

The cache remains private. `brightness-current` exposes its value without allowing callers to depend on the variable itself.

### What the tests can establish

With the writer dynamically replaced, tests can verify all the module logic around the external effect:

- Rounding and clamping to the range 0–100;
- Updating and reading the cached value;
- Shifting from the cached value;
- Using 100 as the initial baseline;
- Resetting to full brightness;
- Updating the cache only after the system write succeeds.

These are unit tests. They do not prove that `brightnessctl` is installed, that its command-line interface is compatible, or that the operating system can change the real device. That would require a separate integration test on a suitable machine.

### When this pattern is appropriate

Function-valued special variables work well for ambient policies and effects that many functions may need during one dynamic operation: writers, clocks, random sources, loggers, process runners, hooks, and similar facilities. They are especially convenient in interactive Common Lisp systems because they can be rebound temporarily at the REPL.

They should remain deliberate and few. Excessive use creates invisible inputs and action at a distance. An ordinary function parameter is clearer when only one or two calls need the dependency. A class or generic function is usually a better boundary when behavior varies by persistent object rather than by dynamic context.

## References and precedents

The technique is not peculiar to this configuration. It is built from standard Common Lisp facilities and appears in the language itself and established projects.

### ANSI Common Lisp

- The Common Lisp HyperSpec entry for [`*macroexpand-hook*`](https://www.lispworks.com/documentation/HyperSpec/Body/v_mexp_h.htm) is the closest standard example. The variable contains a function designator; `macroexpand-1` calls it, and the specification's example installs a temporary function with `let` around a call to `macroexpand`. This is the same structural pattern as `*brightness-writer*`.

- The HyperSpec entry for [`*debugger-hook*`](https://www.lispworks.com/documentation/HyperSpec/Body/v_debugg.htm) defines another function-valued special variable. Its example dynamically binds a custom debugger function with `let`. The Common Lisp condition system invokes the currently visible function when entering the debugger.

These are particularly strong precedents: function-valued dynamically bound hooks are part of ANSI Common Lisp, not an implementation-specific convention.

### Serious projects

- [SLIME](https://slime.common-lisp.dev/doc/html/Debugger.html), the standard Emacs development environment for Common Lisp, connects its debugger through `*debugger-hook*`. Its SWANK backend has a `call-with-debugger-hook` operation whose Common Lisp implementation binds `*debugger-hook*` around a `funcall`; see the [SWANK backend source](https://sources.debian.org/src/slime/1%3A20120525-1/swank-backend.lisp/). This is a direct real-world use of the same dynamic substitution mechanism.

- [ASDF](https://asdf.common-lisp.dev/asdf/Components.html), the de facto standard Common Lisp build system, keeps system locators in the special variable `*system-definition-search-functions*` and calls the functions in that list while resolving systems. This is a multi-function extension point rather than a single replaceable writer, but it uses the same combination of first-class functions and special configuration state. The ASDF manual also explicitly recommends parameterization through special variables or hooks when composing optional behavior.

### Books and tutorials

- Peter Seibel's *Practical Common Lisp*, Chapter 6, [“Variables”](https://gigamonkeys.com/book/variables), gives a detailed explanation of dynamic variables. Its `*standard-output*` examples show the essential behavior used here: downstream functions see a temporary `let` binding, and the prior binding is automatically visible afterward.

- Guy L. Steele Jr.'s *Common Lisp: The Language, Second Edition* discusses special declarations and dynamic bindings in [Section 9.2, “Declaration Specifiers”](https://www.cs.cmu.edu/Groups/AI/html/cltl/clm/node105.html). CLtL2 predates the final ANSI standard in some details, but it remains a foundational description of Common Lisp and the design behind special variables.

- David B. Lamkins's *Successful Lisp* covers the reach and lifetime of dynamic bindings in its chapters on [scope and extent](https://dept-info.labri.fr/~strandh/Teaching/MTP/Common/David-Lamkins/contents.html).

- The community-maintained [Common Lisp variables tutorial](https://lisp-lang.org/learn/variables) provides a shorter executable introduction to `defvar`, `defparameter`, and temporary dynamic binding with `let`.

The standard hooks demonstrate the exact function-valued form; the books and tutorials explain the dynamic-binding mechanism on which it rests; and SLIME and ASDF demonstrate that the broader pattern is used in long-lived, production-quality Common Lisp software.
