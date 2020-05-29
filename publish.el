#!/usr/bin/env -S emacs --script
;;; publish --- Publish contents of my blog
;;
;;; Commentary:
;;
;; A massive pile of barely useful of Emacs Lisp configuration for
;; generating HTML files off the `.org' files within the `sources'
;; directory.
;;
;; Huge thanks to the following references:
;;  * https://orgmode.org/worg/org-tutorials/org-publish-html-tutorial.html
;;  * https://vicarie.in/posts/blogging-with-org.html
;;  * https://gitlab.com/to1ne/blog/blob/master/elisp/publish.el#L69-112
;;  * https://www.brautaset.org/articles/2017/blogging-with-org-mode.html
;;; Code:

;; This is where I downloaded ox-rss
(add-to-list 'load-path (expand-file-name "site-lisp" user-emacs-directory))
(require 'package)
(package-initialize)

(require 'org)
(require 'org-element)

(require 'ox)
(require 'ox-publish)
(require 'ox-html)
(require 'ox-rss)

(defun read-file-contents (path)
  "Return contents of `PATH' file as a string."
  (with-temp-buffer
    (insert-file-contents path)
    (buffer-string)))

(defun relative-to-script (path)
  "Return the relative path file at `PATH'."
  (let ((name (or load-file-name "~/src/github.com/clarete/clarete.github.io/")))
    (concat (file-name-directory name) path)))

(defun local-blog-preamble (_plist)
  "Header (or preamble) for the blog."
  (read-file-contents (relative-to-script "layout/navbar.html")))

(defun local-blog-postamble (_plist)
  "Footer (or postamble) for the blog."
  (read-file-contents (relative-to-script "layout/footer.html")))

(defun lc/blog/rss/sitemap-format-entry (entry style project)
  "Format ENTRY for the RSS feed.
ENTRY is a file name.  STYLE is either 'list' or 'tree'.
PROJECT is the current project."
  (cond ((not (directory-name-p entry))
         (let* ((file (org-publish--expand-file-name entry project))
                (title (org-publish-find-title entry project))
                (date (format-time-string "%Y-%m-%d" (org-publish-find-date entry project)))
                (link (concat "blog/" (file-name-sans-extension entry) ".html")))
           (with-temp-buffer
             (insert (format "* %s\n" title))
             (org-set-property "TITLE" title)
             (org-set-property "RSS_PERMALINK" link)
             (org-set-property "DATE" date)
             (org-set-property "PUBDATE" date)
             (insert-file-contents file)
             (buffer-string))))
        ((eq style 'tree)
         ;; Return only last subdir.
         (file-name-nondirectory (directory-file-name entry)))
        (t entry)))

(defun lc/blog/rss/sitemap-function (title list)
  "Generate RSS feed, as a string.

TITLE is the title of the RSS feed.  LIST is an internal
representation for the files to include, as returned by
`org-list-to-lisp'.  PROJECT is the current project."
  (concat "#+TITLE: " title "\n\n"
          (org-list-to-subtree list nil '(:icount "" :istart ""))))

(defun local-blog-rss-publish-to-rss (plist filename pub-dir)
  "Publish RSS with PLIST, only when FILENAME is 'rss.org'.
PUB-DIR is when the output will be placed."
  (if (equal "rss.org" (file-name-nondirectory filename))
      (org-rss-publish-to-rss plist filename pub-dir)))

(defun local-blog-date-subtitle (file project)
  "Format the date found in FILE of PROJECT."
  (format-time-string "%B %d %Y" (org-publish-find-date file project)))

(defun local-blog-publish (plist filename pub-dir)
  "Wrapper function to publish an file to html.

PLIST contains the properties, FILENAME the source file and
PUB-DIR the output directory."
  (let ((project plist))
    (plist-put plist :subtitle
               (local-blog-date-subtitle filename project))
    (org-html-publish-to-html plist filename pub-dir)))

;; This is where we set all the variables and link to all the
;; functions we created so far and finally call `org-publish-project'
;; in the end.

(let ((base-dir (relative-to-script "sources"))
      (pub-dir (relative-to-script "blog")))

  (setq org-export-with-toc nil
        org-export-with-author t
        org-export-with-email nil
        org-export-with-creator nil
        org-export-with-section-numbers nil

        org-html-doctype "html5"
        org-html-link-home "blog/"
        org-html-link-up "/"
        org-html-postamble 'auto
        org-html-divs
        '((preamble  "header" "top")
          (content   "main"   "content")
          (postamble "footer" "postamble"))
        org-html-head
        (concat
         "<link rel=\"stylesheet\" type=\"text/css\" href=\"/media/css/main.css\" />\n"
         "<link href=\"https://fonts.googleapis.com/css2?family=Quicksand:wght@500&display=swap\" rel=\"stylesheet\">\n"
         "<link rel=\"stylesheet\" type=\"text/css\" href=\"https://maxcdn.bootstrapcdn.com/font-awesome/4.6.3/css/font-awesome.min.css\">\n"
         "<link rel=\"icon\" type=\"image/png\" href=\"/media/img/8bitme.png\" />"
         "<link rel=\"alternate\" type=\"application/rss+xml\" href=\"blog/rss.xml\" />")

        ;; Control where the cache is kept, it can be kept in sync
        ;; with .gitignore
        org-publish-timestamp-directory ".cache/"

        ;; List of stuff to be published
        org-publish-project-alist
        `(("blog" :components ("blog-posts" "blog-static" "blog-rss"))
          ("blog-posts"
           ;; I want to style the whole thing myself. Years working
           ;; with CSS MUST pay off at some point!
           :html-head-include-default-style nil
           ; :auto-preamble t
           ;; Functions to insert the partial layout pieces I have
           :html-preamble local-blog-preamble
           :html-postamble local-blog-postamble
           ;; Override the default function to tweak the HTML it
           ;; generates
           :publishing-function local-blog-publish
           ;; The `sources` directory
           :base-directory ,base-dir
           ;; The `blog` directory
           :publishing-directory ,pub-dir
           ;; Configure output options
           :section-numbers nil
           :table-of-contents nil
           :headline-levels 4
           ;; Although all the posts are in the same directory, I
           ;; might have subdirectories with assets
           :recursive t
           :exclude "rss.org"
           :auto-sitemap t
           :sitemap-filename "index.org"
           :sitemap-title "Hi! I'm Lincoln"
           :sitemap-sort-files anti-chronologically
           :sitemap-file-entry-format "%d - %t"
           :with-date t)

          ;; Static asset collection and publishing
          ("blog-static"
           :base-directory ,base-dir
           :publishing-directory ,pub-dir
           :base-extension "css\\|js\\|png\\|jpg\\|gif\\|pdf"
           :recursive t
           :publishing-function org-publish-attachment
           )

          ("blog-rss"
           :base-directory ,base-dir
           :exclude ,(regexp-opt '("rss.org" "index.org" "404.org"))
           :recursive nil
           :base-extension "org"
           :rss-extension "xml"
           :rss-feed-url: "https://clarete.li/blog/rss.xml"
           :html-link-home "https://clarete.li/"
           :html-link-use-abs-url t
           :html-link-org-files-as-html t
           :auto-sitemap t
           :sitemap-filename "rss.org"
           :sitemap-title "Lincoln Clarete"
           :sitemap-style list
           :sitemap-sort-files anti-chronologically
           :sitemap-format-entry lc/blog/rss/sitemap-format-entry
           :sitemap-function lc/blog/rss/sitemap-function
           :publishing-function local-blog-rss-publish-to-rss
           :publishing-directory ,pub-dir
           :section-numbers nil
           :table-of-contents nil))))

;(org-publish-project "blog")

;;; publish ends here
