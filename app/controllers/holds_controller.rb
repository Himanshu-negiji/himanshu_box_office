class HoldsController < ApplicationController
  HOLD_TTL_SECONDS = 120

  # POST /holds
  def create
    event = Event.find(hold_params[:event_id])
    qty = hold_params[:qty].to_i

    raise ActiveRecord::RecordInvalid.new(event), "qty must be positive" if qty <= 0

    hold = nil
    Event.transaction do
      # Lock the event row to prevent oversubscription under concurrency
      event = Event.lock.find(event.id)

      snapshot = event.snapshot
      if snapshot[:available] < qty
        return render json: { error: "Not enough seats available" }, status: :unprocessable_entity
      end

      payment_token = SecureRandom.uuid
      hold = event.holds.create!(
        qty: qty,
        expires_at: HOLD_TTL_SECONDS.seconds.from_now,
        status: :active,
        payment_token: payment_token
      )
    end

    render json: { hold_id: hold.id, expires_at: hold.expires_at.iso8601, payment_token: hold.payment_token }, status: :created
  end

  private

  def hold_params
    params.require(:hold).permit(:event_id, :qty)
  end
end

