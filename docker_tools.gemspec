lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'docker_tools/version'

Gem::Specification.new do |spec|
  spec.name          = 'docker_tools'
  spec.version       = DockerTools::VERSION
  spec.authors       = ['Godko Ivan', 'Samoilenko Yuri']
  spec.email         = ['igodko@rnds.pro', 'kinnalru@gmail.com']
  spec.required_ruby_version = '>= 2.0.0'

  spec.summary       = 'Helper classes for work with docker and consul'
  spec.description   = 'Helper classes for work with docker and consul'

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'bin'
  spec.executables   = `git ls-files -- bin/*`.split("\n").map{|f| File.basename(f) }
  spec.require_paths = ['lib']

  # spec.add_dependency 'activesupport'
  # spec.add_dependency 'bigdecimal'
  # spec.add_dependency 'bunny'
  spec.add_dependency 'json'
  # spec.add_dependency 'openssl'
  spec.add_dependency 'diplomat'

  spec.add_development_dependency 'bundler', '~> 1.14'
  spec.add_development_dependency 'rake', '~> 10.0'
end
