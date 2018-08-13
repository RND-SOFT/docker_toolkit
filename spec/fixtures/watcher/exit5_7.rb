#!/usr/bin/env ruby
require 'docker_toolkit'

STDOUT.sync = true
STDERR.sync = true

# first must exit with 1 and second is terminated(code 0)
# code 7
DockerToolkit::Watcher.new.exec do |w|
  w.add 'terminator.rb', '--sleep', '1', '--exit', '7'
  w.add 'terminator.rb', '--sleep', '14'
end
