#!/usr/bin/env ruby
require 'docker_toolkit'

STDOUT.sync = true
STDERR.sync = true

# first exit and second is terminated(code 0)
# code 0
DockerToolkit::Watcher.new.exec do |w|
  w.add 'terminator.rb', '--sleep', '2'
  w.add 'terminator.rb', '--sleep', '4', '--term-code', '0'
end
