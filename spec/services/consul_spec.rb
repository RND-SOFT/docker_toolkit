require 'tmpdir'
require 'socket'
require 'English'
require 'securerandom'
require 'diplomat'


RSpec.describe 'consul.rb' do
  let(:waiter){ File.join($root, '../', 'bin', 'waiter.rb') }
  let(:consul){ File.join($root, '../', 'bin', 'consul.rb') }

  around :each do |example|
    Dir.mktmpdir do |dir|
      Dir.chdir dir do
        example.run
      end
    end
  end

  around :each do |example|
    system('consul agent -ui -server -bootstrap-expect=1 -bind 0.0.0.0 -client 0.0.0.0 -dev &> /dev/null &')
    expect($CHILD_STATUS.success?).to be_truthy
    system("#{waiter} --consul -t3 -i1 -q")
    expect($CHILD_STATUS.success?).to be_truthy

    example.run
  ensure
    # system("consul leave &> /dev/null")
    system('killall consul &> /dev/null')
    expect($CHILD_STATUS.success?).to be_truthy
  end

  it 'consul is ready' do
    system('consul members &> /dev/null')
    expect($CHILD_STATUS.success?).to be_truthy
  end

  describe 'when services' do
    shared_examples 'show env' do
      it 'show env for service1' do
        json = `#{consul} --show service1`
        expect($CHILD_STATUS.success?).to be_truthy
        json = JSON.parse(json)
        expect(json).to include('service1')
        expect(json).not_to include('service2')

        service = json['service1']
        expect(service.count).to eq 2
        expect(service[0]).to include('env' => 'KEY_1', 'value' => 'value1')
        expect(service[1]).to include('env' => 'KEY_2', 'value' => 'value2')
      end

      it 'show env for all services' do
        json = `#{consul} --show`
        expect($CHILD_STATUS.success?).to be_truthy
        json = JSON.parse(json)
        expect(json).to include('service1', 'service2')

        service = json['service1']
        expect(service.count).to eq 2
        expect(service[0]).to include('env' => 'KEY_1', 'value' => 'value1')
        expect(service[1]).to include('env' => 'KEY_2', 'value' => 'value2')

        service = json['service2']
        expect(service.count).to eq 1
        expect(service[0]).to include('env' => 'KEY_3', 'value' => 'value3')
      end
    end

    describe 'manual envs load' do
      before do
        Diplomat::Kv.put('services/env/service1/key-1', 'value1')
        Diplomat::Kv.put('services/env/service1/key-2', 'value2')
        Diplomat::Kv.put('services/env/service2/key-3', 'value3')
      end

      include_examples 'show env'
    end

    describe 'load envs from config' do
      before do
        IO.popen("#{consul} --init --config -", 'r+') do |stdin|
          stdin.puts %(
            {
              "service1": [
                {"env": "KEY-1", "value": "value1"},
                {"env": "KEY_2", "value": "value2"}
              ],
              "service2": [
                {"env": "key-3", "value": "value3"}
              ]
            }
          )
          stdin.close
        end
      end

      include_examples 'show env'
    end

    describe 'when dereferencing' do
      shared_examples 'show dereferencing env' do
        it 'is disabled' do
          json = `#{consul} --show service1`
          expect($CHILD_STATUS.success?).to be_truthy
          service = JSON.parse(json)['service1']
          expect(service[1]['env']).to eq('KEY_2')
          expect(service[1]['value']).to eq('consul://services/env/service2/key_3')
        end

        it 'is enabled' do
          json = `#{consul} --show service1 -d`
          expect($CHILD_STATUS.success?).to be_truthy
          service = JSON.parse(json)['service1']
          expect(service[1]['env']).to eq('KEY_2')
          expect(service[1]['value']).to eq('value3')
        end
      end

      describe 'manual envs load' do
        before do
          Diplomat::Kv.put('services/env/service1/key-1', 'value1')
          Diplomat::Kv.put('services/env/service1/key-2', 'consul://services/env/service2/key_3')
          Diplomat::Kv.put('services/env/service2/key_3', 'value3')
        end

        include_examples 'show dereferencing env'
      end

      describe 'load envs from config' do
        before do
          IO.popen("#{consul} --init --config -", 'r+') do |stdin|
            stdin.puts %(
              {
                "service1": [
                  {"env": "KEY-1", "value": "value1"},
                  {"env": "KEY_2", "value": "consul://services/env/service2/key_3"}
                ],
                "service2": [
                  {"env": "key-3", "value": "value3"}
                ]
              }
            )
            stdin.close
          end
        end

        include_examples 'show dereferencing env'
      end
    end

    describe 'when uploading files' do
      let(:file){ "#{SecureRandom.hex}.tmp" }
      let(:content){ SecureRandom.hex }

      before do
        File.write(file, content)
      end

      it 'is disabled' do
        IO.popen("#{consul} --init --config -", 'r+') do |stdin|
          stdin.puts %(
            {
              "service1": [
                {"env": "KEY-1", "value": "value1"},
                {"env": "KEY_2", "file": "FILE"}
              ],
              "service2": [
                {"env": "key-3", "value": "value3"}
              ]
            }
          ).gsub('FILE', file)
          stdin.close
        end

        json = `#{consul} --show service1 -d`
        expect($CHILD_STATUS.success?).to be_truthy
        service = JSON.parse(json)['service1']
        expect(service[1]['env']).to eq('KEY_2')
        expect(service[1]['value']).to eq(file)
      end

      it 'is enabled' do
        IO.popen("#{consul} --init --config - --upload", 'r+') do |stdin|
          stdin.puts %(
            {
              "service1": [
                {"env": "KEY-1", "value": "value1"},
                {"env": "KEY_2", "file": "FILE"}
              ],
              "service2": [
                {"env": "key-3", "value": "value3"}
              ]
            }
          ).gsub('FILE', file)
          stdin.close
        end

        json = `#{consul} --show service1 -d`
        expect($CHILD_STATUS.success?).to be_truthy
        service = JSON.parse(json)['service1']
        expect(service[1]['env']).to eq('KEY_2')
        expect(service[1]['value']).to eq(content)
      end
    end
  end
end
