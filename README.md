# sci-wolfram

Org-babel support for [WolframScript](https://www.wolfram.com/wolframscript/).

**NOTE:** This is a fork form
[TurbulenceChaos](https://github.com/TurbulenceChaos/sci-wolfram). To
support exporting by default, I have changed the default header argument
`(:async . "yes")` to `(:async . "no")` and
removed `(:eval . "never-export")`.

## Features

In addition to the upstream features

- [x] supports `:var` header arguments
- [x] supports inline execution types
  -   Named code block can be called with ...
      `call_<name>[<header rguments>](<arguments>)` ...
  -   A code block can be inline with ...
      `src_<language>[<header arguments>]{<body>}` ...
- [X] By default remove all `Out[n]=` labels from source block execution results.
      To keep it, set custom variable `ob-wolfram-strip-result` to nil

### Examples

#### Convert a `org-table` using a `:var` header argument

``` example
#+NAME: example-table
| 1 | 4 |
| 2 | 4 |
| 3 | 6 |
| 4 | 8 |
| 7 | 0 |

#+NAME: transpose
#+BEGIN_SRC wolfram :var t=example-table
  1+Transpose@t
#+END_SRC

#+RESULTS: transpose
:results:
| 2 | 3 | 4 | 5 | 8 |
| 5 | 5 | 7 | 9 | 1 |
:end:
```

#### Inline code block

``` example
The integral of $x^2$ is src_wolfram[:exports results]{TeXForm[Integrate[x^2, x]]}.
```

#### Inline evaluation of a named code block

``` example
#+NAME: limit
#+begin_src wolfram :exports none
  TeXForm[Limit[Log[b - a + I eta], eta -> 0, Direction -> 1,Assumptions -> {a > 0, b > 0, a > b}]]
#+end_src

The limit of $\lim_{\eta\rightarrow 0^+} \ln (b-a+i\eta)$ is call_limit().
```

#### Latex output
  ``` example
  #+NAME: integrate
  #+begin_src wolfram :exports none
    TeXForm[Integrate[Log[x], x]]
  #+end_src
  
  #+RESULTS: integrate
  :results:
  x (\log (x)-1)
  :end:
  ```

## Installation for `Emacs`

### Prerequisites

-   Free [Wolfram Engine](https://www.wolfram.com/engine/), includes
    `wolframscript` and `wolframplayer` or [WOLFRAM
    MATHEMATICA](https://www.wolfram.com/mathematica/)
-   Optional `LaTex` for [Previewing LaTeX
    fragments](https://orgmode.org/manual/Previewing-LaTeX-fragments.html)
    and / or for [LaTeX / PDF
    Export](https://emacsdocs.org/docs/org/LaTeX-Export)

### Configuration

``` elisp
;; configure sci-wolfram package
(unless (package-installed-p 'sci-wolfram)
  (package-vc-install "https://github.com/wejaeger/sci-wolfram"))

(use-package sci-wolfram
  :ensure nil
  :defer t
  :mode (("\\.wls\\'" . sci-wolfram-mode)
         ("\\.wl\\'"  . sci-wolfram-mode))
  :config
  (add-hook 'sci-wolfram-mode-hook #'lsp-deferred)
  :custom
  ;;(ob-wolfram-strip-result nil)
  (sci-wolfram-formula-type "image"))
```
