# reflow

## Contents

- [Description](#description)
- [Installation](#installation)
- [Usage](#usage)
- [Configuration](#configuration)
- [Requirements](#requirements)

## Description

Reflow is a small Emacs Lisp package that automatically re-flows
hard-wrapped text in Info and Helpful buffers. It joins wrapped lines inside
paragraphs that appear to be natural-language text while avoiding code
blocks, headings and other structures that should remain untouched.

## Installation

```elisp
(use-package reflow
  ;; Load from a local copy
  :load-path "/path/to/reflow.el"
  ;; ... or clone from the GitHub
  ;; :vc (:url "https://github.com/sonofjon/reflow.el"
  ;;          :rev :newest)
  :after (helpful info)
  :commands (reflow-info-buffer
             reflow-helpful-buffer
             reflow-info-mode
             reflow-helpful-mode)
  :config
  ;; Enable automatic reflowing of Info buffers
  (reflow-info-mode 1)
  ;; Enable automatic reflowing of Helpful buffers
  (reflow-helpful-mode 1))
```

## Usage

- M-x reflow-info-buffer — Re-flow the current Info node.
- M-x reflow-helpful-buffer — Re-flow the current Helpful buffer.
- M-x reflow-info-mode — Global minor mode to automatically re-flow
  Info nodes.
- M-x reflow-helpful-mode — Global minor mode to automatically re-flow
  Helpful buffers.

## Configuration

The package exposes a few internal variables that control which paragraphs
are not considered for re-flowing, such as `reflow-forbidden-regexps-info`
and `reflow-forbidden-regexps-helpful`. These are not exposed as `defcustom`
yet; if you need finer control, edit the source or request additional
customization options.

## Requirements

- Emacs 26.1 or newer
- [helpful](https://github.com/Wilfred/helpful) (installed from MELPA) — a better \*help\* buffer
- Info (built-in) — Info documentation reader
