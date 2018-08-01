#!/usr/bin/env ruby

require 'diplomat'
require 'optparse'
require 'English'
require 'yaml'

STDOUT.sync = true
STDERR.sync = true

@opts = {}

parser = OptionParser.new do |o|
  o.banner = 'Usage: consul.rb [options]'

  o.on('--consul url', 'Set up a custom Consul URL') do |url|
    Diplomat.configure do |config|
      config.url = url.strip
    end
  end

  o.on('--token token', 'Connect into consul with custom access token (ACL)') do |token|
    Diplomat.configure do |config|
      config.acl_token = token.strip
    end
  end

  o.on('--init [service]', 'Initialize Consul services from config') do |service|
    @opts[:service] = service
    @opts[:init] = true
  end

  o.on('--config file', 'Read service configulation from file') do |file|
    @opts[:config] = file.strip
  end

  o.on('--upload', 'Upload files to variables') do
    @opts[:upload] = true
  end

  o.on('--show [service]', 'Show service configulation from Consul') do |service|
    @opts[:service] = service
    @opts[:show] = true
  end

  o.on('--override', 'override existed keys') do
    @opts[:override] = true
  end

  o.on('-d', '--dereference', 'dereference consul values in form of "consul://key/subkey"') do
    @opts[:dereference] = true
  end
end
parser.parse!

def die(message)
  STDERR.puts "Error: #{message}"
  exit 1
end

if config = @opts[:config]
  @opts[:config] = if config == '-'
                     JSON.parse(STDIN.read)
                   else
                     JSON.parse(File.read(config))
                   end
end

if @opts[:init]
  raise OptionParser::MissingArgument.new('config') unless @opts[:config]

  services = if service = @opts[:service]
               {
                 service => @opts[:config][service]
               }
             else
               @opts[:config]
  end

  services.each_pair do |service, config|
    path = "services/env/#{service}"
    config.each do |item|
      env = item['env'].downcase.gsub(/[^0-9a-z]/i, '_')
      key = "#{path}/#{env}"
      value = if @opts[:upload] && item['file']
                File.read(item['file'])
              else
                item['value'] || item['default'] || item['file']
      end

      empty = begin
        Diplomat::Kv.get(key)
        false
      rescue Diplomat::KeyNotFound
        true
      end

      Diplomat::Kv.put(key, (value || '').strip) || die("Can't put #{key} to Consul") if empty || @opts[:override]
    end
  end

  exit 0
end

if @opts[:show]
  config = {}

  path = if service = @opts[:service]
           "services/env/#{service}/"
         else
           'services/env/'
         end

  answer = Diplomat::Kv.get(path, recurse: true, convert_to_hash: true) || die("Can't get #{path} from Consul")
  answer['services']['env'].each_pair do |service, env|
    cfg = config[service] ||= []

    env.each_pair do |key, value|
      if @opts[:dereference] && value[/^consul:\/\//]
        reference_path = value.gsub(/^consul:\/\//, '')
        value = Diplomat::Kv.get(reference_path) || die("Can't get #{reference_path} from Consul")
      end
      cfg.push(
        env: key.upcase.gsub(/[^0-9a-z]/i, '_'),
        value: value
      )
    end
  end

  STDOUT.puts JSON.pretty_generate(config)

  exit 0
end

STDOUT.puts parser.help
exit 1
