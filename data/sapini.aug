(* 
 ------------------------------------------------------------------------------
 Copyright (c) 2016 SUSE Linux GmbH, Nuernberg, Germany.

 This program is free software; you can redistribute it and/or modify it under
 the terms of version 2 of the GNU General Public License as published by the
 Free Software Foundation.

 This program is distributed in the hope that it will be useful, but WITHOUT
 ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

 You should have received a copy of the GNU General Public License along with
 this program; if not, contact SUSE Linux GmbH.

 ------------------------------------------------------------------------------

 Author: Josef Reidinger <jreidinger@suse.cz>
 
 SAP INI file module for Augeas
 
 SAP HANA global.ini is a standard INI File, with some keys 
 (system replication, etc.) consisting of a single digit.
*)


module SAPINI =
  autoload xfm

(************************************************************************
 * INI File settings
 *
 * global.ini only supports "# as commentary and "=" as separator
 *************************************************************************)
let comment    = IniFile.comment "#" "#"
let sep        = IniFile.sep "=" "="


(************************************************************************
 *                        ENTRY
 * entry use a bit modified regexp for keys
 *************************************************************************)
let entry   = IniFile.indented_entry /[A-Za-z0-9][A-Za-z0-9._-]*/ sep comment


(************************************************************************
 *                        RECORD
 * global.ini uses standard INI File records
 *************************************************************************)
let title   = IniFile.indented_title IniFile.record_re
let record  = IniFile.record title entry


let lns     = IniFile.lns record comment

let filter = (incl "/hana/shared/[A-Z]{3}/global/hdb/custom/config/global.ini")

let xfm = transform lns filter