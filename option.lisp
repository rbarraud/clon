;;; option.lisp --- Option management for Clon

;; Copyright (C) 2008 Didier Verna

;; Author:        Didier Verna <didier@lrde.epita.fr>
;; Maintainer:    Didier Verna <didier@lrde.epita.fr>
;; Created:       Wed Jul  2 14:26:44 2008
;; Last Revision: Wed Jul  2 14:26:44 2008

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


;; ============================================================================
;; The Option Class
;; ============================================================================

;; #### FIXME: make abstract
(defclass option ()
  ((short-name :documentation "The option's short name."
	       :type (or null string)
	       :reader short-name
	       :initarg :short-name)
   (long-name :documentation "The option's long name."
	      :type (or null string)
	      :reader long-name
	      :initarg :long-name)
   (description :documentation "The option's description."
		:type (or null string)
		:reader description
		:initarg :description)
   (env-var :documentation "The option's associated environment variable."
	    :type (or null string)
	    :reader env-var
	    :initarg :env-var)
   (traversed :documentation "Whether the option's been traversed."
	      :accessor option-traversed
	      :initform nil))
  (:default-initargs
    :short-name nil
    :long-name nil
    :description nil
    :env-var nil)
  (:documentation "The OPTION class.
This class is the base class for all options."))

(defmethod initialize-instance :before
    ((option option) &rest keys &key short-name long-name description env-var)
  "Check consistency of OPTION's initargs."
  (declare (ignore description env-var))
  (unless (or short-name long-name)
    (error "Option ~A: no name given." option))
  ;; #### FIXME: is this really necessary ? What about the day I would like
  ;; to add new syntax like -= etc ?
  ;; Empty long names are forbidden because of the special syntax -- (for
  ;; terminating options). However, it *is* possible to have *one* option with
  ;; an empty (that's different from NIL) short name. This option will just
  ;; appear as `-'. Note that this special option can't appear in a minus or
  ;; plus pack (of course :-). However (and contrary to what I had in my C
  ;; version), it can have a sticky argument if it's not a flag or a boolean.
  ;; In such a case, note that Clon will never detect unknown short options,
  ;; because it will detect the - option with a sticky argument instead.
  (when (and long-name (zerop (length long-name)))
    (error "Option ~A: empty long name." option))
  (when (and short-name long-name (string= short-name long-name))
    (error "Option ~A: short and long names identical." option))
  ;; Short names can't begin with a dash because that would conflict with
  ;; the long name syntax.
  (when (and short-name (string-start short-name "-"))
    (error "Option ~A: short name begins with a dash." option))
  ;; Clon uses only long names, not short ones. But it's preferable to
  ;; reserve the prefix in both cases.
  (unless (cadr (member :internal keys))
    (dolist (name (list short-name long-name))
      (when (and name (or (string= name "clon")
			  (string-start name "clon-"))
	(error "Option ~A: name ~S reserved by Clon." option name))))))


;; -------------------------
;; Name clash check protocol
;; -------------------------

(defmethod check-name-clash ((option1 option) (option2 option))
  "Ensure that there is no name clash between OPTION1 and OPTION2."
  (unless (eq option1 option2)
    (when (and (short-name option1) (short-name option2)
	       (string= (short-name option1) (short-name option2)))
      (error "Options ~A and ~A: indentical short name ~S."
	     option1 option2 (short-name option1)))
    (when (and (long-name option1) (long-name option2)
	       (string= (long-name option1) (long-name option2)))
      (error "Options ~A and ~A: identical Long name ~S."
	     option1 option2 (long-name option1)))))


;; ------------------
;; Traversal protocol
;; ------------------

(defmethod untraverse ((option option))
  "Mark OPTION as untraversed."
  (setf (option-traversed option) nil))


(defmethod next-option ((option option))
  "Return OPTION is it is untraversed (and mark it as traversed)."
  (unless (option-traversed option)
    (setf (option-traversed option) t)
    option))


;; ============================================================================
;; The Option Search protocol
;; ============================================================================

;; #### NOTE: partial matches are not allowed on short options. I didn't think
;; this through, but it would probably make things very difficult wrt sticky
;; options for instance. Think about it again at some point.
;; #### NOTE: also, in the C version, I had a BOOLEAN-ONLY flag which I now
;; think is useless: it was used only for '+' syntax, that is, for short
;; names, and thus requires a full match, as mentioned above. So I don't think
;; that there's any ambiguity.
(defun option-matches (option &key short-name long-name partial-name)
  "Return t if OPTION's names match.
OPTION's names must match either SHORT-NAME, LONG-NAME, or PARTIAL-(long)-NAME."
  (cond (short-name (string= short-name (short-name option)))
	(long-name (string= long-name (long-name option)))
	(partial-name (string-start (long-name option) partial-name))))

(defgeneric option-matches-sticky (option namearg)
  (:documentation "Return t if NAMEARG matches OPTION with a sticky argument."))


;; ============================================================================
;; The Char Packs  Protocol
;; ============================================================================

(defgeneric minus-char (option &optional as-string)
  (:documentation "Return OPTION's minus char, if any.
If AS-STRING is not nil, return a string of that character.")
  (:method ((option option)  &optional as-string)
    "Return OPTION's minus char, if any.
If AS-STRING is not nil, return a string of that character."
    (with-slots (short-name) option
      (when (and short-name (= (length short-name) 1))
	(if as-string
	    short-name
	    (coerce short-name 'character))))))

(defgeneric plus-char (option &optional as-string)
  (:documentation "Return OPTION's plus char, if any.
If AS-STRING is not nil, return a string of that character.")
  (:method ((option option) &optional as-string)
    "Return nil (only switches are plus-packable)."
    nil))


;; ============================================================================
;; The Conversion Protocol
;; ============================================================================

(defgeneric convert-value (option name value)
  (:documentation "Convert command line VALUE for OPTION called with NAME."))

(defgeneric convert-environment (option)
  (:documentation "Get OPTION's value from environment."))


;; ============================================================================
;; The Flag Class
;; ============================================================================

;; A flag can appear in the following forms:

;; -f, --flag                           both names
;; -f                                   short name
;; --flag                               long name

;; #### FIXME: make final
(defclass flag (option)
  ()
  (:documentation "The FLAG class.
This class implements options that don't take any argument."))

(defun make-flag (&rest keys &key short-name long-name description env-var)
  "Make a new flag.
- SHORT-NAME is the option's short name without the dash.
  It defaults to nil.
- LONG-NAME is the option's long name, without the double-dash.
  It defaults to nil.
- DESCRIPTION is the option's description appearing in help strings.
  It defaults to nil."
  (declare (ignore short-name long-name description env-var))
  (apply #'make-instance 'flag keys))

(defun make-internal-flag (long-name description &optional env-var)
  "Make a new internal flag."
  (make-instance 'flag
    :long-name (concatenate 'string "clon-" long-name)
    :description description
    :env-var env-var
    ;; #### FIXME: I'm not quite satisfied with this design here. Other
    ;; possibilities would be to:
    ;; - temporarily set a global variable like *internal*, but /yuck/.
    ;; - temporarily define an additional :before method performing the clon-
    ;; prefix check, but only for user-level options. Cleaner, but obviously
    ;; more costly, although it certainly doesn't matter much.
    :allow-other-keys t
    :internal t))

;; -------------------------
;; Option searching protocol
;; -------------------------

(defmethod option-matches-sticky ((flag flag) namearg)
  "Return nil (flags don't have any argument)."
  nil)


;; -------------------
;; Conversion protocol
;; -------------------

(defmethod convert-value ((flag flag) name value)
  "Retrieve command line status for FLAG.
This method returns two values:
- the first one is :CMDLINE,
- the second one is T if the command line status is OK, or the list
  '(NAME :EXTRA-ARGUMENT VALUE) if FLAG was given an argument."
  ;; We always return :cmdline first because this converter is only called
  ;; when FLAG is actually found on the command line.
  (let ((status (if value (list name :extra-argument value) t)))
    (values :cmdline status)))

(defmethod convert-environment ((flag flag))
  "Retrieve environment status for FLAG.
This method returns :ENV-VAR if FLAG has an associated and existing
environment variable, or nil otherwise."
  ;; #### FIXME: SBCL-specific
  (when (sb-ext:posix-getenv (env-var flag))
    :env-var))


;; ============================================================================
;; The Valued Option Class
;; ============================================================================

;; #### FIXME: we should distinguish between the argument's display name, in
;; itself, and the fact that we want to actually use it. For instance, we
;; might want to display an option as just --color, but still declare that the
;; argument name is CLR so that one day, it is possible to implement escape
;; sequences like %n (for arg name) directly in the help strings. It's even
;; more than that: while the argument display name belongs to the application,
;; the fact that we want to see it probably rather belongs to the user
;; preferences. Like, an option to display help in short form or something.

;; #### FIXME: make abstract
(defclass valued-option (option)
  ((argument-name :documentation "The option's argument display name."
		  :type string
		  :reader argument-name
		  :initarg :argument-name)
   (argument-required-p :documentation "Whether the option's argument is required."
			;; This slot will be initialized afterwards, according
			;; to the :argument-type initarg.
			:reader argument-required-p)
   (default-value :documentation "The option's default value."
		 :type (or null string)
		 :reader default-value
		 :initarg :default-value))
  (:default-initargs
    :argument-name "ARG"
    :argument-type :required
    :default-value nil)
  (:documentation "The VALUED-OPTION class.
This class implements is the base class for options accepting arguments."))

(defmethod initialize-instance :before
    ((option valued-option) &key argument-name argument-type default-value env-var)
  "Check consistency OPTION's value-related initargs."
  (declare (ignore env-var))
  (when (or (null argument-name)
	    (and argument-name (zerop (length argument-name))))
    (error "option ~A: empty argument name." option))
  (unless (or (eq argument-type :required)
	      (eq argument-type :mandatory)
	      (eq argument-type :optional))
    (error "Option ~A: invalid argument type ~S." option argument-type))
  ;; #### FIXME: I can't remember why we don't accept empty default values,
  ;; but right now it feels wrong to me.
  (when (and default-value (zerop (length default-value)))
    (error "option ~A: empty default value." option)))

(defmethod initialize-instance :after
    ((option valued-option) &key argument-name argument-type default-value env-var)
  "Compute values for uninitialized OPTION slots."
  (declare (ignore argument-name default-value env-var))
  (case argument-type
    ((:required :mandatory)
     (setf (slot-value option 'argument-required-p) t))
    (:optional
     (setf (slot-value option 'argument-required-p) nil))))


;; -------------------------
;; Option searching protocol
;; -------------------------

(defmethod option-matches-sticky ((option valued-option) namearg)
  "Return t if NAMEARG matches OPTION with a sticky argument."
  (with-slots (short-name) option
    (when (and short-name (string-start namearg short-name))
      option)))


;; -------------------
;; Char packs protocol
;; -------------------

;; Options with a one-character short name and requiring an argument may
;; appear as the last option in a minus pack. However, we don't make them
;; appear in the usage string.
(defmethod minus-char ((option valued-option) &optional as-string)
  "Return OPTION's minus char, if any.
If AS-STRING is not nil, return a string of that character."
  (unless (argument-required-p option)
    (call-next-method)))


;; ============================================================================
;; The Switch Class
;; ============================================================================

;; #### FIXME: provide :yes-or-no, :on-or-off and :true-or-false special
;; initargs for the argument name, because that's the only ones Clon is able
;; to recognize.

;; #### NOTE: this makes me think that maybe people would like to subclass the
;; switches in order to use other true/false values (I don't know, black/white
;; or something) and have Clon still recognize this as a boolean option.

;; A switch can appear in the following forms:
;;
;;  -(+)b, --boolean[=yes(no)]          both names, optional argument
;;  -(+)b, --boolean=yes(no)            both names, required argument
;;  -(+)b                               short name, whatever the argument
;;  --boolean[=yes(no)]                 long name,  optional argument
;;  --boolean=yes(no)                   long name,  required argument

(defclass switch (valued-option)
  ()
  (:default-initargs
    :argument-name "yes(no)"
    :argument-type :optional
    :default-value nil
    :env-var nil)
  (:documentation "The SWITCH class.
This class implements boolean options."))

(defun make-switch (&rest keys
		    &key short-name long-name description
			 argument-name argument-type
			 default-value env-var)
  "Make a new switch."
  (declare (ignore short-name long-name description
		   argument-name argument-type
		   default-value env-var))
  (apply 'make-instance 'switch keys))

(defun make-internal-switch (long-name description
			     &rest keys
			     &key argument-name argument-type
				  default-value env-var)
  "Make a new internal switch."
  (declare (ignore argument-name argument-type default-value))
  (when env-var
    ;; #### NOTE: this works because the default-initargs option for env-var
    ;; is actually nil, so I don't risk missing a concatenation later.
    (setq env-var (concatenate 'string "CLON_" env-var)))
  (apply 'make-instance 'switch
	 :long-name (concatenate 'string "clon-" long-name)
	 :description description
	 :env-var env-var
	 :allow-other-keys t
	 :internal t
	 (remove-keys keys :env-var)))


;; -------------------------
;; Option searching protocol
;; -------------------------

(defmethod option-matches-sticky ((option switch) namearg)
  "Return nil (switches can't be sticky because of their short syntax)."
  nil)


;; -------------------
;; Char packs protocol
;; -------------------

(defmethod plus-char ((option switch) &optional as-string)
  "Return OPTION's plus char (same as minus char for switches)."
  (minus-char option as-string))


;; -------------------
;; Conversion protocol
;; -------------------

(defmethod convert-value ((option switch) name value)
  "."
  t)

(defmethod convert-environment ((option switch))
  "Return t if an OPTION's associated env var exists."
  ;; #### FIXME: SBCL-specific
  (sb-ext:posix-getenv (env-var option)))


;; ============================================================================
;; The String Option Class
;; ============================================================================

;; A string option can appear in the following formats:
;;
;;   -o, --option=STR                   both names, required argument
;;   -o, --option[=STR]                 both names, optional argument
;;   -o STR                             short name, required argument
;;   -o [STR]                           short name, optional argument
;;   --option=STR                       long name,  required argument
;;   --option[=STR]                     long name,  optional argument

;; #### FIXME: make final
(defclass stropt (valued-option)
  ()
  (:default-initargs :argument-name "STR")
  (:documentation "The STROPT class.
This class implements options the values of which are strings."))

(defun make-stropt (&rest keys
		    &key short-name long-name description
			 argument-name argument-type
			 default-value env-var)
  "Make a new string option."
  (declare (ignore short-name long-name description
		   argument-name argument-type
		   default-value env-var))
  (apply 'make-instance 'stropt keys))

(defun make-internal-stropt (long-name description
			     &rest keys
			     &key argument-name argument-type
				  default-value env-var)
  "Make a new built-in string option."
  (declare (ignore argument-name argument-type default-value))
  (when env-var
    ;; #### NOTE: this works because the default-initargs option for env-var
    ;; is actually nil, so I don't risk missing a concatenation later.
    (setq env-var (concatenate 'string "CLON_" env-var)))
  (apply 'make-instance 'stropt
	 :long-name (concatenate 'string "clon-" long-name)
	 :description description
	 :env-var env-var
	 :allow-other-keys t
	 :internal t
	 (remove-keys keys :env-var)))


;;; option.lisp ends here
