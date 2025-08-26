class Booking < ApplicationRecord
  belongs_to :event
  belongs_to :hold

  validates :qty, presence: true, numericality: { only_integer: true, greater_than: 0 }
end
