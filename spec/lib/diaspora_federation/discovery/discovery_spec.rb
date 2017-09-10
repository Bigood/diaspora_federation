module DiasporaFederation
  describe Discovery::Discovery do
    let(:host_meta_xrd) { Discovery::HostMeta.from_base_url("http://localhost:3000/").to_xml }
    let(:webfinger_data) {
      {
        acct_uri:      "acct:#{alice.diaspora_id}",
        alias_url:     alice.alias_url,
        hcard_url:     alice.hcard_url,
        seed_url:      alice.url,
        profile_url:   alice.profile_url,
        atom_url:      alice.atom_url,
        salmon_url:    alice.salmon_url,
        subscribe_url: alice.subscribe_url,
        guid:          alice.guid,
        public_key:    alice.serialized_public_key
      }
    }
    let(:webfinger_xrd) {
      DiasporaFederation::Discovery::WebFinger.new(webfinger_data).to_xml
    }
    let(:webfinger_jrd) {
      JSON.pretty_generate(DiasporaFederation::Discovery::WebFinger.new(webfinger_data).to_json)
    }
    let(:hcard_html) {
      DiasporaFederation::Discovery::HCard.new(
        guid:             alice.guid,
        nickname:         alice.nickname,
        full_name:        alice.full_name,
        url:              alice.url,
        photo_large_url:  alice.photo_default_url,
        photo_medium_url: alice.photo_default_url,
        photo_small_url:  alice.photo_default_url,
        public_key:       alice.serialized_public_key,
        searchable:       alice.searchable,
        first_name:       alice.first_name,
        last_name:        alice.last_name
      ).to_html
    }
    let(:account) { alice.diaspora_id }
    let(:default_image) { "http://localhost:3000/assets/user/default.png" }
    subject { Discovery::Discovery.new(account) }

    describe "#intialize" do
      it "sets diaspora* ID" do
        discovery = Discovery::Discovery.new("some_user@example.com")
        expect(discovery.diaspora_id).to eq("some_user@example.com")
      end

      it "downcases account and strips whitespace, and sub 'acct:'" do
        discovery = Discovery::Discovery.new("acct:BIGBOY@Example.Com ")
        expect(discovery.diaspora_id).to eq("bigboy@example.com")
      end
    end

    describe ".fetch_and_save" do
      it "fetches the userdata and returns a person object" do
        stub_request(:get, "https://localhost:3000/.well-known/webfinger?resource=acct:#{account}")
          .to_return(status: 200, body: webfinger_jrd)
        stub_request(:get, "http://localhost:3000/hcard/users/#{alice.guid}")
          .to_return(status: 200, body: hcard_html)

        expect_callback(:save_person_after_webfinger, kind_of(Entities::Person))
        person = subject.fetch_and_save

        expect(person.guid).to eq(alice.guid)
        expect(person.diaspora_id).to eq(account)
        expect(person.url).to eq(alice.url)
        expect(person.exported_key).to eq(alice.serialized_public_key)

        profile = person.profile

        expect(profile.diaspora_id).to eq(alice.diaspora_id)
        expect(profile.first_name).to eq("Dummy")
        expect(profile.last_name).to eq("User")

        expect(profile.image_url).to eq(default_image)
        expect(profile.image_url_medium).to eq(default_image)
        expect(profile.image_url_small).to eq(default_image)
      end

      it "fetches the userdata and saves the person object via callback" do
        stub_request(:get, "https://localhost:3000/.well-known/webfinger?resource=acct:#{account}")
          .to_return(status: 200, body: webfinger_jrd)
        stub_request(:get, "http://localhost:3000/hcard/users/#{alice.guid}")
          .to_return(status: 200, body: hcard_html)

        callback_person = nil
        expect(DiasporaFederation.callbacks).to receive(:trigger) do |callback, person|
          expect(callback).to eq(:save_person_after_webfinger)
          expect(person).to be_instance_of(Entities::Person)
          callback_person = person
        end

        expect(subject.fetch_and_save).to be(callback_person)
      end

      it "fails if the diaspora* ID does not match" do
        modified_webfinger = webfinger_jrd.gsub(account, "anonther_user@example.com")

        stub_request(:get, "https://localhost:3000/.well-known/webfinger?resource=acct:#{account}")
          .to_return(status: 200, body: modified_webfinger)

        expect { subject.fetch_and_save }.to raise_error Discovery::DiscoveryError
      end

      it "fails if the diaspora* ID was not found" do
        stub_request(:get, "https://localhost:3000/.well-known/webfinger?resource=acct:#{account}")
          .to_return(status: 404)
        stub_request(:get, "http://localhost:3000/.well-known/webfinger?resource=acct:#{account}")
          .to_return(status: 404)
        stub_request(:get, "https://localhost:3000/.well-known/host-meta")
          .to_return(status: 200, body: host_meta_xrd)
        stub_request(:get, "http://localhost:3000/.well-known/webfinger.xml?resource=acct:#{account}")
          .to_return(status: 404)

        expect { subject.fetch_and_save }.to raise_error Discovery::DiscoveryError
      end

      context "http fallback" do
        context "http fallback disabled (default)" do
          it "falls back to legacy WebFinger if https fails with 404" do
            stub_request(:get, "https://localhost:3000/.well-known/webfinger?resource=acct:#{account}")
              .to_return(status: 404)
            stub_request(:get, "https://localhost:3000/.well-known/host-meta")
              .to_return(status: 200, body: host_meta_xrd)
            stub_request(:get, "http://localhost:3000/.well-known/webfinger.xml?resource=acct:#{account}")
              .to_return(status: 200, body: webfinger_xrd)
            stub_request(:get, "http://localhost:3000/hcard/users/#{alice.guid}")
              .to_return(status: 200, body: hcard_html)

            expect_callback(:save_person_after_webfinger, kind_of(Entities::Person))
            person = subject.fetch_and_save

            expect(person.guid).to eq(alice.guid)
            expect(person.diaspora_id).to eq(account)
          end

          it "falls back to legacy WebFinger if https fails with ssl error" do
            stub_request(:get, "https://localhost:3000/.well-known/webfinger?resource=acct:#{account}")
              .to_raise(OpenSSL::SSL::SSLError)
            stub_request(:get, "https://localhost:3000/.well-known/host-meta")
              .to_raise(OpenSSL::SSL::SSLError)
            stub_request(:get, "http://localhost:3000/.well-known/host-meta")
              .to_return(status: 200, body: host_meta_xrd)
            stub_request(:get, "http://localhost:3000/.well-known/webfinger.xml?resource=acct:#{account}")
              .to_return(status: 200, body: webfinger_xrd)
            stub_request(:get, "http://localhost:3000/hcard/users/#{alice.guid}")
              .to_return(status: 200, body: hcard_html)

            expect_callback(:save_person_after_webfinger, kind_of(Entities::Person))
            person = subject.fetch_and_save

            expect(person.guid).to eq(alice.guid)
            expect(person.diaspora_id).to eq(account)
          end
        end

        context "http fallback enabled" do
          before :all do
            DiasporaFederation.webfinger_http_fallback = true
          end

          after :all do
            DiasporaFederation.webfinger_http_fallback = false
          end

          it "falls back to http if https fails with 404" do
            stub_request(:get, "https://localhost:3000/.well-known/webfinger?resource=acct:#{account}")
              .to_return(status: 404)
            stub_request(:get, "http://localhost:3000/.well-known/webfinger?resource=acct:#{account}")
              .to_return(status: 200, body: webfinger_jrd)
            stub_request(:get, "http://localhost:3000/hcard/users/#{alice.guid}")
              .to_return(status: 200, body: hcard_html)

            expect_callback(:save_person_after_webfinger, kind_of(Entities::Person))
            person = subject.fetch_and_save

            expect(person.guid).to eq(alice.guid)
            expect(person.diaspora_id).to eq(account)
          end

          it "falls back to http if https fails with ssl error" do
            stub_request(:get, "https://localhost:3000/.well-known/webfinger?resource=acct:#{account}")
              .to_raise(OpenSSL::SSL::SSLError)
            stub_request(:get, "http://localhost:3000/.well-known/webfinger?resource=acct:#{account}")
              .to_return(status: 200, body: webfinger_jrd)
            stub_request(:get, "http://localhost:3000/hcard/users/#{alice.guid}")
              .to_return(status: 200, body: hcard_html)

            expect_callback(:save_person_after_webfinger, kind_of(Entities::Person))
            person = subject.fetch_and_save

            expect(person.guid).to eq(alice.guid)
            expect(person.diaspora_id).to eq(account)
          end
        end
      end

      context "legacy WebFinger" do
        it "falls back to legacy WebFinger" do
          incomplete_webfinger_json = "{\"links\":[{\"rel\":\"http://openid.net/specs/connect/1.0/issuer\"," \
                                      "\"href\":\"https://localhost:3000/\"}],\"subject\":\"acct:#{account}\"}"
          stub_request(:get, "https://localhost:3000/.well-known/webfinger?resource=acct:#{account}")
            .to_return(status: 200, body: incomplete_webfinger_json)
          stub_request(:get, "https://localhost:3000/.well-known/host-meta")
            .to_return(status: 200, body: host_meta_xrd)
          stub_request(:get, "http://localhost:3000/.well-known/webfinger.xml?resource=acct:#{account}")
            .to_return(status: 200, body: webfinger_xrd)
          stub_request(:get, "http://localhost:3000/hcard/users/#{alice.guid}")
            .to_return(status: 200, body: hcard_html)

          expect_callback(:save_person_after_webfinger, kind_of(Entities::Person))
          person = subject.fetch_and_save

          expect(person.guid).to eq(alice.guid)
          expect(person.diaspora_id).to eq(account)
          expect(person.url).to eq(alice.url)
          expect(person.exported_key).to eq(alice.serialized_public_key)

          profile = person.profile

          expect(profile.diaspora_id).to eq(alice.diaspora_id)
          expect(profile.first_name).to eq("Dummy")
          expect(profile.last_name).to eq("User")

          expect(profile.image_url).to eq(default_image)
          expect(profile.image_url_medium).to eq(default_image)
          expect(profile.image_url_small).to eq(default_image)
        end

        it "falls back to http if https fails with 404" do
          stub_request(:get, "https://localhost:3000/.well-known/webfinger?resource=acct:#{account}")
            .to_return(status: 404)
          stub_request(:get, "https://localhost:3000/.well-known/host-meta")
            .to_return(status: 404)
          stub_request(:get, "http://localhost:3000/.well-known/host-meta")
            .to_return(status: 200, body: host_meta_xrd)
          stub_request(:get, "http://localhost:3000/.well-known/webfinger.xml?resource=acct:#{account}")
            .to_return(status: 200, body: webfinger_xrd)
          stub_request(:get, "http://localhost:3000/hcard/users/#{alice.guid}")
            .to_return(status: 200, body: hcard_html)

          expect_callback(:save_person_after_webfinger, kind_of(Entities::Person))
          person = subject.fetch_and_save

          expect(person.guid).to eq(alice.guid)
          expect(person.diaspora_id).to eq(account)
        end

        it "falls back to http if https fails with ssl error" do
          stub_request(:get, "https://localhost:3000/.well-known/webfinger?resource=acct:#{account}")
            .to_raise(OpenSSL::SSL::SSLError)
          stub_request(:get, "https://localhost:3000/.well-known/host-meta")
            .to_raise(OpenSSL::SSL::SSLError)
          stub_request(:get, "http://localhost:3000/.well-known/host-meta")
            .to_return(status: 200, body: host_meta_xrd)
          stub_request(:get, "http://localhost:3000/.well-known/webfinger.xml?resource=acct:#{account}")
            .to_return(status: 200, body: webfinger_xrd)
          stub_request(:get, "http://localhost:3000/hcard/users/#{alice.guid}")
            .to_return(status: 200, body: hcard_html)

          expect_callback(:save_person_after_webfinger, kind_of(Entities::Person))
          person = subject.fetch_and_save

          expect(person.guid).to eq(alice.guid)
          expect(person.diaspora_id).to eq(account)
        end

        it "fails if the diaspora* ID does not match" do
          modified_webfinger = webfinger_xrd.gsub(account, "anonther_user@example.com")

          stub_request(:get, "https://localhost:3000/.well-known/webfinger?resource=acct:#{account}")
            .to_return(status: 200, body: "foobar")
          stub_request(:get, "https://localhost:3000/.well-known/host-meta")
            .to_return(status: 200, body: host_meta_xrd)
          stub_request(:get, "http://localhost:3000/.well-known/webfinger.xml?resource=acct:#{account}")
            .to_return(status: 200, body: modified_webfinger)

          expect { subject.fetch_and_save }.to raise_error Discovery::DiscoveryError
        end
      end

      context "error handling" do
        it "re-raises DiscoveryError" do
          expect(subject).to receive(:validate_diaspora_id)
            .and_raise(Discovery::DiscoveryError, "Something went wrong!")

          expect { subject.fetch_and_save }.to raise_error Discovery::DiscoveryError, "Something went wrong!"
        end

        it "re-raises InvalidDocument" do
          expect(subject).to receive(:validate_diaspora_id)
            .and_raise(Discovery::InvalidDocument, "Wrong document!")

          expect { subject.fetch_and_save }.to raise_error Discovery::InvalidDocument, "Wrong document!"
        end

        it "re-raises InvalidData" do
          expect(subject).to receive(:validate_diaspora_id)
            .and_raise(Discovery::InvalidData, "Wrong data!")

          expect { subject.fetch_and_save }.to raise_error Discovery::InvalidData, "Wrong data!"
        end

        it "raises a DiscoveryError when an unhandled error occurs" do
          expect(subject).to receive(:validate_diaspora_id)
            .and_raise("OMG! EVERYTHING IS BROKEN!")

          expect {
            subject.fetch_and_save
          }.to raise_error Discovery::DiscoveryError,
                           "Failed discovery for #{account}: RuntimeError: OMG! EVERYTHING IS BROKEN!"
        end
      end
    end
  end
end
