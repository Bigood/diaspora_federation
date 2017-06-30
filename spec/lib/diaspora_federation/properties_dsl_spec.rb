module DiasporaFederation
  describe PropertiesDSL do
    subject(:dsl) { Class.new.extend(PropertiesDSL) }

    context "simple properties" do
      it "can name simple properties by symbol" do
        dsl.property :test, :string
        properties = dsl.class_props
        expect(properties).to have(1).item
        expect(properties[:test]).to eq(:string)
        expect(dsl.xml_names[:test]).to eq(:test)
      end

      it "will not accept other types for names" do
        ["test", 1234, true, {}].each do |val|
          expect {
            dsl.property val, :string
          }.to raise_error PropertiesDSL::InvalidName
        end
      end

      it "will not accept other types for type" do
        ["test", 1234, true, {}].each do |val|
          expect {
            dsl.property :fail, val
          }.to raise_error PropertiesDSL::InvalidType
        end
      end

      it "accepts only supported types" do
        %i[text number foobar].each do |val|
          expect {
            dsl.property :fail, val
          }.to raise_error PropertiesDSL::InvalidType
        end
      end

      it "can define multiple properties" do
        dsl.property :test, :string
        dsl.property :asdf, :string
        dsl.property :zzzz, :string
        properties = dsl.class_props
        expect(properties).to have(3).items
        expect(properties.keys).to include(:test, :asdf, :zzzz)
        properties.values.each {|type| expect(type).to eq(:string) }
      end

      it "can add an xml name to simple properties with a symbol" do
        dsl.property :test, :string, xml_name: :xml_test
        properties = dsl.class_props
        expect(properties).to have(1).item
        expect(properties[:test]).to eq(:string)
        expect(dsl.xml_names[:test]).to eq(:xml_test)
      end

      it "will not accept other types for xml names" do
        ["test", 1234, true, {}].each do |val|
          expect {
            dsl.property :test, :string, xml_name: val
          }.to raise_error PropertiesDSL::InvalidName, "invalid xml_name"
        end
      end
    end

    context "nested entities" do
      it "gets included in the properties" do
        expect(Entities::TestNestedEntity.class_props.keys).to include(:test, :multi)
      end

      it "can define nested entities" do
        dsl.entity :other, Entities::TestEntity
        properties = dsl.class_props
        expect(properties).to have(1).item
        expect(properties[:other]).to eq(Entities::TestEntity)
      end

      it "can define an array of a nested entity" do
        dsl.entity :other, [Entities::TestEntity]
        properties = dsl.class_props
        expect(properties).to have(1).item
        expect(properties[:other]).to be_an_instance_of(Array)
        expect(properties[:other].first).to eq(Entities::TestEntity)
      end

      it "must be an entity subclass" do
        [1234, true, {}].each do |val|
          expect {
            dsl.entity :fail, val
          }.to raise_error PropertiesDSL::InvalidType
        end
      end

      it "must be an entity subclass for array" do
        [1234, true, {}].each do |val|
          expect {
            dsl.entity :fail, [val]
          }.to raise_error PropertiesDSL::InvalidType
        end
      end

      it "can not add an xml name to a nested entity" do
        expect {
          dsl.entity :other, Entities::TestEntity, xml_name: :other_name
        }.to raise_error ArgumentError, "xml_name is not supported for nested entities"
      end
    end

    describe ".default_values" do
      it "can accept default values" do
        dsl.property :test, :string, default: :foobar
        defaults = dsl.default_values
        expect(defaults[:test]).to eq(:foobar)
      end

      it "can accept default blocks" do
        dsl.property :test, :string, default: -> { "default" }
        defaults = dsl.default_values
        expect(defaults[:test]).to eq("default")
      end
    end

    describe ".resolv_aliases" do
      it "resolves the defined alias" do
        dsl.property :test, :string, alias: :test_alias
        data = dsl.resolv_aliases(test_alias: "foo")
        expect(data[:test]).to eq("foo")
        expect(data).not_to have_key(:test_alias)
      end

      it "raises when alias and original property are present" do
        dsl.property :test, :string, alias: :test_alias
        expect {
          dsl.resolv_aliases(test_alias: "foo", test: "bar")
        }.to raise_error PropertiesDSL::InvalidData, "only use 'test_alias' OR 'test'"
      end

      it "returns original data if no alias is defined" do
        dsl.property :test, :string, alias: :test_alias
        data = dsl.resolv_aliases(test: "foo")
        expect(data[:test]).to eq("foo")
      end

      it "returns original data if alias is defined, but not present" do
        dsl.property :test, :string
        data = dsl.resolv_aliases(test: "foo")
        expect(data[:test]).to eq("foo")
        expect(data).not_to have_key(:test_alias)
      end
    end

    describe ".find_property_for_xml_name" do
      it "finds property by xml_name" do
        dsl.property :test, :string, xml_name: :xml_test
        expect(dsl.find_property_for_xml_name("xml_test")).to eq(:test)
      end

      it "finds property by name" do
        dsl.property :test, :string, xml_name: :xml_test
        expect(dsl.find_property_for_xml_name("test")).to eq(:test)
      end

      it "returns nil if property is not defined" do
        dsl.property :test, :string, xml_name: :xml_test
        expect(dsl.find_property_for_xml_name("unknown")).to be_nil
      end
    end
  end
end
