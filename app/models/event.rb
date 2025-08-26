class Event < ApplicationRecord
  has_many :holds, dependent: :destroy
  has_many :bookings, dependent: :destroy

  validates :name, presence: true
  validates :total_seats, presence: true, numericality: { only_integer: true, greater_than: 0 }

  # Returns a hash with total, available, held, booked counts
  def snapshot
    active_holds_qty = holds.where(status: "active").where("expires_at > ?", Time.current).sum(:qty)
    booked_qty = bookings.sum(:qty)
    available_qty = [total_seats - active_holds_qty - booked_qty, 0].max

    { total: total_seats, available: available_qty, held: active_holds_qty, booked: booked_qty }
  end
end
