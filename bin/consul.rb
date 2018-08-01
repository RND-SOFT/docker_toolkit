#!/usr/bin/env ruby

require 'diplomat'
require 'optparse'
require 'English'
require 'yaml'

STDOUT.sync = true
STDERR.sync = true

@opts = {}

@opts[:exec] = (begin
                  ARGV.join(' ').split(' -- ')[1].strip
                rescue StandardError
                  nil
                end)

parser = OptionParser.new do |o|
  o.banner = 'Usage: consul.rb [options] -- exec'

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

  o.on('--env prefix', 'export KV values from prefix as env varaibles') do |prefix|
    @opts[:env] = (prefix + '/').gsub('//', '/')
  end

  o.on('--export', 'add export to --env output') do
    @opts[:export] = true
  end

  o.on('--pristine', "not include the parent processes' environment when exec child process") do
    @opts[:pristine] = true
  end

  o.on('--put path:value', 'put value to path') do |path|
    @opts[:put] = path.strip
  end

  o.on('--get path', 'get value from') do |path|
    @opts[:get] = path.strip
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
      if @opts[:dereference] && value && value[/^consul:\/\//]
        reference_path = value.gsub(/^consul:\/\//, '')
        value = Diplomat::Kv.get(reference_path)
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

if put = @opts[:put]
  path, *value = put.split(':').map(&:strip)
  value = value.join(':')
  value = File.read(value) if @opts[:upload] && value && File.exist?(value)

  Diplomat::Kv.put(path, (value || '').strip) || die("Can't put #{path} to Consul")

  exit 0
end

if path = @opts[:get]
  value = Diplomat::Kv.get(path)
  if @opts[:dereference] && value && value[/^consul:\/\//]
    reference_path = value.gsub(/^consul:\/\//, '')
    value = Diplomat::Kv.get(reference_path)
  end

  STDOUT.puts (value || '').strip

  exit 0
end

if prefix = @opts[:env]
  keys = Diplomat::Kv.get(prefix, keys: true) || die("Can't get keys at #{prefix} from Consul")

  env = keys.reduce({}) do |e, key|
    value = Diplomat::Kv.get(key)
    if @opts[:dereference] && value && value[/^consul:\/\//]
      reference_path = value.gsub(/^consul:\/\//, '')
      value = Diplomat::Kv.get(reference_path)
    end

    e.merge(
      key.gsub(prefix, '').upcase.gsub(/[^0-9a-z]/i, '_') => value
    )
  end

  if cmd = @opts[:exec]

    env = if @opts[:pristine]
            env
          else
            ENV.to_h.merge(env)
    end

    exec(env, cmd, unsetenv_others: true)
  else
    env.each_pair do |k, v|
      STDOUT.puts "#{@opts[:export] ? 'export ' : ''}#{k}=\"#{v}\""
    end
  end


  exit 0
end

STDOUT.puts parser.help
exit 1
