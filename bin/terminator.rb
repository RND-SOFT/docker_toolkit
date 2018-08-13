#!/usr/bin/env ruby
require 'optparse'
require 'English'

STDOUT.sync = true
STDERR.sync = true

@opts = {
  code: 0,
  sleep: 1,
  term_code: 0
}

def log(msg)
  puts "[terminator]: #{msg}"
end

log "started: #{ARGV.inspect}"


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




%w[INT TERM].each do |sig|
  trap(sig) do
    log "signal: #{sig}. exit: #{@opts[:term_code]}"
    exit(@opts[:term_code])
  end
end

log 'sleep...'
sleep @opts[:sleep]

log 'go'
if @opts[:kill]
  log 'kill self'
  ::Process.kill('KILL', $PROCESS_ID)
end

if @opts[:term]
  log 'term self'
  ::Process.kill('TERM', $PROCESS_ID)
end

log "normal exit with: #{@opts[:code]}"
exit @opts[:code]
