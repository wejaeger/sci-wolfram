**NOTE:** This is a fork form
[TurbulenceChaos](https://github.com/TurbulenceChaos/sci-wolfram). To
support exporting by default, I have changed the default header argument
`(:async . "yes")`{.verbatim} to `(:async . "no")`{.verbatim} and
removed `(:eval . "never-export")`{.verbatim}.

# Features

In addition to the upstream features

-   [x] supports `:var`{.verbatim} header arguments
-   [x] supports inline execution types
    -   Named code block can be called with ...
        `call_<name>[<header rguments>](<arguments>)` ...
    -   A code block can be inline with ...
        `src_<language>[<header arguments>]{<body>}` ...

## Examples

### Convert a `org-table`{.verbatim} using a `:var`{.verbatim} header argument

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
```

### Inline code block

``` example
The integral of $x^2$ is src_wolfram[:exports results]{TeXForm[Integrate[x^2, x]]}.
```

### Inline evaluation of a named code block

``` example
#+NAME: limit
#+begin_src wolfram :exports none
  TeXForm[Limit[Log[b - a + I eta], eta -> 0, Direction -> 1,Assumptions -> {a > 0, b > 0, a > b}]]
#+end_src

The limit of $\lim_{\eta\rightarrow 0^+} \ln (b-a+i\eta)$ is call_limit().
```

### Remove output fields from results using `:post`{.verbatim} header argument

-   Normal result

    ``` example
    #+NAME: integrate
    #+begin_src wolfram :exports none
      TeXForm[Integrate[Log[x], x]]
    #+end_src

    #+RESULTS: integrate
    :results:


    Out[7]//TeXForm= x (\log (x)-1)

    :end:

    #+end_src
    ```

-   Output field removed

    ``` example
    #+NAME: strip
    #+begin_src emacs-lisp :var body="" :results none :exports none
      "Replace all occurrencies of '*Out[0-9+]*=' with empty string."
      (let ((regexp "^.*?Out\\[[0-9]+\\].*?=\w*?"))
        (string-trim(replace-regexp-in-string regexp "" body)))
    #+end_src

    #+NAME: integrate
    #+begin_src wolfram :exports none :post strip(*this*)
      TeXForm[Integrate[Log[x], x]]
    #+end_src

    #+RESULTS: integrate
    :results:
    x (\log (x)-1)
    :end:
    ```

# Installation for `Emacs`

## Prerequisites

-   Free [Wolfram Engine](https://www.wolfram.com/engine/), includes
    `wolframscript` and `wolframplayer` or [WOLFRAM
    MATHEMATICA](https://www.wolfram.com/mathematica/)
-   Optional `LaTex`{.verbatim} for [Previewing LaTeX
    fragments](https://orgmode.org/manual/Previewing-LaTeX-fragments.html)
    and / or for [LaTeX / PDF
    Export](https://emacsdocs.org/docs/org/LaTeX-Export)

## Configuration

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
  (sci-wolfram-formula-type "image"))
```
