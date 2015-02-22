# encoding: utf-8

RSpec.describe BaseHangul do

  describe '.encode' do
    # TODO move to spec/support
    shared_examples "encodes" do |examples|
      examples.each do |binary, hangul|
        specify "encodes #{binary} to #{hangul}" do
          encoded = described_class.encode(binary)
          expect(encoded).to eq(hangul)
        end
      end
    end

    context 'when empty biniry' do
      subject(:encoded) { described_class.encode('') }
      it { is_expected.to eq('') }
    end

    context 'when the length is divided by 5, the remainer is 0' do
      examples = {
        '123ab'                     => '꺽먹꼍녜',
        "123d\x00"                  => '꺽먹꼐가',
        '1234567890'                => '꺽먹께겔꼍뮷뒝낮',
        "12345678d\x00"             => '꺽먹께겔꼍뮷듕가',
        'This is an encoded string' =>
          '넥라똔먈늴멥갯놓궂뗐밸뮤뉴뗐뀄굡덜멂똑뚤',
      }
      it_behaves_like 'encodes', examples
    end

    context "when the length is divided by 5, the remainer is 1, 2, or 3" do
      examples = {
        '1'                     => '꺽흐흐흐',
        '12'                    => '꺽먈흐흐',
        '123'                   => '꺽먹꺄흐',
        '123456'                => '꺽먹께겔꼍흐흐흐',
        '1234567'               => '꺽먹께겔꼍뮨흐흐',
        '12345678'              => '꺽먹께겔꼍뮷됩흐',
      }
      it_behaves_like 'encodes', examples
      examples.each do |binary, hangul|
        specify "encoded includes 흐" do
          encoded = described_class.encode(binary)
          expect(encoded).to include('흐')
        end
      end
    end

    context 'when the length is divided by 5, the remainer is 4' do
      examples = {
        '123d'                  => '꺽먹꼐빎',
        '123e'                  => '꺽먹꼐빔',
        '123f'                  => '꺽먹꼐빕',
        '123g'                  => '꺽먹꼐빗',
        '12345678d'             => '꺽먹께겔꼍뮷듕빎',
        '12345678e'             => '꺽먹께겔꼍뮷듕빔',
        '12345678f'             => '꺽먹께겔꼍뮷듕빕',
        '12345678g'             => '꺽먹께겔꼍뮷듕빗',
      }
      it_behaves_like 'encodes', examples
    end
  end

  describe '.decode' do
    it_behaves_like 'a decoder', :decode

    context 'when string has wrong number of padding characters' do
      it 'decodes hangul to binary' do
        decoded = described_class.decode('꺽')
        expect(decoded).to eq('1')
        decoded = described_class.decode('꺽흐')
        expect(decoded).to eq('1')
        decoded = described_class.decode('꺽흐흐')
        expect(decoded).to eq('1')
        decoded = described_class.decode('꺽흐흐흐흐')
        expect(decoded).to eq('1')
        decoded = described_class.decode('꺽먈')
        expect(decoded).to eq('12')
        decoded = described_class.decode('꺽먹꺄')
        expect(decoded).to eq('123')
        decoded = described_class.decode('꺽먹께겔꼍')
        expect(decoded).to eq('123456')
        decoded = described_class.decode('꺽먹께겔꼍뮨')
        expect(decoded).to eq('1234567')
        decoded = described_class.decode('꺽먹께겔꼍뮷됩')
        expect(decoded).to eq('12345678')
        decoded = described_class.decode('꺽먹꼍녜흐')
        expect(decoded).to eq('123ab')
        decoded = described_class.decode('꺽먹께겔꼍뮷뒝낮흐흐')
        expect(decoded).to eq('1234567890')
      end
    end

    context 'when there are invalid characters' do
      it 'ignores invalid characters' do
        strings = [' 꺽먹꼍녜',
                   '꺽먹꼍녜 ',
                   '꺽あ먹高꼍녜 ',
                   "\n꺽\t먹\u3000꼍abc녜"]
        strings.each do |encoded|
          decoded = described_class.decode(encoded)
          expect(decoded).to eq('123ab')
        end
      end
    end
  end

  describe '.strict_decode' do
    let(:msg_invalid_char) { described_class.const_get(:MSG_INVALID_CHAR) }
    let(:msg_invalid_padding) { described_class.const_get(:MSG_INVALID_PADDING) }

    it_behaves_like 'a decoder', :strict_decode

    context 'when string has wrong number of padding characters' do
      it 'raises ArgumentError' do
        strings = ['꺽', # rubocop:disable Style/WordArray
                   '꺽흐',
                   '꺽흐흐',
                   '꺽흐흐흐흐',
                   '꺽먈',
                   '꺽먹꺄',
                   '꺽먹께겔꼍',
                   '꺽먹께겔꼍뮨',
                   '꺽먹께겔껼뮷됩',
                   '꺽먹꼍녜흐',
                   '꺽먹께겔꼍뮷뒝낮흐흐']
        strings.each do |encoded|
          expect { described_class.strict_decode(encoded) }
            .to raise_error(ArgumentError, msg_invalid_padding)
        end
      end
    end

    context 'when string has characters after padding characters' do
      it 'raises ArgumentError' do
        strings = ['꺽흐꺽흐흐흐', # rubocop:disable Style/WordArray
                   '꺽흐흐흐꺽흐흐흐',
                   '꺽먹꺄흐꺽',
                   '꺽먹께흐겔꼍흐흐흐',
                   '꺽먹꼐흐꺽먹꼐빎']
        strings.each do |encoded|
          expect { described_class.strict_decode(encoded) }
            .to raise_error(ArgumentError, msg_invalid_padding)
        end
      end
    end

    context 'when string has special characters with wrong position' do
      it 'raises ArgumentError' do
        strings = ['꺽먹꼐빎꺽흐흐흐', # rubocop:disable Style/WordArray
                   '꺽먹빎',
                   '꺽먹빎흐']
        strings.each do |encoded|
          expect { described_class.strict_decode(encoded) }
            .to raise_error(ArgumentError, msg_invalid_padding)
        end
      end
    end

    context 'when there are invalid characters' do
      it 'raises ArgumentError' do
        strings = [' 꺽먹꼍녜',
                   '꺽먹꼍녜 ',
                   "\n꺽\t먹\u3000꼍abc녜"]
        strings.each do |encoded|
          expect { described_class.strict_decode(encoded) }
            .to raise_error(ArgumentError, msg_invalid_char)
        end
      end
    end
  end
end
