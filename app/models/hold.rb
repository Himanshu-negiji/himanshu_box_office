class Hold < ApplicationRecord
  belongs_to :event

  enum status: { active: "active", expired: "expired", booked: "booked" }

  validates :qty, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :payment_token, presence: true, uniqueness: true
  validates :expires_at, presence: true

  scope :active_nonexpired, -> { where(status: :active).where("expires_at > ?", Time.current) }
end
