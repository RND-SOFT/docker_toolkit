#!/usr/bin/env ruby
require 'docker_toolkit'

STDOUT.sync = true
STDERR.sync = true

# self must be terminated and second must exit with 2
# code 2
DockerToolkit::Watcher.new.exec do |w|
  w.add 'terminator.rb', '--sleep', '5', '--term-code', '2'
  w.add 'terminator.rb', '--sleep', '5'

  Thread.new do
    sleep 3
    ::Process.kill 'TERM', $PROCESS_ID
  end
end
