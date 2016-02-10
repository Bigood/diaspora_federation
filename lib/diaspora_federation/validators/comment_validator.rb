module DiasporaFederation
  module Validators
    # This validates a {Entities::Comment}
    class CommentValidator < Validation::Validator
      include Validation

      include RelayableValidator

      rule :text, [:not_empty,
                   length: {maximum: 65_535}]
    end
  end
end
