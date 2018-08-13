#!/usr/bin/env ruby
require 'docker_toolkit'

STDOUT.sync = true
STDERR.sync = true

# self must be terminated and all must exit with 0
# code 0
DockerToolkit::Watcher.new.exec do |w|
  w.add 'terminator.rb', '--sleep', '5'
  w.add 'terminator.rb', '--sleep', '5'

  Thread.new do
    sleep 3
    ::Process.kill 'TERM', $PROCESS_ID
  end
end
