module DiasporaFederation
  describe Federation::Receiver::Private do
    let(:recipient) { 42 }
    let(:post) { Fabricate(:status_message_entity, public: false) }
    let(:magic_env) { Salmon::MagicEnvelope.new(post, post.author) }

    describe "#receive" do
      it "receives a private post" do
        expect_callback(:receive_entity, post, post.author, recipient)

        described_class.new(magic_env, recipient).receive
      end

      it "validates the sender" do
        sender = Fabricate.sequence(:diaspora_id)
        bad_env = Salmon::MagicEnvelope.new(post, sender)

        expect {
          described_class.new(bad_env, recipient).receive
        }.to raise_error Federation::Receiver::InvalidSender, "invalid sender: #{sender}"
      end

      it "validates the recipient" do
        expect {
          described_class.new(magic_env).receive
        }.to raise_error Federation::Receiver::RecipientRequired
      end

      context "with relayable" do
        let(:comment) { Fabricate(:comment_entity, parent: Fabricate(:related_entity, public: false)) }

        it "receives a comment from the author" do
          magic_env = Salmon::MagicEnvelope.new(comment, comment.author)

          expect_callback(:receive_entity, comment, comment.author, recipient)

          described_class.new(magic_env, recipient).receive
        end

        it "receives a comment from the parent author" do
          magic_env = Salmon::MagicEnvelope.new(comment, comment.parent.author)

          expect_callback(:receive_entity, comment, comment.parent.author, recipient)

          described_class.new(magic_env, recipient).receive
        end

        it "validates the sender" do
          sender = Fabricate.sequence(:diaspora_id)
          bad_env = Salmon::MagicEnvelope.new(comment, sender)

          expect {
            described_class.new(bad_env, recipient).receive
          }.to raise_error Federation::Receiver::InvalidSender, "invalid sender: #{sender}"
        end
      end

      context "with retraction" do
        context "for a post" do
          let(:retraction) { Fabricate(:retraction_entity, target_type: "Post") }

          it "retracts a post from the author" do
            magic_env = Salmon::MagicEnvelope.new(retraction, retraction.target.author)

            expect_callback(:receive_entity, retraction, retraction.author, recipient)

            described_class.new(magic_env, recipient).receive
          end

          it "validates the sender" do
            sender = Fabricate.sequence(:diaspora_id)
            bad_env = Salmon::MagicEnvelope.new(retraction, sender)

            expect {
              described_class.new(bad_env, recipient).receive
            }.to raise_error Federation::Receiver::InvalidSender, "invalid sender: #{sender}"
          end
        end

        context "for a comment" do
          let(:retraction) {
            Fabricate(
              :retraction_entity,
              target_type: "Comment",
              target:      Fabricate(:related_entity, parent: Fabricate(:related_entity))
            )
          }

          it "retracts a comment from the author" do
            magic_env = Salmon::MagicEnvelope.new(retraction, retraction.target.author)

            expect_callback(:receive_entity, retraction, retraction.target.author, recipient)

            described_class.new(magic_env, recipient).receive
          end

          it "retracts a comment from the parent author" do
            magic_env = Salmon::MagicEnvelope.new(retraction, retraction.target.parent.author)

            expect_callback(:receive_entity, retraction, retraction.target.parent.author, recipient)

            described_class.new(magic_env, recipient).receive
          end

          it "validates the sender" do
            sender = Fabricate.sequence(:diaspora_id)
            bad_env = Salmon::MagicEnvelope.new(retraction, sender)

            expect {
              described_class.new(bad_env, recipient).receive
            }.to raise_error Federation::Receiver::InvalidSender, "invalid sender: #{sender}"
          end
        end
      end
    end
  end
end
