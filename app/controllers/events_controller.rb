class EventsController < ApplicationController
  # POST /events
  def create
    event = Event.create!(event_params)
    render json: { event_id: event.id, total_seats: event.total_seats, created_at: event.created_at }, status: :created
  end

  # GET /events/:id
  def show
    event = Event.find(params[:id])
    render json: event.snapshot
  end

  private

  def event_params
    params.require(:event).permit(:name, :total_seats)
  end
end

