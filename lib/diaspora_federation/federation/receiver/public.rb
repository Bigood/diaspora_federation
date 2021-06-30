# frozen_string_literal: true

module DiasporaFederation
  module Federation
    module Receiver
      # Receiver for public entities
      class Public < AbstractReceiver
        private

        def validate
          super
          validate_public_flag
        end

        def validate_public_flag
          return if !entity.respond_to?(:public) || entity.public

          if entity.is_a?(Entities::Profile) &&
            %i[bio birthday gender location carto_id carto_latitude carto_longitude carto_etablissement carto_user_type carto_technics carto_activites carto_methods].all? {|prop| entity.public_send(prop).nil? }
            return
          end

          raise NotPublic, "received entity #{entity} should be public!"
        end
      end
    end
  end
end
