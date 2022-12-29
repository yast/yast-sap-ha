require "yast/rake"

Yast::Tasks.submit_to :sle15sp3

Yast::Tasks.configuration do |conf|
  conf.skip_license_check << /.*desktop$/
  conf.skip_license_check << /.*erb$/
  conf.skip_license_check << /.*yaml$/
  conf.skip_license_check << /.*yml$/
  conf.skip_license_check << /.*html$/
  conf.skip_license_check << /.*rpmlintrc$/
  conf.skip_license_check << /pry_debug.rb/
  conf.skip_license_check << /make_package.sh/
  conf.skip_license_check << /srhook.py.tmpl/
  conf.skip_license_check << /collect_logs.sh/
  conf.skip_license_check << /aux/
  conf.exclude_files << /pry_debug.rb/
  conf.exclude_files << /.rubocop.yml/
  conf.exclude_files << /TODO.md/
  conf.exclude_files << /doc/
  conf.exclude_files << /make_package.sh/
  conf.exclude_files << /test/
  conf.exclude_files << /aux/
end

