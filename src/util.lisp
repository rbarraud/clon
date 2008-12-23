;;; util.lisp --- General utilities for Clon

;; Copyright (C) 2008 Didier Verna

;; Author:        Didier Verna <didier@lrde.epita.fr>
;; Maintainer:    Didier Verna <didier@lrde.epita.fr>
;; Created:       Mon Jun 30 17:23:36 2008
;; Last Revision: Wed Nov  5 09:23:14 2008

;; This file is part of Clon.

;; Clon is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2 of the License, or
;; (at your option) any later version.

;; Clon is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program; if not, write to the Free Software
;; Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.


;;; Commentary:

;; Contents management by FCM version 0.1.


;;; Code:

(in-package :clon)
(in-readtable :clon)


;; ==========================================================================
;; Miscellaneous Auxiliary Routines
;; ==========================================================================

(defmacro econd (&body clauses)
  "Like COND, but signal an error if no clause evaluates to t."
  `(cond ,@(append clauses
		   '((t (error "Fell out of ECOND clauses."))))))

(defmacro endpush (object place)
  "Like push, but at the end."
  `(setf ,place (nconc ,place (list ,object))))

(defmacro maybe-push (object place)
  "Like push, but only if OBJECT is non-nil."
  `(when ,object (push ,object ,place)))

(defmacro accumulate ((initial-value) &body body)
  "Accumulate BODY forms in a list beginning with INITIAL-VALUE.
INITIAL-VALUE is not evaluated. BODY forms are accumulated only when their
value is non-nil.
If nothing to accumulate, then return nil instead of the list of
INITIAL-VALUE."
  (let ((place (gensym "place"))
	(initial-place (gensym "initial-place")))
    `(let* ((,place (list ',initial-value))
	    (,initial-place ,place))
      ,@(mapcar (lambda (body-form)
		  `(maybe-push ,body-form ,place))
		body)
      (when (not (eq ,initial-place ,place))
	(nreverse ,place)))))

(defun beginning-of-string-p (beginning string &optional ignore-case)
  "Check that STRING starts with BEGINNING.
If IGNORE-CASE, well, ignore case."
  (let ((length (length beginning)))
    (and (>= (length string) length)
	 (funcall (if ignore-case #'string-equal #'string=)
		  beginning string :end2 length))))

(defun closest-match (match list &key ignore-case (key #'identity))
  "Return the LIST element closest to MATCH, or nil.
If IGNORE-CASE, well, ignore case.
KEY should provide a way to get a string from each LIST element."
  (let ((match-length (length match))
	(shortest-distance most-positive-fixnum)
	closest-match)
    (dolist (elt list)
      (let ((elt-string (funcall key elt))
	    distance)
	(when (and (beginning-of-string-p match elt-string ignore-case)
		   (< (setq distance (- (length elt-string) match-length))
		      shortest-distance))
	  (setq shortest-distance distance)
	  (setq closest-match elt))))
    closest-match))

(defun complete-string (beginning complete)
  "Complete BEGINNING with the rest of COMPLETE in parentheses.
For instance, completing 'he' with 'help' will produce 'he(lp)'."
  (assert (beginning-of-string-p beginning complete))
  (assert (not (string= beginning complete)))
  (concatenate 'string beginning "(" (subseq complete (length beginning)) ")"))

(defun list-to-string (list &key (key #'identity))
  "Return a coma-separated string of all LIST elements.
KEY should provide a way to get a string from each LIST element."
  (reduce (lambda (str1 str2) (concatenate 'string str1 ", " str2))
	  list
	  :key key))

(defun symbol-to-string (symbol)
  "Return SYMBOL name downcased."
  (string-downcase (symbol-name symbol)))

(defun symbols-to-string (symbols)
  "Return a coma-separated list of downcased SYMBOLS names."
  (list-to-string symbols :key #'symbol-to-string))



;; ==========================================================================
;; Key-Value Pairs Manipulation
;; ==========================================================================

(defun select-keys (keys &rest selected)
  "Return a new property list from KEYS with only SELECTED ones."
  (loop :for key :in keys :by #'cddr
	:for val :in (cdr keys) :by #'cddr
	:when (member key selected)
	:nconc (list key val)))

(defun remove-keys (keys &rest removed)
  "Return a new property list from KEYS without REMOVED ones."
  (loop :for key :in keys :by #'cddr
	:for val :in (cdr keys) :by #'cddr
	:unless (member key removed)
	:nconc (list key val)))



;; ==========================================================================
;; CLOS Utility Routines
;; ==========================================================================

(defclass abstract-class (standard-class)
  ()
  (:documentation "The ABSTRACT-CLASS class.
This is the meta-class for abstract classes."))

(defmacro defabstract (class super-classes slots &rest options)
  "Like DEFCLASS, but define an abstract class."
  (when (assoc :metaclass options)
    (error "Defining abstract class ~S: explicit meta-class option." class))
  `(defclass ,class ,super-classes ,slots ,@options
    (:metaclass abstract-class)))

(defmethod make-instance ((class abstract-class) &rest initargs)
  (declare (ignore initargs))
  (error "Instanciating class ~S: is abstract." (class-name class)))

;; #### PORTME.
(defmethod sb-mop:validate-superclass
    ((class abstract-class) (superclass standard-class))
  t)

;; #### PORTME.
(defmethod sb-mop:validate-superclass
    ((class standard-class) (superclass abstract-class))
  t)



;; ==========================================================================
;; Stream to file-stream conversion (thanks Nikodemus !)
;; ==========================================================================

;; #### WARNING: remove that after upgrading SBCL
(declaim (sb-ext:muffle-conditions sb-ext:compiler-note))
(defgeneric stream-file-stream (stream &optional direction)
  (:documentation "Convert STREAM to a file-stream.")
  (:method ((stream file-stream) &optional direction)
    (declare (ignore direction))
    stream)
  (:method ((stream synonym-stream) &optional direction)
    (declare (ignore direction))
    (stream-file-stream (symbol-value (synonym-stream-symbol stream))))
  (:method ((stream two-way-stream) &optional direction)
    (stream-file-stream
	(case direction
	  (:input (two-way-stream-input-stream stream))
	  (:output (two-way-stream-output-stream stream))
	  (otherwise
	   (error "Cannot extract file-stream from TWO-WAY-STREAM ~A:
invalid direction: ~S"
		  stream direction)))
	direction)))



;; ==========================================================================
;; Wrappers around non ANSI features
;; ==========================================================================

(defun quit (status)
  "Quit the Lisp environment"
  ;; #### PORTME.
  (sb-ext:quit :unix-status status))


;;; util.lisp ends here
