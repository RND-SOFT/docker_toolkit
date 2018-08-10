#!/usr/bin/env ruby

require "childprocess"
require 'optparse'
require 'English'

STDOUT.sync = true
STDERR.sync = true

@opts = {
  code: 0,
  sleep: 1,
  term_code: 0
}

parser = OptionParser.new do |o|
  o.banner = 'Usage: term.rb [options]'

  o.on("--exit code=#{@opts[:code]}", 'set exit code') do |code|
    @opts[:code] = code.to_i
  end

  o.on("--sleep sec=#{@opts[:sleep]}", 'Sleep before exit') do |sec|
    @opts[:sleep] = sec.to_i
  end

  o.on('--term', 'SIGTERM self') do
    @opts[:term] = true
  end

  o.on("--term-code=#{@opts[:term_code]}", 'exit code when SIGTERM catched') do |code|
    @opts[:term_code] = code.to_i
  end

  o.on('--kill', 'SIGKILL self') do
    @opts[:kill] = true
  end

end
parser.parse!

def log msg
  puts "[terminator]: #{msg}"
end


%w[INT TERM].each do |sig|
  trap(sig) do
    exit(@opts[:term_code])
  end
end 

::Process.kill('KILL', $$) if @opts[:kill]
::Process.kill('TERM', $$) if @opts[:term]


sleep @opts[:sleep]
exit @opts[:code]