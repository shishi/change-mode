;;; change-mode.el --- minor mode displaying buffer changes with special face

;; Copyright (C) 1998 Richard Sharman

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Commentary:

;; A minor mode: "change-mode".
;;
;; Change-mode has 2 submodes: active and passive.
;; When active,  changes to the buffer are displayed in a different
;; face.  When passive,  any existing displayed changes are saved and
;; new ones recorded but are not displayed differently.
;; Why active and passive?  Having the changes visible can be
;; handy when you want the information but very distracting
;; otherwise.   So, you can keep change-mode in passive state while
;; you make your changes,  toggle it on to active mode to see them,
;; then toggle it back off to avoid distraction.
;;
;; When a change-mode is on (either active or passive) you can
;; go to the next or previous change with change-mode-next-change &
;; change-mode-previous-change.
;;
;; You can "age" different sets of changes by using
;; change-mode-rotate-colours.  This rotates different through a
;; series of different faces,  so you can distinguish "new" changes
;; from "older" changes.
;;
;; You can also use the command compare-with-file to show changes in
;; this file compared with another file (typically the previous
;; version of the file).
;;
;;
;; You can define your own faces using the various set-face-*
;; functions (these can be used interactively).  Or you can evaluate
;; something like this before loading change-mode.el:
;;   (make-face 'change-face)
;;   (set-face-background 'change-face "DarkGoldenrod4")
;;
;; There are currently two hooks run by `change-mode':
;;   change-mode-enable-hook and change-mode-disable-hook
;; which are called from `change-mode' when the mode is being turned on
;; or off respectively.  (The enable hook is not only called when the
;; mode is intially turned on,  it is called each time -- e.g. when
;; toggling between active and passive modes.
;; I'm not happy with this,  and may change this soon.)
;;
;; Example usage:
;;  (defun my-change-mode-enable-hook ()
;;    (or (facep 'change-face)
;;        (progn
;;      ;; stuff to do the very first time change-mode is called
;;      ;; (in any buffer)
;;      (make-face 'change-face)
;;      (set-face-foreground 'change-face "DarkGoldenrod4")
;;      (set-face-background 'change-face "lavender")))
;;    ;; stuff to do each time
;;    (add-hook 'local-write-file-hooks 'change-mode-rotate-colours)
;;  )
;;
;;  (defun my-change-mode-disable-hook ()
;;    (remove-hook 'local-write-file-hooks 'change-mode-rotate-colours)
;;  )
;;
;;  (add-hook 'change-mode-enable-hook 'my-change-mode-enable-hook)
;;  (add-hook 'change-mode-disable-hook 'my-change-mode-disable-hook)

;;           Explciit vs. Implicit
;;

;; Normally, Change mode is turned on explicitly for certain buffers.
;;
;; If you prefer to have it automatically invoked you can do it as
;; follows.
;;
;; 1. Most modes have a major-hook, typically called MODE-hook.  You
;; can use add-hook to call change-mode.
;;
;;   Example:
;;      (add-hook 'c-mode-hook 'change-mode)
;;
;;  If you want to make it start up in passive mode (regardless of the
;;  setting of change-mode-initial-state):
;;      (add-hook 'emacs-lisp-mode-hook
;;          (lambda ()
;;            (change-mode 'passive)))
;;
;; However, this cannot be done for Fundamental-mode for there is no
;; such hook.
;;
;; 2. You can use the function `global-change-mode'
;; This function, which is fashioned after the way `global-font-lock'
;; works,  toggles on or off global change mode.
;; When activated, it turns on change mode in all "suitable" existings
;; buffers and will turn it on in new "suitable" buffers to be
;; created.
;;
;; A buffer's "suitability" is determined by variable
;; `change-mode-global-modes',  as follows.  If the variable is
;; * nil  -- then no buffers are suitable;
;; * a function -- this function is called and the result is used.  As
;;   an example,  if the value is 'buffer-file-name then all buffers
;;   who are visiting files are suitable, but others (like dired
;;   buffers) are not;
;; * a list -- then if the buufer is suitable iff its mode is in the
;;   list,  exccept if the first element is nil in which case the test
;;   is reversed (i.e. it is a list of unsuitable modes).
;; * Otherwise,  the buffer is suitable if its name does not begin with
;;   ' ' or '*' and (buffer-file-name) returns true.
;;
;; It is recommended to set it to a list of specific modes,  e.g.
;;   (setq change-mode-global-modes
;;      '(c-mode emacs-lisp-mode text-mode fundamental-mode))
;; While the default cases works fairly reasonably,  it does include
;; several cases that probably aren't wanted (e.g. mail buffers).

;;     Possible bindings:
;; (global-set-key '[C-right] 'change-mode-next-change)
;; (global-set-key '[C-left]  'change-mode-previous-change)
;;
;;     Other interactive functions (which could be bound if desired):
;; change-mode
;; change-mode-remove-change-face
;; change-mode-rotate-colours
;; compare-with-file

;;     Possible autoloads:
;;
;; (autoload 'change-mode "change-mode"
;;   "Show changes in a distincive face" t)
;;
;; (autoload 'change-mode-next-change "change-mode" "\
;; Move to the beginning of the next change, if minor-mode
;; change-mode is in effect." t)
;;
;; (autoload 'change-mode-previous-change "change-mode" "\
;; Move to the beginning of the previous change, if minor-mode
;; change-mode is in effect." t)
;;
;; (autoload 'compare-with-file "change-mode"
;;   "Compare this saved buffer with a file,  showing differences
;; in a distinctive face" t)
;;
;; (autoload 'change-mode-remove-change-face "change-mode" "\
;; Remove the change face from the region.  This allows you to
;; manually remove highlighting from uninteresting changes." t)
;;
;; (autoload (quote change-mode-rotate-colours) "change-mode" "\
;; Rotate the faces used by change-mode.  Current changes will be
;; display in the face described by the first element of
;; change-mode-face-list,  those (older) changes will be shown in the
;; face descriebd by the second element,  and so on.   Very old changes
;; reamin in the last face in the list.
;;
;; You can automatically rotate colours when the buffer is saved
;; by adding this to local-write-file-hooks,  by evaling (in the
;; buffer to be saved):
;; \(add-hook 'local-write-file-hooks 'change-mode-rotate-colours)
;; " t nil)
;;
;; (autoload (quote global-change-mode) "change-mode" "\
;; Turn on or off global Change mode."
;; `change-mode-global-modes'." t nil)

;;; Bugs:

;; - the next-change and previous-change functions are too literal;
;;   they should find the next "real" change,  in other treat
;;   consecutive changes as one.

;;; To do (maybe),  notes, ...

;; - having different faces for deletion and non-deletion: is it
;;   really worth the hassle?
;; - should have better hooks:  when should they be run?
;; - compare-with-file should allow RCS files - e.g. nice to be able
;;   to say show changes compared with version 2.1.
;; - Maybe we should have compare-with-buffer as well.  (When I tried
;;   a while back I ran into a problem with ediff-buffers-internal.)

;;; History:

;; R Sharman (rshar...@magma.ca) Feb 1998:
;; - initial release.
;; Ray Nickson (nick...@mcs.vuw.ac.nz) 20 Feb 1998:
;; - deleting text causes immediately surrounding characters to be highlighted.
;; - change-mode is only active for the current buffer.
;; Jari Aalto <jari.aa...@ntc.nokia.com> Mar 1998
;; - fixes for byte compile errors
;; - use eval-and-compile for autoload
;; Marijn Ros <J.M....@fys.ruu.nl> Mar 98
;; - suggested turning it on by default
;; R Sharman (rshar...@magma.ca) Mar 1998:
;; - active/passive added
;; - allow different faces for deletions and additions/changes
;; - allow changes to be hidden (using 'saved-face attribute)
;; - added compare-with-file
;; - coexist with font-lock-mode  {now obsolete}
;; June 98
;; - try and not clobber other faces if change-mode-dont-clober-other-faces
;;   (this is now obsolete)
;; - allow initial default state to be passive or active
;; - allow rotation of old changes to different faces
;; - added hooks
;; - added automatic stuff
;; Adrian Bridgett <adrian.bridg...@zetnet.co.uk> June 98:
;; - make hide/unhide not affect the buffer modified status
;; July 98
;; - change-mode-rotate-colours: only if in change-mode!
;; - changed meaning of ARG for global-change-mode
;; July 98
;; compare-with-file:  clear buffer modification status,  return to
;;    original point.  Complain if read-only.  Force change-mode-active.
;; Eric Ludlam <za...@gnu.org> Suggested using overlays.
;; July 98
;; - Used overlays instead of properties.  Didn't work with undo.
;; - Used overlays for display and text properties to record changes.
;; - compare-with-file now works with read-only buffers.

;;; Code:

;; ====== defvars of variables that the user may which to change =========

;; Face information: How the changes appear.

;; Defaults for face: red foreground, no change to background,
;; and underlined if a change is because of a deletion.
;; Note: underlining is helpful in that is shows up changes in white
;; space.  However,  having it set for non-delete changes can be
;; annoying because all indentation on inserts gets underlined (which
;; can look pretty ugly!).

;; These can be set before loading change-mode,  or
;; changed on the fly,  by evaling something like this:
;; (set-face-foreground 'change-face "green")
;; (set-face-underline-p 'change-face t)

(defvar change-face-foreground "red"
  "Foreground colour of changes other than deletions.
If set to nil,  the foreground is not changed.")
(defvar change-face-background nil
  "Background colour of changes other than deletions.
If set to nil,  the background is not changed."
)
(defvar change-face-underlined nil
"If non nil, changes other than deletions are underlined.")

(defvar change-delete-face-foreground "red"
"Foreground colour of changes due to deletions.
If set to nil,  the foreground is not changed.")

(defvar change-delete-face-background nil
"Background colour of changes due to deletions.
If set to nil,  the background is not changed.")

;; This looks pretty ugly, actually...  Maybe it should default to nil.
(defvar change-delete-face-underlined t
"If non nil, changes due to deletions are underlined.")

(defvar change-mode-face-list nil
  "*A list of faces used when rotataing changes.

Normally this list is created from `change-mode-colours' when needed.
However, you can set this variable to any list of faces.  You will
have to do this if you want faces which don't just differ from
`change-face' by the foreground colour.  Otherwise,  this list will be
constructed when needed from  `change-mode-colours'.

The face names should begin with \"change-\" so that they will be
hidden and restored when toggling between active and passive modes.")

;; A (not very good) default list of colours to rotate through.
;; This assumes that normal characters are roughly black foreeground
;; on a ligh background:
;;
(defvar change-mode-colours '(
                              "blue"
                              "firebrick"
                              "green4"
                              "DarkOrchid"
                              "chocolate4"
                              "NavyBlue")
  "*Colours used by `change-mode-rotate-colours'.
The current change will be displayed in the first element of this
list,  the next older will be in the second element etc." )

;; If you invoke change-mode with no argument,  should it start in
;; active or passive mode?
;;
(defvar change-mode-initial-state 'active
  "*What state (active or passive) change-mode should start in.

This is used when change-mode is called with no argument.
This variable must be set to either 'active or 'passive.")

(defvar change-mode-global-initial-state 'passive
  "*What state  global-change-mode should start in.

This is used if global-change-mode is called with no argument.
This variable must be set to either 'active or 'passive.")

;; The strings displayed in the mode-line for the minor mode:
(defvar change-mode-active-string " Change-active"
  "The string used when Change mode is in the active state.")
(defvar change-mode-passive-string " Change-passive"
  "The string used when Change mode is in the passive state.")

;; I think the test of the buffer name is not necessary and
;; may be removed soon.
(defvar change-mode-global-modes t
  "Used to determine whether a buffer is suitable for global Change mode.

nil means no buffers are suitable for global-change-mode.
A function means that function is called:  if it returns non-nil the
buffer is suitable.
A list is a list of modes for which it is suitable,  or a list whose
first element is 'not followed by modes which are not suitable.
t means the buffer is suitable if its name does not begin with ' ' or
'*' and the buffer has a filename.

Examples:
        (c-mode c++-mode)
means that Change mode is turned on for buffers in C and C++ modes only."
)

(defvar change-mode-debug nil)

(defvar global-change-mode nil)

(defvar change-mode-global-changes-existing-buffers nil
  "*If non-nil togging global Change mode affects existing buffers.

Normally,  global-change-mode means affects only new buffers (to be
created).  However, if change-mode-global-changes-existing-buffers is
non-nil then turning on global-change-mode will turn on change-mode in
suitable buffers and turning the mode off will remove it from existing
buffers." )

;; ========================================================================

;; These shouldn't be changed!

(defvar change-mode nil)
(defvar change-mode-list nil)

(defvar change-mode-string " ??")
(or (assq 'change-mode minor-mode-alist)
    (setq minor-mode-alist
          (cons '(change-mode change-mode-string) minor-mode-alist)
          ))
(make-variable-buffer-local 'change-mode)
(make-variable-buffer-local 'change-mode-string)

(eval-and-compile
  ;;  For compare-with-file
  (defvar ediff-number-of-differences)
  (autoload 'ediff-setup                "ediff")
  ;; we still get a byte-compile warning so this probably isn't
  ;; what's needed...
  (if (string-match "^19\." emacs-version)
      (autoload 'ediff-eval-in-buffer "ediff")
    (autoload 'ediff-with-current-buffer "ediff"))
  (autoload 'ediff-really-quit          "ediff")
  (autoload 'ediff-make-fine-diffs      "ediff")
  (autoload 'ediff-get-fine-diff-vector "ediff")
  (autoload 'ediff-get-difference       "ediff")
  )

;; See change-mode-set-face-on-change for why undo is adviced.
(eval-when-compile (require 'advice))
(defvar undo-in-progress nil) ;; only undo should change this!
(defadvice undo (around record-this-is-an-undo activate)
  (let ((undo-in-progress t))
    ad-do-it))

;;; Functions...

(defun change-mode-map-changes  (func &optional start-position end-position)
  "Call function FUNC for each region used by change-mode."
  ;; if start-position is nil, (point-min) is used
  ;; if end-position is nil, (point-max) is used
  ;; func is called with 3 params: property start stop
  (interactive)
  (let (
         (start (or start-position (point-min)))
         (limit (or end-position (point-max)))
         prop end
         )
    (while (and start (< start limit))
      (setq prop (get-text-property start 'change))
      (setq end (text-property-not-all start limit 'change prop))
      (if prop
          (funcall func prop start (or end limit)))
      (setq start end)
      )))

(defun change-mode-display-changes (&optional beg end)
  "Dispplay face information for Change mode.

An overlay containing a change face is added,  from the information
in the text property of type change.

This is the opposite of change-mode-hide-changes."
  (change-mode-map-changes 'change-mode-make-ov beg end))

(defun change-mode-make-ov (prop start end)
  ;; for the region make change overlays corresponding to
  ;; the text property 'change
  (let ((ov (make-overlay start end))
        face
        )
    (or prop
        (error "change-mode-make-ov: prop is nil"))
    (if (eq prop 'change-delete)
        (setq face 'change-delete-face)
      (setq face (nth 1 (member prop change-mode-list))))
    (if face
        (progn
          ;; We must mark the face,  that is the purpose of the overlay
          (overlay-put ov 'face face)
          ;; I don't think we need to set evaporate since we should
          ;; be controlling them!
          (overlay-put ov 'evaporate t)
          ;; We set the change property so we can tell this is one
          ;; of our overlays (so we don't delete someone else's).
          (overlay-put ov 'change t)
          )
      (error "change-mode-make-ov: no face for prop: %s" prop)
      )
    ))

(defun change-mode-hide-changes (&optional beg end)
  "Remove face information for Change mode.

The overlay containing the face is removed,  but the text property
containing the change information is retained.

This is the opposite of change-mode-display-changes."
  (let (
         (start (or beg (point-min)))
         (limit (or end (point-max)))
         p ov
         )
    (setq p (overlays-in start limit))
    (while p
      ;; don't delete the overlay if it isn't ours!
      (if (overlay-get (car p) 'change)
          (delete-overlay (car p)))
      (setq p (cdr p))
      )))

(defun change-mode-fixup (beg end)
  "Fix change overlays in region beg .. end.

Ensure the overlays agree with the changes as determined from
the text properties of type 'change ."
  ;; Remove or alter overlays in region beg..end
  (let (p ov ov-start ov-end
         props q)
    (setq p (overlays-in beg end))
    ;; temp for debugging:
    (or (eq change-mode 'active)
        (error "change-mode-fixup called but change mode not active"))
    (while p
      (setq ov (car p))
      (setq ov-start (overlay-start ov))
      (setq ov-end (overlay-end ov))
      (if (< ov-start beg)
          (progn
            (move-overlay ov ov-start beg)
            (if (> ov-end end)
                (progn
                  (setq props (overlay-properties ov))
                  (setq ov (make-overlay end ov-end))
                  (while props
                    (overlay-put ov (car props)(car (cdr props)))
                    (setq props (cdr (cdr props))))
                  )
              )
            )
        (if (> ov-end end)
            (move-overlay ov end ov-end)
          (delete-overlay ov)
          ))
      (setq p (cdr p)))
    (change-mode-display-changes beg end)
    ))

;;;###autoload
(defun change-mode-remove-change-face (beg end)
  "Remove the change face from the region.
This allows you to manually remove highlighting from uninteresting changes."
  (interactive "r")
  (let ((after-change-functions nil))
    (remove-text-properties beg end  '(change nil))
    (change-mode-fixup beg end)))

(defun change-mode-set-face-on-change (beg end leng-before
                                           &optional no-proerty-change)
  "Record changes and optionally display them in a distinctive face.
Change-mode adds this function to the `after-change-functions' hook."
  ;;
  ;; This function is called by the `after-change-functions' hook, which
  ;; is how we are notified when text is changed.
  ;; It is also called from `compare-with-file'.
  ;;
  ;; We do NOT want to simply do this if this is an undo command, because
  ;; otherwise an undone change shows up as changed.  While the
  ;; properties are restored by undo,  we must fixup the overlay.
  ;; How do we know if this is an undo?  We can't use `this-command'
  ;; because `undo' sets `this-command' to t (and some other commands do
  ;; also).  So we advise the function `undo'.
  (save-match-data
    (let ((beg-decr 1) (end-incr 1)
          (type 'change)
          ;; (face 'change-face)
          old)
      (if undo-in-progress
          (if (eq change-mode 'active)
              (change-mode-fixup beg end))
        ;; This test hopefully isn't needed,  since it probably was put in
        ;; because of the bug about not keeping the hook properly local.
        ;;   ((string-match "^[ *]"  (buffer-name))
        ;;    nil) ;; (message "ignoring this in minibuffer!"))
        ;; (setq face 'change-face)
        (if (and (= beg end) (> leng-before 0))
            ;; deletion
            (progn
              ;; The eolp and bolp tests are a kludge!  But they prevent rather
              ;; nasty looking displays when deleting text at the end
              ;; of line,  such as normal corrections as one is typing and
              ;; immediately makes a corrections,  and when deleting first
              ;; character of a line.

;;;           (if (= leng-before 1)
;;;               (if (eolp)
;;;                   (setq beg-decr 0 end-incr 0)
;;;                 (if (bolp)
;;;                     (setq beg-decr 0))))
;;;           (setq beg (max (- beg beg-decr) (point-min)))
              (setq end (min (+ end end-incr) (point-max)))
              ;; (setq face 'change-delete-face)
              (setq type 'change-delete)
              )
          ;; Not a deletion.
          ;; Most of the time the following is not necessary,  but
          ;; if the current text was marked as a deletion then
          ;; the old overlay is still in effect:
          ;; Because we marked some text as deleted,  if we add text
          ;; clear then this deletion marking.
          (if (eq (get-text-property end 'change) 'change-delete)
              (progn
                (remove-text-properties end (+ end 1) '(change nil))
                (remove-text-properties end (+ end 1) '(change nil))
                (put-text-property end (+ end 1) 'change 'change)
                (if (eq change-mode 'active)
                    (change-mode-fixup beg (+ end 1))))))
        (or no-proerty-change
                (put-text-property beg end 'change type))
        (if (or (eq change-mode 'active) no-proerty-change)
            (change-mode-make-ov type beg end))
        ))))

(defun change-mode-make-faces ()
  "Define the faces for change-mode if not already done so."
  ;; This code moved from  change-mode  so that the faces can
  ;; be used from elsewhere, without invoking change-mode.
  (or (facep 'change-face)
      (progn
        (make-face 'change-face)
        (set-face-foreground 'change-face change-face-foreground)
        (set-face-underline-p 'change-face change-face-underlined)))
  (or (facep 'change-delete-face)
      (progn
        (make-face 'change-delete-face)
        (set-face-foreground 'change-delete-face change-delete-face-foreground)
        (set-face-underline-p 'change-delete-face change-delete-face-underlined))))

(defun change-mode-set (value)
  "Turn on change-mode for this buffer."
  (setq change-mode value)
  (remove-hook 'after-change-functions 'change-mode-set-face-on-change t)
  ;; (message (format "change-mode is now %s" (prin1-to-string change-mode)))
  (change-mode-make-list)
  (if (eq change-mode 'active)
      (progn
        (setq change-mode-string change-mode-active-string)
        ;; replace any change-face-hidden with change-face
        (or buffer-read-only
            (change-mode-display-changes)))
    ;; mode is passive
    (setq change-mode-string change-mode-passive-string)
    (or buffer-read-only
        (change-mode-hide-changes))
    )
  (force-mode-line-update)
  (make-local-hook 'after-change-functions)
  (add-hook 'after-change-functions 'change-mode-set-face-on-change nil t)
  )

(defun change-mode-clear ()
  "Remove change-mode for this buffer.
This removes all saved change information."
  (if buffer-read-only
      (message "Cannot remove changes, buffer is in read-only mode.")
    (remove-hook 'after-change-functions 'change-mode-set-face-on-change t)
    (let ((after-change-functions nil))
      (change-mode-hide-changes)
      (change-mode-map-changes
       '(lambda (prop start stop)
          (remove-text-properties start stop '(change nil))))
      )
    (setq change-mode nil)
    (force-mode-line-update)
    ;; If we type:  C-u -1 M-x change-mode
    ;; we want to turn it off,  but change-mode-post-command-hook
    ;; runs and that turns it back on!
    (remove-hook 'post-command-hook 'change-mode-post-command-hook)
    ))

;;;###autoload
(defun change-mode (&optional arg)
  "Toggle (or initially set) Change mode.

Without an argument,
  if change-mode is not enabled, then enable it (to either active
      or passive as determined by variable change-mode-initial-state);
  otherwise, toggle between active and passive states.

With an argument,
  if just C-u  or  a positive argument,  set state to active;
  with a zero argument,  set state to passive;
  with a negative argument,  disable change-mode completely.

Active state -  means changes are shown in a distinctive face.
Passive state - means changes are kept and new ones recorded but are
                not displayed in a different face.

Functions:
\\[change-mode-next-change] - move point to beginning of next change
\\[change-mode-previous-change] - move point to beginning of previous change
\\[compare-with-file] - mark text as changed by comparing this buffer
against the contents of a file
\\[change-mode-remove-change-face] - remove the change face from the
region
\\[change-mode-rotate-colours] - rotate different \"ages\" of changes
through various faces.

Hook variables:
change-mode-enable-hook - when called entering active or passive state
change-mode-disable-hook - when turning off change-mode.
"
  (interactive "P")
  (if window-system
      (let ((new-change-mode
             (cond
              ((null arg)
               ;; no arg => toggle (or set to active initially)
               (if change-mode
                   (if (eq change-mode 'active) 'passive 'active)
                 change-mode-initial-state))
              ;; an argument is given
              ((eq arg 'active)
               'active)
              ((eq arg  'passive)
               'passive)
              ((> (prefix-numeric-value arg) 0)
               'active)
              ((< (prefix-numeric-value arg) 0)
               nil)
              (t
               'passive)
              )))
        (if new-change-mode
            ;; mode is turned on -- but may be passive
            (progn
              (run-hooks 'change-mode-enable-hook)
              (change-mode-set new-change-mode))
          ;; mode is turned off
          (run-hooks 'change-mode-disable-hook)
          (change-mode-clear))
        )
    (message "Change-mode only works when using a window system"))
  )

;;;###autoload
(defun change-mode-next-change ()
  "Move to the beginning of the next change, if in Change mode."
  (interactive)
  (let ( (start (point))
         prop )
    (setq prop (get-text-property (point) 'change))
    (if prop
        ;; we are in a change
        (setq start (next-single-property-change (point) 'change))
      )
    (if start
        (setq start (next-single-property-change start 'change)))
    (if start
        (goto-char start)
      (message "no next change"))
    ))

;;;###autoload
(defun change-mode-previous-change ()
  "Move to the beginning of the previous change, if in Change mode."
  (interactive)
  (let ( (start (point)) (prop nil) )
    (or (bobp)
        (setq prop (get-text-property (1- (point)) 'change)))
    (if prop
        ;; we are in a change
        (setq start (previous-single-property-change (point) 'change)))
    (if start
        (setq start (previous-single-property-change start 'change)))
    ;; special handling for the case where (point-min) is a change
    (if start
        (setq start (or (previous-single-property-change start 'change)
                        (if (get-text-property (point-min) 'change)
                            (point-min)))))
    (if start
        (goto-char start)
      (message "no previous change"))
    ))

;; ========================================================================

(defun change-mode-make-list (&optional force)
  "Construct change-mode-list and change-mode-face-list."
  ;; Constructs change-mode-face-list if necessary,
  ;; and change-mode-list always:
  ;; Maybe this should always be called when rotating a face
  ;; so we pick up any changes?
  (if (or (null change-mode-face-list)  ; Don't do it if it
          force) ; already exists unless FORCE non-nil.
      (let ((p change-mode-colours)
            (n 1) name)
        (setq change-mode-face-list nil)
        (change-mode-make-faces)        ;; ensure change-face is valid!
        (while p
          (setq name (intern (format "change-face-%d" n)))
          (copy-face 'change-face name)
          (set-face-foreground name (car p))
          (setq change-mode-face-list
                (append change-mode-face-list (list name)))
          (setq p (cdr p))
          (setq n (1+ n)))))
  (setq change-mode-list (list 'change 'change-face))
  (let ((p change-mode-face-list)
        (n 1)
        last-category last-face)
    (while p
      (setq last-category (intern (format "change-%d" n)))
      ;; (setq last-face (intern (format "change-face-%d" n)))
      (setq last-face (car p))
      (setq change-mode-list
            (append change-mode-list
                    (list last-category last-face)))
      (setq p (cdr p))
      (setq n (1+ n)))
    (setq change-mode-list
          (append change-mode-list
                  (list last-category last-face)))
    ))

(defun change-mode-bump-change (prop start end)
  "Increment (age) the change mode text property of type change."
  (let ( new-prop )
    (if (eq prop 'change-delete)
        (setq new-prop (nth 2 change-mode-list))
      (setq new-prop (nth 2 (member prop change-mode-list)))
      )
    (if prop
        (put-text-property start end 'change new-prop)
      (message "%d-%d unknown property %s not changed" start end prop)
      )
    ))

;;;###autoload
(defun change-mode-rotate-colours ()
  "Rotate the faces used by Change mode.

Current changes will be display in the face described by the first
element of change-mode-face-list, those (older) changes will be shown
in the face descriebd by the second element, and so on.  Very old
changes remain shown in the last face in the list.

You can automatically rotate colours when the buffer is saved
by adding this to local-write-file-hooks,  by evaling (in the
buffer to be saved):
  (add-hook 'local-write-file-hooks 'change-mode-rotate-colours)
"
  ;; You can do this:
  ;; (add-hook 'local-write-file-hooks 'change-mode-rotate-colours)
  (interactive)
  ;; (if (eq change-mode 'active))
  (let ((after-change-functions nil))
    ;; ensure change-mode-list is made and up to date
    (change-mode-make-list)
    ;; remove our existing overlays
    (change-mode-hide-changes)
    ;; for each change text property, increment it
    (change-mode-map-changes 'change-mode-bump-change)
    ;; and display them all if active
    (if (eq change-mode 'active)
        (change-mode-display-changes))
    )
  ;; This always returns nil so it is safe to use in
  ;; local-write-file-hook
  nil)

;; ========================================================================
;; Comparing with an existing file.
;; This uses ediff to find the differences.

;;;###autoload
(defun compare-with-file (file-b)
  "Compare this buffer with a file.

The current buffer must be an unmodified buffer visiting a file.

If the backup filename exists, it is used as the default
when called interactively.

If a buffer is visiting the file being compared with, it also will
have its differences highlighted.  Otherwise, the file is read in
temporarily but the buffer is deleted.

If either file is read-only,  differences are highlighted but because
no text proerties are changed you cannot use `change-mode-next-change'
nor `change-mode-previous-change'."
  (interactive (list
              (read-file-name
               "File to compare with? " ;; prompt
               ""                     ;; directory
               nil                      ;; default
               'yes                     ;; must exist
               (let ((f (make-backup-file-name
                         (or (buffer-file-name (current-buffer))
                             (error "no file for this buffer")))))
                 (if (file-exists-p f) f ""))
               )))
  (let* ((buf-a (current-buffer))
         (buf-a-read-only buffer-read-only)
         (orig-pos (point))
         (file-a (buffer-file-name))
         (existing-buf (get-file-buffer file-b))
         (buf-b (or existing-buf
                    (find-file-noselect file-b)))
         (buf-b-read-only (save-excursion
                            (set-buffer buf-b)
                            buffer-read-only))
         xy  xx yy p q
         a-start a-end len-a
         b-start b-end len-b
         )
    ;; We use the fact that the buffer is not marked modified at the
    ;; end where we clear its modified status
    (if (buffer-modified-p buf-a)
        (if (y-or-n-p (format "OK to save %s?  " file-a))
                       (save-buffer buf-a)
          (error "Buffer must be saved before comparing with a file.")))
    (if (and existing-buf (buffer-modified-p buf-b))
        (if (y-or-n-p (format "OK to save %s?  " file-b))
                       (save-buffer buf-b)
          (error "Cannot compare with a file in an unsaved buffer.")))
    (change-mode 'active)
    (if existing-buf (save-excursion
                       (set-buffer buf-b)
                       (change-mode 'active)))
    (save-window-excursion
      (setq xy (change-mode-get-diff-info buf-a file-a buf-b file-b)))
    (setq xx (car xy))
    (setq p xx)
    (setq yy (car (cdr xy)))
    (setq q yy)
    (change-mode-make-list)
    (while p
      (setq a-start (nth 0 (car p)))
      (setq a-end (nth 1 (car p)))
      (setq b-start (nth 0 (car q)))
      (setq b-end (nth 1 (car q)))
      (setq len-a (- a-end a-start))
      (setq len-b (- b-end b-start))
      (set-buffer buf-a)
      ;; (message (format "%d %d %d"  a-start a-end len-b))
      (change-mode-set-face-on-change a-start a-end len-b buf-a-read-only)
      (set-buffer-modified-p nil)
      (goto-char orig-pos)
      (if existing-buf
          (progn
            (set-buffer buf-b)
            (change-mode-set-face-on-change b-start b-end len-a
                                            buf-b-read-only)
            ))
      (setq p (cdr p))
      (setq q (cdr q))
      )
    (if existing-buf
        (set-buffer-modified-p nil)
      (kill-buffer buf-b))
    ))

(defun change-mode-get-diff-info (buf-a file-a buf-b file-b)
  (let ((e nil) x y)   ;; e is set by function change-mode-get-diff-list-hk
    (ediff-setup buf-a file-a buf-b file-b
               nil nil   ; buf-c file-C
               'change-mode-get-diff-list-hk
               (list (cons 'ediff-job-name 'something))
               )
    (if (fboundp 'ediff-with-current-buffer)
        (ediff-with-current-buffer e (ediff-really-quit nil))
      ;; 19.34 equivalent to ediff-with-current-buffer:
      (ediff-eval-in-buffer e (ediff-really-quit nil)))
    (list x y)))

(defun change-mode-get-diff-list-hk ()
  ;; (message "change-mode-get-diff-list-hk started")
  ;; x and y are dynamically bound by change-mode-get-diff-info
  ;; which calls this function as a hook
  (defvar x)  ;; placate the byte-compiler
  (defvar y)
  (setq  e (current-buffer))
  (let ((n 0) extent p va vb a b)
    (setq  x nil  y nil)    ;; x and y are bound by change-mode-get-diff-info
    (while (< n ediff-number-of-differences)
      ;; (message (format "diff # %d of %d" n ediff-number-of-differences))
      ;;
      (ediff-make-fine-diffs n)
      (setq va (ediff-get-fine-diff-vector n 'A))
      ;; va is a vector if there are fine differences
      (if va
          (setq a (append va nil))
        ;; if not,  get the unrefined difference
        (setq va (ediff-get-difference n 'A))
        (setq a (list (elt va 0)))
        )
      ;; a list a list
      (setq p a)
      (while p
        (setq extent (list (overlay-start (car p))
                           (overlay-end (car p))))
        (setq p (cdr p))
        (setq x (append x (list extent) ))
        );; while p
      ;;
      (setq vb (ediff-get-fine-diff-vector n 'B))
      ;; vb is a vector
      (if vb
          (setq b (append vb nil))
        ;; if not,  get the unrefined difference
        (setq vb (ediff-get-difference n 'B))
        (setq b (list (elt vb 0)))
        )
      ;; b list a list
      (setq p b)
      (while p
        (setq extent (list (overlay-start (car p))
                           (overlay-end (car p))))
        (setq p (cdr p))
        (setq y (append y (list extent) ))
        );; while p
      ;;
      (setq n (1+ n))
      );; while
    ;; ediff-quit doesn't work here.
    ;; No point in returning a value, since this is a hook function.
    ))

;; ======================= automatic stuff ==============

;; Default t case - buffer name is probably redunndant?  Why not just
;; use (buffer-file-name) ?

(defun change-mode-major-mode-hook ()
  (add-hook 'post-command-hook 'change-mode-post-command-hook)
  )

(defun change-mode-post-command-hook ()
  ;; This is called after changeing a major mode, but also after each
  ;; M-x command,  in which case the current buffer is a minibuffer.
  ;; In that case, do not act on it here,  but don't turn it off
  ;; either,  we will get called here again soon-after.
  ;; Also,  don't enable it for other special buffers.
  (if (string-match "^[ *]"  (buffer-name))
      nil ;; (message "ignoring this post-command-hook")
    (remove-hook 'post-command-hook 'change-mode-post-command-hook)
    ;; The following check isn't necessary,  since
    ;; change-mode-turn-on-maybe makes this check too.
    (or change-mode     ;; don't turn it on if it already is
        (change-mode-turn-on-maybe change-mode-global-initial-state))
    ))

;;;###autoload
(defun global-change-mode (&optional arg)
  "Turn on or off global Change mode.

When called interactively:
- if no prefix, toggle global Change mode on or off
- if called with a positive prefix (or just C-u) turn it on in active mode
- if called with a zero prefix  turn it on in passive mode
- if called with a negative prefix turn it off

When called from a program:
- if ARG is nil or omitted, turn it off
- if ARG is 'active,  turn it on in active mode
- if ARG is 'passive, turn it on in passive mode
- otherwise just turn it on

When global change mode is enabled, change mode is turned on for
future \"suitable\" buffers (and for \"suitable\" existing buffers if
variable change-mode-global-changes-existing-buffers is non-nil).
\"Suitablity\" is determined by variable change-mode-global-modes."

  (interactive
   (list
    (cond
     ((null current-prefix-arg)
      ;; no arg => toggle it on/off
      (setq global-change-mode (not global-change-mode)))
     ;; positive interactive arg - turn it on as active
     ((> (prefix-numeric-value current-prefix-arg) 0)
      (setq global-change-mode t)
      'active)
     ;; zero interactive arg - turn it on as passive
     ((= (prefix-numeric-value current-prefix-arg) 0)
      (setq global-change-mode t)
      'passive)
     ;; negative interactive arg - turn it off
     (t
      (setq global-change-mode nil)
      nil))))

  (if arg
      (progn
        (if (eq arg 'active)
            (setq change-mode-global-initial-state 'active)
          (if (eq arg  'passive)
              (setq change-mode-global-initial-state 'passive)))
        (setq global-change-mode t)
        (message "turning ON global change mode in %s state"
                 change-mode-global-initial-state)
        (add-hook 'change-major-mode-hook 'change-mode-major-mode-hook)
        (if change-mode-global-changes-existing-buffers
            (change-mode-update-all-buffers change-mode-global-initial-state))
        )
    (message "turning OFF global change mode")
    (remove-hook 'change-major-mode-hook 'change-mode-major-mode-hook)
    (remove-hook 'post-command-hook
                 'change-mode-post-command-hook)
    (if change-mode-global-changes-existing-buffers
        (change-mode-update-all-buffers nil))
    )
  )

(defun change-mode-turn-on-maybe (value)
  "Turn on change-mode if it is appropriate for this buffer.

A buffer is appropriate for Change mode if:
- the buffer is not a special buffer (one whose name begins with '*'
  or ' ')
- the buffer's mode is suitable as per variable change-mode-global-modes
- change-mode is not already on for this buffer.

This function is called from change-mode-update-all-buffers
from global-change-mode when turning on global change mode.
"
  (or change-mode                       ; do nothing if already on
      (if
          (cond
           ((null change-mode-global-modes)
            nil)
           ;; Unfortunately, functionp isn't in emacs 19.34
           ;; ((functionp change-mode-global-modes)
           ;;    (funcall change-mode-global-modes))
           ((or
             (and (fboundp 'functionp)
                  (functionp change-mode-global-modes))
             (and (symbolp change-mode-global-modes)
                  (fboundp change-mode-global-modes)))
            (funcall change-mode-global-modes))
            ((listp change-mode-global-modes)
             (if (eq (car-safe change-mode-global-modes) 'not)
                 (not (memq major-mode (cdr change-mode-global-modes)))
               (memq major-mode change-mode-global-modes)))
            (t
             (and
              (not (string-match "^[ *]"  (buffer-name)))
              (buffer-file-name))
             ))
          (change-mode-set value))
      ))

(defun change-mode-turn-off-maybe ()
  (if change-mode
      (change-mode-clear)))

(defun change-mode-update-all-buffers (value)
  ;; with-current-buffer is not in emacs-19.34
  (if (boundp 'with-current-buffer)
      (mapcar
       (function (lambda (buffer)
                   (with-current-buffer buffer
                     (if value
                         (change-mode-turn-on-maybe value)
                       (change-mode-turn-off-maybe))
                     )))
       (buffer-list))
    ;; I hope this does the same thing...
    (save-excursion
      (mapcar
       (function (lambda (buffer)
                   (set-buffer buffer)
                   (if value
                       (change-mode-turn-on-maybe value)
                     (change-mode-turn-off-maybe))
                   ))
       (buffer-list)))
    ))

;; ===================== debug ==================
;; For debug & test:
(defun change-mode-debug-show (&optional beg end)
  (interactive)
  (message "--- change-mode-show ---")
  (change-mode-map-changes '(lambda (prop start end)
                              (message "%d-%d: %s" start end prop)
                              )
                           beg end
                           ))

;; ================== end of debug ===============

(provide 'change-mode)
;;; change-mode.el ends here