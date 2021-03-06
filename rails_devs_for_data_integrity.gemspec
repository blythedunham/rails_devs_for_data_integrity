# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run the gemspec command
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{rails_devs_for_data_integrity}
  s.version = "0.1.4"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Blythe Dunham"]
  s.date = %q{2009-12-17}
  s.description = %q{Rails Devs For Data Integrity catches unique key and foreign key violations
    coming from the  MySQLdatabase and converts them into an error on the
    ActiveRecord object similar to validation errors
    }
  s.email = %q{blythe@snowgiraffe.com}
  s.extra_rdoc_files = [
    "README"
  ]
  s.files = [
    ".gitignore",
     "MIT-LICENSE",
     "README",
     "Rakefile",
     "VERSION",
     "init.rb",
     "install.rb",
     "lib/rails_devs_for_data_integrity.rb",
     "rails_devs_for_data_integrity.gemspec",
     "tasks/rails_devs_for_data_integrity_tasks.rake",
     "test/rails_devs_for_data_integrity_test.rb",
     "test/test_helper.rb",
     "uninstall.rb"
  ]
  s.homepage = %q{http://github.com/blythedunham/rails_devs_for_data_integrity}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{Gracefully handles MySQL unique and foreign key violations by adding an error to the ActiveRecord object}
  s.test_files = [
    "test/rails_devs_for_data_integrity_test.rb",
     "test/test_helper.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<thoughtbot-shoulda>, [">= 0"])
    else
      s.add_dependency(%q<thoughtbot-shoulda>, [">= 0"])
    end
  else
    s.add_dependency(%q<thoughtbot-shoulda>, [">= 0"])
  end
end

