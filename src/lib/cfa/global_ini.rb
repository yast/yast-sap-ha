# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2018 SUSE Linux GmbH, Nuernberg, Germany.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact SUSE Linux GmbH.
#
# ------------------------------------------------------------------------------
#
# Summary: SUSE High Availability Setup for SAP Products: HANA configuration
# Authors: Ayoub Belarbi <ayoub.belarbi@suse.com>

require "yast"
require "yast2/target_file"

require "cfa/base_model"
require "cfa/matcher"
require "cfa/augeas_parser"

module CFA
  # class representing HANA global.ini config file model.
  # It provides helper to manipulate with the global.ini file.
  # It uses CFA framework and Augeas parser.
  # @see http://www.rubydoc.info/github/config-files-api/config_files_api/CFA/BaseModel
  # @see http://www.rubydoc.info/github/config-files-api/config_files_api/CFA/AugeasParser
  class GlobalIni < BaseModel
    def initialize(path, file_handler: nil)
      super(AugeasParser.new("Sapini.lns"), path, file_handler: file_handler)
    end

    # Replaces or adds a config Tree and subtree.
    # @param [String] tree_key
    # @param [String] subtree_key
    # @param [String] subtree_value
    # @return [void]
    def set_config(tree_key, subtree_key, subtree_value)
      entries = data.select(key_matcher(tree_key))
      if entries.empty?
        entry = AugeasTree.new
        entry[subtree_key] = subtree_value
        data.add(tree_key, entry)
        log.info "Successfully created tree '#{tree_key}' with subtree '#{subtree_key}' and value '#{subtree_value}'"
      else
        entries.each do |e|
          if e[:value] && e[:value][subtree_key]
            e[:value][subtree_key] = subtree_value
            log.info "Successfully modified subtree '#{subtree_key}' in tree '#{tree_key}' with value '#{subtree_value}'"
          else
            e[subtree_key] = subtree_value
            log.info "Successfully created new subtree '#{subtree_key}' in tree '#{tree_key}' with value '#{subtree_value}'"
          end
        end
      end
    end

    # Removes all occurrences of a given tree or subtree.
    # If called with only the tree key (tree key), it will remove all
    # the entire tree
    # @param [String] tree_key
    # @param [String] subtree_key
    # @return [void]
    def delete_config(tree_key, subtree_key = "")
      entries = data.select(key_matcher(tree_key))
      if entries.empty?
        log.info "No tree found with id '#{tree_key}'. Doing nothing."
      elsif subtree_key == ""
        entries.each do |e|
          data.delete(e[:key])
          log.info "Deleting tree '#{tree_key}'"
        end
      else
        entries.each do |e|
          if e[:value] && e[:value][subtree_key]
            e[:value].delete(subtree_key)
            log.info "Successfully deleted subtree '#{subtree_key}' in tree '#{tree_key}'"
          else
            log.info "Didn't found tree '#{tree_key}' with subtree '#{subtree_key}'"
          end
        end
      end
    end

    private

    # Returns matcher for cfa to find entries with given key
    def key_matcher(key)
      Matcher.new { |k, _v| k == key }
    end

  end
end