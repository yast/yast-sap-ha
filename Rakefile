require "yast/rake"

Yast::Tasks.submit_to :sle15sp3

Yast::Tasks.configuration do |conf|
  #lets ignore license check for now
  conf.skip_license_check << /.*/
  conf.exclude_files << /pry_debug.rb/
  conf.exclude_files << /.rubocop.yml/
  conf.exclude_files << /TODO.md/
  conf.exclude_files << /doc/
  conf.exclude_files << /make_package.sh/
  conf.exclude_files << /test/
  conf.exclude_files << /aux/
end
