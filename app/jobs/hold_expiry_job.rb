class HoldExpiryJob < ApplicationJob
  queue_as :default

  # Scans for expired holds and marks them expired
  def perform
    Hold.where(status: :active).where("expires_at <= ?", Time.current).find_each do |hold|
      # Mark expired if not already booked
      hold.update!(status: :expired) unless Booking.exists?(hold_id: hold.id)
    end
  end
end

