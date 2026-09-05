;;; ob-wolfram.el --- Org-babel for Wolfram language  -*- lexical-binding: t; -*-

;; Copyright (C) 2025-2026 PENG

;; Author: PENG <p.peng01@outlook.com>
;; Created: 20250520
;; Version: 20260812
;; Package-Requires: ((emacs "29.1"))
;; Keywords: languages, processes, tools
;; Homepage: https://github.com/TurbulenceChaos/sci-wolfram

;; This file is not part of GNU Emacs

;;; License

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Org-babel for Wolfram language

;; Installation and usage:
;; Please check README.md.

;; See https://github.com/wejaeger/sci-wolfram for more information.

;;; Code:

(require 'ob)
(require 'ob-ref)
(require 'ob-eval)

(defconst ob-wolfram-session "*Wolfram REPL*")

(defconst ob-wolfram-prompt-regexp "^In\\[[0-9]+\\]:= ")

(defconst ob-wolfram-out-regexp "^.*?Out\\[[0-9]+\\].*?=\w*?")

(defvar ob-wolfram-session-initiated nil)

(defvar ob-wolfram-async-registered nil)

;; org-babel-execute:wolfram stores current execution parameters here
(defvar ob-wolfram-curr-params nil)

;; display inline images in babel result
(defvar ob-wolfram-babel-info nil)

(defcustom ob-wolfram-strip-result t
  "When not `nil', remove all `Out[]' labels in results."
  :group 'sci-wolfram
  :type 'boolean)

;; session evaluate
(defun ob-wolfram-make-repl ()
  "Create wolfram REPL."
  (unless (comint-check-proc ob-wolfram-session)
    (message "Starting Wolfram REPL ...")
    (make-comint-in-buffer "ob-wolfram-session" ob-wolfram-session "wolframscript" nil "-rawterm")
    (with-current-buffer ob-wolfram-session
      (setq-local comint-prompt-regexp ob-wolfram-prompt-regexp))
    (setq ob-wolfram-session-initiated nil)
    (setq ob-wolfram-async-registered nil)))

(defun ob-wolfram-remove-empty-lines (body)
  (substring-no-properties (replace-regexp-in-string "\n[ \t\n]*\n" "\n" body)))

(defun ob-wolfram-postprocess (result inline)
  "Remove all OUT[] labels when 'inline' or custom variable 'org-babel-wolfram-strip-result' is non nil.
  After that, if appropriate, convert tables into elisp lists."
  (let* ((stripped (if (or inline ob-wolfram-strip-result)
		       (string-trim(replace-regexp-in-string ob-wolfram-out-regexp "" result))
		     result)))
    (if (string-prefix-p "[[file" stripped)
	stripped
      (org-babel-reassemble-table
        (org-babel-script-escape stripped)
        (org-babel-pick-name (cdr (assq :colname-names ob-wolfram-curr-params))
  	                     (cdr (assq :colnames ob-wolfram-curr-params)))
        (org-babel-pick-name (cdr (assq :rowname-names ob-wolfram-curr-params))
			     (cdr (assq :rownames ob-wolfram-curr-params)))))))


(defun ob-wolfram-evaluate-session (body &optional inline)
  "Evaluate wolfram babel session."
  (let* ((eoe (format "ob_wolfram_eoe_%s" (org-id-uuid)))
         (code (concat
                (ob-wolfram-remove-empty-lines body)
                (format "\nWriteString[\"stdout\",\"%s\\n\"];\n" eoe)))
         (result (org-babel-comint-with-output
                     (ob-wolfram-session eoe)
                   (comint-send-string ob-wolfram-session code)))
         (return (mapconcat #'identity (cl-remove eoe result :test #'string-match-p))))
    (ob-wolfram-postprocess return inline)))

(defun ob-wolfram-initiate-session ()
  (unless ob-wolfram-session-initiated
    (ob-wolfram-evaluate-session "WriteString[\"stdout\",\"Initiate wolfram babel session\\n\"];\n")
    (setq ob-wolfram-session-initiated t)))

(defun ob-wolfram-babel-get-info ()
  (let ((buf (current-buffer))
        (pos (point)))
    (setq-local ob-wolfram-babel-info (cons buf pos))))

(add-hook 'org-babel-after-execute-hook #'ob-wolfram-babel-get-info)

;; reference:
;; https://github.com/doomemacs/modules/blob/5c89315d5e7138db58e1ef37aaf4c651bb3bcc78/modules/lang/org/config.el#L289
(defun ob-wolfram-display-inline-images-in-babel-result ()
  (unless (or
           ;; ...but not while Emacs is exporting an org buffer (where
           ;; `org-display-inline-images' can be awfully slow).
           (bound-and-true-p org-export-current-backend)
           ;; ...and not while tangling org buffers (which happens in a temp
           ;; buffer where `buffer-file-name' is nil).
           (string-match-p "^ \\*temp" (buffer-name)))
    (save-excursion
      (when-let* ((beg (org-babel-where-is-src-block-result))
                  (end (progn (goto-char beg) (forward-line) (org-babel-result-end))))
        (save-restriction
          (narrow-to-region (min beg end) (max beg end))
          (goto-char (point-min))
          (if (version< "9.8" (org-version))
              (org-link-preview-region nil nil (point-min) (point-max))
            (org-display-inline-images nil nil (point-min) (point-max)))
          (when (and (executable-find "pdflatex")
                     (search-forward "\\begin{equation*}" nil t)
                     (search-forward "\\end{equation*}" nil t))
            (message "Creating LaTeX previews in buffer...")
            (org--latex-preview-region (point-min) (point-max))
            (message "Creating LaTeX previews in buffer... done.")))))))

(add-hook 'org-babel-after-execute-hook
          (lambda ()
            (let* ((info (org-babel-get-src-block-info))
                   (lang (nth 0 info))
                   (params (nth 2 info))
                   (async (cdr (assq :async params))))
              (when (and (string= lang "wolfram")
                         (not (string-match-p "yes" async)))
                (ob-wolfram-display-inline-images-in-babel-result)))))

(defun ob-wolfram-async-chunk-callback (result)
  "Filter applied to results before insertion.
See `org-babel-comint-async-chunk-callback'."
  (prog1
      (ob-wolfram-postprocess result nil)
    (let ((buf (car ob-wolfram-babel-info))
          (pos (cdr ob-wolfram-babel-info)))
      (run-at-time 0 nil (lambda ()
                           (with-current-buffer buf
                             (save-excursion
                               (goto-char pos)
                               (ob-wolfram-display-inline-images-in-babel-result))))))))

;; async evaluate
(defun ob-wolfram-async-register ()
  (let ((buf (current-buffer)))
    (unless (and ob-wolfram-async-registered
                 (eq buf (car ob-wolfram-babel-info)))
      (org-babel-comint-async-register
       ob-wolfram-session
       buf
       "ob_wolfram_async_\\(start\\|end\\)_\\(.+\\)"
       'ob-wolfram-async-chunk-callback
       nil)
      (setq ob-wolfram-async-registered t))))

(defun ob-wolfram-async-evaluate-session (body)
  (ob-wolfram-async-register)
  (let* ((uuid (org-id-uuid))
         (start (format "ob_wolfram_async_start_%s" uuid))
         (end   (format "ob_wolfram_async_end_%s" uuid))
         (code (concat
                (format "WriteString[\"stdout\",\"%s\\n\"]\n" start)
                (ob-wolfram-remove-empty-lines body)
                (format "\nWriteString[\"stdout\",\"%s\\n\"]\n" end))))
    (comint-send-string ob-wolfram-session code)
    uuid))

(defun ob-wolfram-inline-call-p ()
  "Check if current execution type is inline."
  (org-element-type-p (org-element-context) '(inline-babel-call inline-src-block)))

(defun ob-wolfram-replace-drawer (result-params)
  "Replace occurrences of 'drawer' in result-params with empty string."
  (when (member "drawer" result-params)
    (setf (nth (cl-position "drawer" result-params :test 'equal) result-params) ""))
  result-params)

;; org babel execute
;;;###autoload
(defun org-babel-execute:wolfram (body params)
  (setq-local ob-wolfram-curr-params params)
  (ob-wolfram-make-repl)
  (ob-wolfram-initiate-session)

  (let* ((async (cdr (assq :async params)))
	(processed-params (org-babel-process-params params))
        ;; for check if inline
	(inline (ob-wolfram-inline-call-p))

	;; expand the body with `org-babel-expand-body:wolfram'
	(full-body (org-babel-expand-body:wolfram body params processed-params)))

    ;; drawer as result type is not allowed inline
    (when inline (ob-wolfram-replace-drawer (cdr (assq :result-params params))))
    (if (and (string-match-p "yes" async) (not inline))
	(ob-wolfram-async-evaluate-session full-body)
      (ob-wolfram-evaluate-session full-body inline))))

;; This function expands the body of a source code block by doing things like
;; prepending argument definitions to the body, it should be called by the
;; `org-babel-execute:wolfram' function above. Variables get concatenated in
;; the `mapconcat' form, therefore to change the formatting you can edit the
;; `format' form.
(defun org-babel-expand-body:wolfram (body params &optional processed-params)
  "Expand BODY according to PARAMS, return the expanded body."
  (let ((vars (org-babel--get-vars (or processed-params (org-babel-process-params params)))))
    (concat
     (mapconcat ;; define any variables
      (lambda (pair)
        (format "%s = %s;"
                (car pair) (org-babel-wolfram-var-to-wolfram (cdr pair))))
      vars "\n")
     "\n" body "\n")))

(defun org-babel-wolfram-var-to-wolfram (var)
  "Convert an elisp var into a string of wolfram source code
   specifying a var of the same value."
  (if (listp var)
      (concat "{" (mapconcat #'org-babel-wolfram-var-to-wolfram var ", ") "}")
    (format "%S" var)))

(defvar org-babel-default-header-args:wolfram
  `((:session . ,ob-wolfram-session)
    (:async . "no")
    (:results . "value drawer")
    (:display . "text")
    (:comments . "link")
    (:exports . "both"))
  "Default arguments to use when evaluating a source block.")

(provide 'ob-wolfram)
;;; ob-wolfram.el ends here
