describe Validation::Rule::PublicKey do
  it "will not accept parameters" do
    validator = Validation::Validator.new({})
    expect {
      validator.rule(:key, public_key: {param: true})
    }.to raise_error ArgumentError
  end

  it "has an error key" do
    expect(described_class.new.error_key).to eq(:public_key)
  end

  context "validation" do
    ["PUBLIC KEY", "RSA PUBLIC KEY"].each do |key_type|
      context key_type do
        let(:prefix) { "-----BEGIN #{key_type}-----" }
        let(:suffix) { "-----END #{key_type}-----" }

        let(:key) { "#{prefix}\nAAAAAA==\n#{suffix}\n" }

        it "validates an exported RSA key" do
          validator = Validation::Validator.new(OpenStruct.new(key: key))
          validator.rule(:key, :public_key)

          expect(validator).to be_valid
          expect(validator.errors).to be_empty
        end

        it "strips whitespace" do
          validator = Validation::Validator.new(OpenStruct.new(key: "  \n   #{key}\n \n  "))
          validator.rule(:key, :public_key)

          expect(validator).to be_valid
          expect(validator.errors).to be_empty
        end

        it "fails if the prefix is missing" do
          validator = Validation::Validator.new(OpenStruct.new(key: "\nAAAAAA==\n#{suffix}\n"))
          validator.rule(:key, :public_key)

          expect(validator).not_to be_valid
          expect(validator.errors).to include(:key)
        end

        it "fails if the suffix is missing" do
          validator = Validation::Validator.new(OpenStruct.new(key: "#{prefix}\nAAAAAA==\n\n"))
          validator.rule(:key, :public_key)

          expect(validator).not_to be_valid
          expect(validator.errors).to include(:key)
        end

        it "fails if the key is empty" do
          validator = Validation::Validator.new(OpenStruct.new(key: ""))
          validator.rule(:key, :public_key)

          expect(validator).not_to be_valid
          expect(validator.errors).to include(:key)
        end

        it "fails if the key is nil" do
          validator = Validation::Validator.new(OpenStruct.new(key: nil))
          validator.rule(:key, :public_key)

          expect(validator).not_to be_valid
          expect(validator.errors).to include(:key)
        end
      end
    end
  end
end
