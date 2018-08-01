require_relative File.join($root, '../', 'bin', 'merger.rb')

RSpec.describe 'merger.rb' do
  context 'algorithm' do
    [
      {
        input1: { a: 1, h: { i: 1 } },
        input2: { b: 2, h: { j: 2 } },
        result: { a: 1, b: 2, h: { i: 1, j: 2 } }
      },
      {
        input1: { a: 1, c: 2, h: { i: 1, j: 2 } },
        input2: { a: 2, b: 3, h: { i: 2, k: 3 } },
        result: { a: 2, b: 3, c: 2, h: { i: 2, j: 2, k: 3 } }
      },
      {
        input1: { a: [1, 2] },
        input2: { a: [2, 3] },
        result: { a: [1, 2, 3] }
      }
    ].each_with_index do |example, i|
      it "hash merge #{i}" do
        input1 = example[:input1]
        input2 = example[:input2]
        result = example[:result]

        merged = extend_hash(input1.deep_dup, input2)
        expect(merged).to eq result
      end
    end
  end

  context 'files' do
    let(:merger){ File.join($root, '../', 'bin', 'merger.rb') }

    [1, 2].each do |num|
      it "case #{num}" do
        Dir.chdir File.join($root, 'fixtures') do
          result_yml = `COMPOSE_FILE=template#{num}.yml #{merger}`.strip
          expected_yml = File.read("result#{num}.yml").strip
          result = YAML.safe_load(result_yml)
          expected = YAML.safe_load(expected_yml)

          expect(result).to eq expected
        end
      end
    end
  end
end
