;;; reflow.el --- Re-flow buffers -*- lexical-binding: t; -*-
;;
;; Author: Andreas Jonsson <ajdev8@gmail.com>
;; Maintainer: Andreas Jonsson <ajdev8@gmail.com>
;; Version: 0.1
;; Package-Requires: ((emacs "26.1"))
;; Keywords: convenience, docs
;;
;;; Commentary:
;;
;; Utilities to automatically re-flow text in Info and Helpful buffers.
;;
;; Provides:
;;  - reflow-info-buffer
;;  - reflow-helpful-buffer
;;  - reflow-info-mode
;;  - reflow-helpful-mode
;;
;; Usage:
;;
;;   (use-package reflow
;;     :load-path "/path/to/reflow"
;;     :commands (reflow-info-buffer
;;                reflow-helpful-buffer
;;                reflow-info-mode
;;                reflow-helpful-mode)
;;     :config
;;     ;; Enable automatic reflowing of Info buffers
;;     (reflow-info-mode 1)
;;     ;; Enable automatic reflowing of Helpful buffers
;;     (reflow-helpful-mode 1))
;;
;;; Code:

(defconst reflow-bullet-regexp
  "^[ \t]*\\(•\\|[*]\\|[(]?[0-9]+[.)]\\|[(]?[a-z][.)]\\)[ \t]"
  "Regular expression matching a bullet or numbered-list marker at the start of a line.")

(defconst reflow-forbidden-regexps-info
  '(
    "^[ \t]*[-+*=—]\\{2,\\}"            ; Multiple markers
    ;; "^[ \t]*\\(;;\\|[(][^‘A-Z]\\)"   ; Elisp code and comments
    "^[ \t]*\\(;;\\|[(][^‘A-Z]*$\\)"    ; Elisp code and comments
    "^[ \t]\\{8,\\}"                    ; Excessive indentation
    )
  "Forbidden line regexps for Info buffers.")

(defconst reflow-forbidden-regexps-helpful
  '(
    "^[ \t]*\\(Signature\\|Documentation\\|References\\|Debugging\\|Source Code\\|Symbol Properties\\)[ \t]*$"
    "^[ \t]*\\(;;\\|[(][^‘A-Z]*$\\)"    ; Elisp code and comments
    )
  "Forbidden line regexps for helpful buffers.")

(defun reflow-count-matches (regexp text)
  "Return the number of non-overlapping occurrences of REGEXP in TEXT."
  (let ((count 0)
        (pos 0))
    (while (string-match regexp text pos)
      (setq count (1+ count))
      (setq pos (1+ (match-beginning 0))))
    count))

;; TODO
;;   Convert this to a defconst regexp for consistency with other regexps above
;;   Use `sentence-end' instead
(defun reflow-sentence-match-p (text)
  "Return t if TEXT starts and ends like a sentence."
  (and (string-match-p "^[[:upper:]]" text)   ; “‘
       (string-match-p "[.:)\"”]$" text)))   ; ”

(defun reflow-structure-match-p (beg end)
  "Return t if the text between BEG and END has a paragraph-like structure.

A text block is considered to have a paragraph-like structure if the
text meets either of the following two criteria:

  1. The text start with an uppercase letter and end with a dot.

  2. If the text starts with a bullet or numbered-list marker, then
     there must be no more than one such marker, and, the remaining text
     must be a sentence or series of sentences.

This function uses `reflow-bullet-regexp' to detect bullet markers."
  (let* ((text (string-trim (buffer-substring-no-properties beg end)))
         (candidate (if (string-match-p reflow-bullet-regexp text)
                        (and (<= (reflow-count-matches reflow-bullet-regexp text) 1)
                             (string-trim (replace-regexp-in-string reflow-bullet-regexp "" text)))
                      text)))
    (and candidate (reflow-sentence-match-p candidate))))

(defun reflow-forbidden-match-p (beg end regexps)
  "Return t if any of the REGEXPS matches any line between BEG and END."
  (save-excursion
    (goto-char beg)
    (let ((found nil))
      (while (and (< (point) end) (not found))
        (let ((line (thing-at-point 'line t)))
          (dolist (rx regexps)
            (when (string-match-p rx line)
              (setq found t))))
        (forward-line 1))
      found)))

;; Unused function
(defun reflow-paragraph-match-p (beg end regexp mode)
  "Return t if the paragraph between BEG and END satisfies a regexp check.
REGEXP is applied to each line.  MODE determines how the results are combined:
  'all  : returns t if every line matches REGEXP
  'any  : returns t if at least one line matches REGEXP
  'none : returns t if no line matches REGEXP"
  (save-excursion
    (goto-char beg)
    (cond
     ((eq mode 'all)
      (catch 'fail
        (while (< (point) end)
          (let ((line (thing-at-point 'line t)))
            ;; Debug
            (message "\nLine:\n%s" line)
            (unless (string-match-p regexp line)
              (progn
                ;; Debug
                (message "No match: %s" regexp)
                (throw 'fail nil))))
          (forward-line 1))
        t))
     ((eq mode 'any)
      (catch 'match
        (while (< (point) end)
          (let ((line (thing-at-point 'line t)))
            ;; Debug
            (message "\nLine:\n%s" line)
            (when (string-match-p regexp line)
              (progn
                ;; Debug
                (message "Line matched: %s" regexp)
                (throw 'match t))))
          (forward-line 1))
        nil))
     ((eq mode 'none)
      ;; 'none is just the inverse of 'any
      (not (reflow-paragraph-match-p beg end regexp 'any)))
     (t
      (error "Invalid mode: %s (must be 'all, 'any, or 'none)" mode)))))

;; Optional wrappers for convenience:
(defun reflow-paragraph-match-all-p (beg end regexp)
  "Return t if every line in the paragraph between BEG and END matches REGEXP."
  (reflow-paragraph-match-p beg end regexp 'all))

(defun reflow-paragraph-match-any-p (beg end regexp)
  "Return t if any line in the paragraph between BEG and END matches REGEXP."
  (reflow-paragraph-match-p beg end regexp 'any))

(defun reflow-paragraph-match-none-p (beg end regexp)
  "Return t if no line in the paragraph between BEG and END matches REGEXP."
  (reflow-paragraph-match-p beg end regexp 'none))

(defun reflow-join-lines-in-region (beg end)
  "Join lines between BEG and END.
The function removes hard line breaks (newline characters) that split a
text into separate lines."
  (save-excursion
    (goto-char beg)
    ;; Debug
    ;; (insert "<Start>")
    (while (re-search-forward "\\([^ \n]\\)[ \t]*\n[ \t]*\\([^ \n]\\)" end t)
      (replace-match "\\1 \\2" nil nil))))

(defun reflow-buffer (forbidden-regexps)
  "Re-flow the current buffer by joining lines in each paragraph.
For paragraphs to be re-flowed, individual lines must not match any
regexp in FORBIDDEN-REGEXPS, and a structure criteria must be met.  See
`reflow-structure-match-p'."
  (with-demoted-errors "Error re-flowing text: %S"
    (let ((inhibit-read-only t))
      (save-excursion
        (goto-char (point-min))
        (while (< (point) (point-max))
          (let ((p-beg (point)))
            (forward-paragraph)
            (let ((p-end (point)))
              ;; Debug:
              ;; (message "Paragraph from %d to %d:\n%s" p-beg p-end
              ;;          (buffer-substring-no-properties p-beg p-end))
              (unless (reflow-forbidden-match-p p-beg p-end forbidden-regexps)
                (when (reflow-structure-match-p p-beg p-end)
                  (reflow-join-lines-in-region p-beg p-end))))
            (when (< (point) (point-max))
              (forward-char 1))))))))

;;;###autoload
(defun reflow-info-buffer ()
  "Re-flow the current Info node, joining lines where appropriate.
Uses a common first-line rule (first non-blank character must be uppercase)
and Info-specific forbidden regexps."
  (interactive)
  (reflow-buffer reflow-forbidden-regexps-info))

(defun reflow-info-buffer-advice (orig-fun &rest args)
  "Advice function to re-flow an Info node after it is selected.
ORIG-FUN should be `Info-select-node'."
  (let ((result (apply orig-fun args)))
    (reflow-info-buffer)
    result))

;;;###autoload
(define-minor-mode reflow-info-mode
  "Minor mode that toggles automatic re-flowing of Info nodes.
When enabled, `Info-select-node' is advised so that after a node is
selected, the buffer’s text is re-flowed."
  :init-value nil
  :global t
  :lighter (:eval (when (derived-mode-p 'Info-mode) " RF"))
  (if reflow-info-mode
      (advice-add 'Info-select-node :around #'reflow-info-buffer-advice)
    (advice-remove 'Info-select-node #'reflow-info-buffer-advice)))

;;;###autoload
(defun reflow-helpful-buffer ()
  "Re-flow the current Helpful buffer, joining lines where appropriate.
Uses a common first-line rule (first non-blank character must be
uppercase) and Helpful-specific forbidden regexps."
  (interactive)
  (reflow-buffer reflow-forbidden-regexps-helpful))

(defun reflow-helpful-buffer-advice (orig-fun &rest args)
  "Advice function to re-flow a Helpful buffer.
ORIG-FUN should be `helpful-update'."
  (let ((result (apply orig-fun args)))
    (reflow-helpful-buffer)
    result))

;;;###autoload
(define-minor-mode reflow-helpful-mode
  "Minor mode that toggles automatic re-flowing of Helpful buffers.
When enabled, `helpful-update' is advised so that after a Helpful buffer
is updated, the buffer’s text is re-flowed."
  :init-value nil
  :global t
  :lighter (:eval (when (derived-mode-p 'helpful-mode) " RF"))
  (if reflow-helpful-mode
      (advice-add 'helpful-update :around #'reflow-helpful-buffer-advice)
    (advice-remove 'helpful-update #'reflow-helpful-buffer-advice)))

(provide 'reflow)
