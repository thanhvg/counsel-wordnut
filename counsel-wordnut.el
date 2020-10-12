;;; counsel-wordnut.el --- Helm interface for WordNet -*- lexical-binding: t; -*-

;; Copyright (C) 2020  Manuel Uberti <manuel.uberti@inventati.org>

;; Author: Manuel Uberti <manuel.uberti@inventati.org>
;; URL: https://github.com/emacs-helm/counsel-wordnut
;; Version: 0.1
;; Package-Requires: ((emacs "24.3"))

;;; Commentary:

;; This package is a combination of two packages already available:
;;
;; - https://github.com/raghavgautam/helm-wordnet
;; - https://github.com/gromnitsky/wordnut
;;
;; See the README for more information.

;;; Code:

(require 'ivy)
(require 'org)

(defgroup counsel-wordnut nil
  "Helm interface for WordNet."
  :group 'convenience)

(defcustom counsel-wordnut-wordnet-location
  (car (file-expand-wildcards "/usr/share/wordnet*"))
  "Location of WordNet index files."
  :type 'string
  :group 'counsel-wordnut)

(defcustom counsel-wordnut-prog "wn"
  "Name of the WordNet program."
  :type 'string
  :group 'counsel-wordnut)

(defconst counsel-wordnut-cmd-options
  '("-over"
    "-synsn" "-synsv" "-synsa" "-synsr"
    "-simsv"
    "-antsn" "-antsv" "-antsa" "-antsr"
    "-famln" "-famlv" "-famla" "-famlr"
    "-hypen" "-hypev"
    "-hypon" "-hypov"
    "-treen" "-treev"
    "-coorn" "-coorv"
    "-derin" "-deriv"
    "-domnn" "-domnv" "-domna" "-domnr"
    "-domtn" "-domtv" "-domta" "-domtr"
    "-subsn"
    "-partn"
    "-membn"
    "-meron"
    "-hmern"
    "-sprtn"
    "-smemn"
    "-ssubn"
    "-holon"
    "-hholn"
    "-entav"
    "-framv"
    "-causv"
    "-perta" "-pertr"
    "-attrn" "-attra")
  "Optional arguments for WordNet command.")

(defconst counsel-wordnut-section-headings
  '("Antonyms" "Synonyms" "Hyponyms" "Troponyms"
    "Meronyms" "Holonyms" "Pertainyms"
    "Member" "Substance" "Part"
    "Attributes" "Derived" "Domain" "Familiarity"
    "Coordinate" "Grep" "Similarity"
    "Entailment" "'Cause To'" "Sample" "Overview of"))

(defun counsel-wordnut--get-wordlist ()
  "Fetch WordNet suggestions and return them as a list."
  (let* ((all-indexes (directory-files
                       counsel-wordnut-wordnet-location t "index\\..*" ))
         (word-indexes (cl-remove-if
                        (lambda (x) (string-match-p "index\\.sense$" x))
                        all-indexes)))
    (cl-mapcan
     (lambda (x)
       (with-temp-buffer
         (insert-file-contents x)
         (goto-char (point-min))
         (while (re-search-forward "^  .*\n\\| .*" nil t)
           (replace-match ""))
         (split-string (buffer-string) "\n" t)))
     word-indexes)))

(defvar counsel-wordnut-all-words nil
  "List of all the words available via WordNet.")

(defun counsel-wordnut--get-candidates ()
  "Initialize `counsel-wordnut-all-words' and return it."
  (unless (bound-and-true-p counsel-wordnut-all-words)
    (setq counsel-wordnut-all-words (counsel-wordnut--get-wordlist)))
  counsel-wordnut-all-words)

(defconst counsel-wordnut-fl-link-cat-re "->\\((.+?)\\)?")
(defconst counsel-wordnut-fl-link-word-sense-re "\\([^,;)>]+#[0-9]+\\)")
(defconst counsel-wordnut-fl-link-re (concat counsel-wordnut-fl-link-cat-re " "
                                          counsel-wordnut-fl-link-word-sense-re))
(defconst counsel-wordnut-font-lock-keywords
  `(("^\\* .+$" . 'org-level-1)
    ("^\\*\\* .+$" . 'org-level-2)
    (,counsel-wordnut-fl-link-cat-re ;; anchor
     ,(concat " " counsel-wordnut-fl-link-word-sense-re) nil nil (1 'link))))

(define-derived-mode counsel-wordnut-mode special-mode "Helm-Wordnut"
  "Major mode interface to WordNet lexical database."
  (setq font-lock-defaults '(counsel-wordnut-font-lock-keywords))
  (let ((org-startup-folded nil))
    (org-mode))
  (visual-line-mode +1))

(defun counsel-wordnut--format-buffer ()
  "Format the entry buffer."
  (let ((inhibit-read-only t)
        (case-fold-search nil))
    ;; Delete the first empty line
    (goto-char (point-min))
    (delete-blank-lines)

    ;; Make headings
    (delete-matching-lines "^ +$" (point-min) (point-max))
    (while (re-search-forward
            (concat "^" (regexp-opt counsel-wordnut-section-headings t)) nil t)
      (replace-match "* \\1"))

    ;; Remove empty entries
    (goto-char (point-min))
    (while (re-search-forward "^\\* .+\n\n\\*" nil t)
      (replace-match "*" t t)
      ;; back over the '*' to remove next matching lines
      (backward-char))

    ;; Make sections
    (goto-char (point-min))
    (while (re-search-forward "^Sense [0-9]+" nil t)
      (replace-match "** \\&"))

    ;; Remove the last empty entry
    (goto-char (point-max))
    (if (re-search-backward "^\\* .+\n\\'" nil t)
        (replace-match "" t t))

    (goto-char (point-min))))

(defun counsel-wordnut--persistent-action (word)
  "Display the meaning of WORD."
  (let ((buf (get-buffer-create "*WordNet*"))
        (options (mapconcat 'identity counsel-wordnut-cmd-options " ")))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (shell-command-to-string
                 (format "%s %s %s" counsel-wordnut-prog word options))))
      (counsel-wordnut--format-buffer)
      (set-buffer-modified-p nil)
      (unless (eq major-mode 'counsel-wordnut-mode) (counsel-wordnut-mode))
      (display-buffer buf)
      (other-window 1))))

;;;###autoload
(defun counsel-wordnut ()
  "Search wordnut with ivy."
  (interactive)
  (ivy-read "Wordnut search: "
            (counsel-wordnut--get-candidates)
            :history 'counsel-wordnut-history
            :require-match t
            :action #'counsel-wordnut--persistent-action
            :caller 'counsel-wordnut))


(provide 'counsel-wordnut)

;;; counsel-wordnut.el ends here
