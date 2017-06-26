module Amorail
  # AmoCRM unsorted entity
  class Unsorted < Amorail::Entity
    amo_names 'unsorted'

    amo_field :source, :source_uid, :source_data, :data

    validates :source, :source_uid, :source_data, :data,
              presence: true

    attr_accessor :category

  end
end
