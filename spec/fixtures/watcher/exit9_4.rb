#!/usr/bin/env ruby
require 'docker_toolkit'

STDOUT.sync = true
STDERR.sync = true

# self must be terminated and second must exit with 2
# code 2
DockerToolkit::Watcher.new.exec do |w|
  w.add 'terminator.rb', '--sleep', '3', '--exit', '4'

  w.add 'terminator.rb', '--sleep', '4'

  Thread.new do
    sleep 2
    puts `ls /tmp/no_such_file &> /dev/null`
    system('cat /tmp/no_such_file &> /dev/null')
  end

 
end
