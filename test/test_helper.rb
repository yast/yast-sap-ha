# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2016 SUSE Linux GmbH, Nuernberg, Germany.
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
# Summary: SUSE High Availability Setup for SAP Products: test helper
# Authors: Ilya Manyugin <ilya.manyugin@suse.com>

# Set the paths
ENV['Y2DIR'] = File.expand_path('../../src', __FILE__)

if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start
end

require 'yast'

# # Stub a command execution
# def allow_to_execute(cmd)
#   path = Yast::Path.new('.target.bash_output')
#   allow(Yast::SCR).to receive(:Execute).with(path, cmd)
# end

# # Return a full path to the data file
# def file_path(name)
#   File.join(DATA_PATH, name)
# end

# def template(name)
#   File.read(File.join(File.expand_path('data'), File.basename(name)))
# end

# # Check if the Y2LOG contains a message
# def log_contains?(message, search_span = 1)
#   lines = IO.readlines(File.expand_path('~/.y2log'))[-search_span..-1]
#   regex = Regexp.new(message, Regexp::IGNORECASE)
#   lines.any? do |line|
#     regex.match(line)
#   end
# end
