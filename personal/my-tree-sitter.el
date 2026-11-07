;;; my-tree-sitter.el --- Install missing grammars on demand -*- lexical-binding: t -*-

(require 'treesit)
(require 'my-vendor)

(defconst my-tree-sitter-repositories
  '((typst "uben0" "tree-sitter-typst")
    (cmake "uyha" "tree-sitter-cmake")
    (rust "tree-sitter" "tree-sitter-rust")
    (tlaplus "tlaplus-community" "tree-sitter-tlaplus"))
  "Vendor repositories for the personal tree-sitter grammars.")

(dolist (entry my-tree-sitter-repositories)
  (add-to-list 'treesit-language-source-alist
               (list (car entry) (apply #'my-vendor-dest (cdr entry)))))

(defun my-tree-sitter-ensure-grammar (language)
  "Install LANGUAGE only when a usable grammar is not already available.
Clone only the requested grammar's source.  Signal an actionable error if
installation fails, so the next startup can retry the missing grammar."
  (unless (treesit-language-available-p language)
    (let ((repository (assq language my-tree-sitter-repositories)))
      (unless repository
        (error "No personal tree-sitter repository for %s" language))
      (apply #'my-vendor-install-git "github.com" (cdr repository))
      (treesit-install-language-grammar language)
      (unless (treesit-language-available-p language)
        (error "Tree-sitter grammar %s is unavailable after installation; check compiler output and retry"
               language)))))

(provide 'my-tree-sitter)
;;; my-tree-sitter.el ends here
