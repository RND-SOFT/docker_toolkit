#!/usr/bin/env ruby

require 'optparse'
require 'securerandom'
require 'English'
require 'openssl'
require 'tempfile'

STDOUT.sync = true
STDERR.sync = true

TIMEOUT = 15
INTERVAL = 3

@opts = {}

@opts[:exec] = (begin
                  ARGV.join(' ').split(' -- ')[1].strip
                rescue StandardError
                  nil
                end)
@opts[:timeout] = TIMEOUT
@opts[:interval] = INTERVAL
@opts[:consul_addr] = 'http://localhost:8500'


OptionParser.new do |o|
  o.banner = 'Usage: waiter.rb [options] -- exec'

  o.on('--tcp host:port', 'Wait for tcp accepts on host:port') do |addr|
    host, port = addr.split(':')
    @opts[:tcp] = addr.strip
    @opts[:host] = host.strip
    @opts[:port] = port.strip
  end

  o.on('--db dbname', 'Wait for PG database exists. Using --tcp to conenct PG') do |db|
    @opts[:db] = db.strip
  end

  o.on('--tb tablename', 'Wait for PG table exists. Using --tcp to conenct PG') do |tb|
    @opts[:tb] = tb.strip
  end

  o.on('-f', '--file filename', 'Wait for file exists.') do |file|
    @opts[:file] = file.strip
  end

  o.on("--consul-addr addr=#{@opts[:consul_addr]}", 'HTTP addres to connect to consul') do |addr|
    @opts[:consul_addr] = addr.strip
  end

  o.on('--consul', 'Wait for local consul agent to be ready') do
    @opts[:consul] = true
  end

  o.on('--consul-service service', 'Wait for service appear in consul') do |service|
    @opts[:consul_service] = service
  end

  o.on('--user user', 'username') do |user|
    @opts[:user] = user.strip
  end

  o.on('--pass pass', 'password') do |pass|
    @opts[:pass] = pass.strip
  end

  o.on('-t', '--timeout secs=15', 'Total timeout') do |timeout|
    @opts[:timeout] = timeout.to_i
  end

  o.on('-i', '--interval secs=2', 'Interval between attempts') do |interval|
    @opts[:interval] = interval.to_i
  end

  o.on('-q', '--quiet', 'Do not output any status messages') do
    @opts[:quiet] = true
  end
end.parse!

def log(message)
  puts message unless @opts[:quiet]
end

@opts[:timeout] = @opts[:timeout].to_i
@opts[:interval] = @opts[:interval].to_i

if @opts[:db]
  @pg = {}
  @pg[:db] = "-d #{@opts[:db]}"
  @pg[:user] = "-U #{@opts[:user]}" if @opts[:user]
  @pg[:pass] = if @opts[:pass] && !@opts[:pass].empty?
                 "-W #{@opts[:pass]}"
               else
                 '-w'
  end

  @pg[:host] = "-h #{@opts[:host]}" if @opts[:host]
  @pg[:port] = "-p #{@opts[:port]}" if @opts[:port]

  @pg[:tb] = @opts[:tb] if @opts[:tb]
end

def wait_for(timeout)
  starttime = Time.now
  loop do
    success = yield

    return success if success

    return false if (Time.now - starttime) > timeout
    sleep @opts[:interval]
  end

  false
end

def complete!(success)
  if success
    if @opts[:exec]
      exec @opts[:exec]
    else
      exit 0
    end
  end

  STDERR.puts 'Operation timed out'
  exit 1
end

def wait_for_consul
  log('Waiting for consul...')
  ret = wait_for @opts[:timeout] do
    cmd = "consul operator raft list-peers -http-addr=#{@opts[:consul_addr]} > /dev/null 2>&1"
    system(cmd)
    $CHILD_STATUS.success?
  end

  yield(ret)
end

def wait_for_consul_service(service)
  log("Waiting for consul service #{service}...")
  ret = wait_for @opts[:timeout] do
    cmd = "curl -s #{@opts[:consul_addr]}/v1/health/service/#{service}?passing | wc -c"
    bytes = `#{cmd}`.to_i
    bytes > 10
  end

  yield(ret)
end

def wait_for_tcp
  log("Waiting for TCP: #{@opts[:host]}:#{@opts[:port]}...")
  ret = wait_for @opts[:timeout] do
    cmd = "nc -z #{@opts[:host]} #{@opts[:port]} > /dev/null 2>&1"
    system(cmd)
    $CHILD_STATUS.success?
  end

  yield(ret)
end

def wait_for_db
  log("Waiting for DB: pg://#{@opts[:user]}:#{@opts[:pass]}@#{@opts[:host]}:#{@opts[:port]}/#{@opts[:db]}...")
  ret = wait_for @opts[:timeout] do
    cmd = "psql -lqt #{@pg[:user]} #{@pg[:pass]} #{@pg[:host]} #{@pg[:port]} #{@pg[:db]} 2>/dev/null | cut -d \\| -f 1 | grep -qw #{@opts[:db]} > /dev/null 2>&1"
    system(cmd)
    $CHILD_STATUS.success?
  end

  yield(ret)
end

def wait_for_tb
  log("Waiting for TABLE: pg://#{@opts[:user]}:#{@opts[:pass]}@#{@opts[:host]}:#{@opts[:port]}/#{@opts[:db]}##{@opts[:tb]}...")
  ret = wait_for @opts[:timeout] do
    cmd = "echo \"\\dt\" | psql -qt #{@pg[:user]} #{@pg[:pass]} #{@pg[:host]} #{@pg[:port]} #{@pg[:db]} 2>/dev/null | cut -d \\| -f 2 | grep -qw #{@pg[:tb]} > /dev/null 2>&1"
    system(cmd)
    $CHILD_STATUS.success?
  end

  yield(ret)
end

def wait_for_file(file = @opts[:file], timeout = @opts[:timeout])
  log("Waiting for FILE: #{file}")
  ret = wait_for timeout do
    File.exist? file
  end
  yield(ret)
end

if @opts[:tb]
  wait_for_tcp do |success|
    if success
      wait_for_db do |success|
        if success
          wait_for_tb do |success|
            complete!(success)
          end
        end
      end
    end

    complete!(false)
  end
end

if @opts[:db]
  wait_for_tcp do |success|
    if success
      wait_for_db do |success|
        complete!(success)
      end
    end

    complete!(false)
  end
end


if @opts[:consul]
  wait_for_consul do |success|
    complete!(success)
  end
end

if @opts[:consul_service]
  wait_for_consul_service(@opts[:consul_service]) do |success|
    complete!(success)
  end
end

if @opts[:tcp]
  wait_for_tcp do |success|
    complete!(success)
  end
end

if @opts[:file]
  wait_for_file(@opts[:file], @opts[:timeout]) do |success|
    complete!(success)
  end
end
