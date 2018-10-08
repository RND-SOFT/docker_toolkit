#!/usr/bin/env ruby

require 'optparse'
require 'diplomat'

@opts = {
  url: 'http://localhost:8500',
  timeout: 10,
  ttl: 30*60,
}

parser = OptionParser.new do |o|
  o.banner = 'Usage: locker.rb [options]'

  o.on("--consul url=#{@opts[:url]}", 'Set up a custom Consul URL') do |url|
    Diplomat.configure do |config|
      config.url = url.strip
    end
  end

  o.on("--lock resource", 'resource name to lock with Consul') do |resource|
    @opts[:lock] = resource.strip
  end

  o.on("--ttl seconds=#{@opts[:ttl]}", 'TTL to set when session created') do |seconds|
    @opts[:ttl] = Integer(seconds.strip)
  end

  o.on("--unlock session", 'session name from previous call lock') do |session|
    @opts[:unlock] = session.strip
  end

  o.on("--timeout seconds=#{@opts[:timeout]}", 'timeout to wait lock') do |seconds|
    @opts[:timeout] = Integer(seconds.strip)
  end

end
parser.parse!


def lock session, locker, timeout
  Timeout::timeout(timeout) do
    return Diplomat::Lock.wait_to_acquire("resource/#{locker[:resource]}/lock", session, locker.to_json, 10)
  end

rescue Timeout::Error => e
  return false
end


if resource = @opts[:lock]
  locker = {
    Name: "#{resource}_locker_#{rand(999999)}",
    Behavior: 'delete',
    TTL: "#{@opts[:ttl]}s",
    resource: resource,
  }
  sessionid = Diplomat::Session.create(locker)

  if lock(sessionid, locker, @opts[:timeout])
    puts sessionid
    exit 0
  else
    STDERR.puts "Failed to lock resource: #{resource}"
    exit 1
  end

elsif session = @opts[:unlock]
  Diplomat::Session.destroy(session)
else
  STDERR.puts parser.help
  exit 1
end
