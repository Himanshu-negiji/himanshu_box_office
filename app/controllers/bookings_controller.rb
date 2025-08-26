class BookingsController < ApplicationController
  # POST /book
  def create
    hold_id = booking_params[:hold_id]
    payment_token = booking_params[:payment_token]

    booking = nil
    Hold.transaction do
      hold = Hold.lock.find(hold_id)

      if hold.payment_token != payment_token
        return render json: { error: "Invalid payment token" }, status: :unprocessable_entity
      end

      # Idempotency: if a booking already exists for this hold, return it
      existing = Booking.find_by(hold_id: hold.id)
      if existing
        return render json: { booking_id: existing.id }, status: :ok
      end

      # Validate hold is active and not expired
      if hold.status != "active" || hold.expires_at <= Time.current
        return render json: { error: "Hold is not active or has expired" }, status: :unprocessable_entity
      end

      # Lock event to serialize concurrent bookings for the same event
      event = Event.lock.find(hold.event_id)

      booking = Booking.create!(event_id: event.id, hold_id: hold.id, qty: hold.qty)
      hold.update!(status: :booked)
    end

    render json: { booking_id: booking.id }, status: :created
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Hold not found" }, status: :not_found
  rescue ActiveRecord::RecordNotUnique
    # Idempotency safety: return the existing booking for this hold
    if (existing = Booking.find_by(hold_id: booking_params[:hold_id]))
      render json: { booking_id: existing.id }, status: :ok
    else
      render json: { error: "Duplicate booking attempt" }, status: :conflict
    end
  end

  private

  def booking_params
    params.require(:booking).permit(:hold_id, :payment_token)
  end
end

