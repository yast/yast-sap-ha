#
# Rake file
#
# Copyright (c) 2016 SUSE Linux GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#

require "yast/rake"

Yast::Tasks.configuration do |conf|
  conf.skip_license_check << /.*desktop$/
  conf.exclude_files << "pry_debug.rb"
  conf.exclude_files << /.rubocop.yml/
end

desc "Runs unit tests with coverage."
task "coverage" do
  files = Dir["**/test/**/*_{spec,test}.rb"]
  sh "export COVERAGE=1; rspec --color --format doc '#{files.join("' '")}'" unless files.empty?
  sh "xdg-open coverage/index.html"
end
