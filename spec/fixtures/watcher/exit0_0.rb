#!/usr/bin/env ruby
require 'docker_toolkit'

STDOUT.sync = true
STDERR.sync = true

#first and second exits normaly
#code 0
DockerToolkit::Watcher.new.exec do |w|
  w.add *%w(terminator.rb --sleep 2)
  w.add *%w(terminator.rb --sleep 2)
end





