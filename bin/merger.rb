#!/usr/bin/env ruby

require 'English'
require 'yaml'

if File.basename($PROGRAM_NAME) == File.basename(__FILE__)
  unless ENV['COMPOSE_FILE']
    STDERR.puts 'COMPOSE_FILE environment must point to one on mo files'
    exit 1
  end
end


class Hash

  def deep_dup
    Marshal.load(Marshal.dump(self))
  end

end

class Array

  def deep_dup
    Marshal.load(Marshal.dump(self))
  end

end



def extend_hash(first, second)
  raise ArgumentError.new('First and second args equal nil') if [first, second].all? &:nil?
  return second if first.nil?
  return first if second.nil?

  first.each_pair do |fk, fv|
    next unless second.key?(fk)

    sv = second[fk]
    raise "Types of values not match(#{fv.class}, #{sv.class})" if fv.class != sv.class

    # Специальный случай потому что command не мерджится а заменяется
    if fk == 'command'
      first[fk] = sv
    elsif fv.is_a? Hash
      extend_hash(fv, sv)
    elsif fv.is_a? Array
      fv |= sv
      first[fk] = fv
    else
      first[fk] = sv
    end
  end

  second.each_pair do |sk, sv|
    next if first.key?(sk)

    first[sk] = sv
  end

  first
end

def process_compose_hash(yml, dirname, parent = {})
  (yml['services'] || {}).each_pair do |name, service|
    next unless ext = service['extends']
    base = if ext.is_a? String
             template = yml['services'][ext]
             parent_service = (parent['services'] || {})[ext] || {}
             extend_hash(parent_service.deep_dup, template)
           elsif file = ext['file']
             ENV.each_pair do |k, v|
               file.gsub!("$#{k}", v)
               file.gsub!("${#{k}}", v)
             end

             file_to_load = if File.exist?(dirname + '/' + file)
                              dirname + '/' + file
                            else
                              file
                    end

             tmp = process_compose_hash(YAML.load(File.read(file_to_load)), File.dirname(file_to_load), service)

             begin
                 (tmp['services'][ext['service']] || {})
               rescue StandardError
                 {}
               end
           else
             yml['services'][ext['service']]
    end.deep_dup

    service.delete 'extends'

    yml['services'][name] = extend_hash(base, service)
  end
  yml
end

if File.basename($PROGRAM_NAME) == File.basename(__FILE__)
  result = ENV['COMPOSE_FILE'].split(':').reduce({}) do |parent, file|
    yml = process_compose_hash(YAML.load(File.read(file)), File.dirname(file), parent)
    if yml['version'] && parent['version'] && yml['version'] != parent['version']
      raise "version mismatch: #{file}"
    end
    ret = extend_hash(parent.deep_dup, yml)
    ret
  end

  if ARGV[0].nil? || ARGV[0].strip == '-'
    puts YAML.dump(result)
  else
    File.write(ARGV[0].strip, YAML.dump(result))
  end

end
