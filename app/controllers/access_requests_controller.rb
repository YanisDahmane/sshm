# Access requests: anyone with a profile asks for temporary access; operators
# and admins (never the requester) approve or deny pending requests.
class AccessRequestsController < ApplicationController
  require_permission :operate, only: %i[approve deny]

  before_action :expire_stale_requests
  before_action :set_request, only: %i[approve deny cancel]

  def index
    @mine = current_user.access_requests.includes(:server, :decided_by).recent.limit(20)
    return unless can?(:operate)

    @pending = AccessRequest.pending.includes(:server, :requester, :profile).order(:created_at)
    @history = AccessRequest.where.not(status: "pending").includes(:server, :requester, :decided_by).recent.limit(20)
  end

  def new
    @request = AccessRequest.new(server_id: params[:server_id], duration_minutes: 60)
  end

  def create
    @request = AccessRequest.new(request_params.merge(requester: current_user))

    if @request.save
      Activity.record!(:access_requested, server: @request.server, profile: @request.profile, unix_user: @request.unix_user,
                                          requester: current_user.email, duration_label: @request.duration_label, reason: @request.reason)
      redirect_to access_requests_path, notice: "Demande envoyée. Un opérateur ou un administrateur doit l'accepter dans les #{AccessRequest::PENDING_FOR.in_hours.to_i} heures."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def approve
    return redirect_to(access_requests_path, alert: "Vous ne pouvez pas décider de cette demande.", status: :see_other) unless @request.decidable_by?(current_user)
    return redirect_to(access_requests_path, alert: "Le profil de cette demande a été supprimé : refusez-la.", status: :see_other) unless @request.profile

    result = BulkAccess.grant([ @request.profile ], [ @request.server ], account: @request.unix_user, duration: @request.duration).sole
    if result.error?
      redirect_to access_requests_path, alert: "Impossible d'accorder l'accès : #{result.message}. La demande reste en attente.", status: :see_other
    else
      @request.approve!(current_user)
      record(:access_request_approved)
      redirect_to access_requests_path, notice: "Accès accordé à #{@request.requester.email} sur « #{@request.server.name} » pendant #{@request.duration_label}.", status: :see_other
    end
  end

  def deny
    return redirect_to(access_requests_path, alert: "Vous ne pouvez pas décider de cette demande.", status: :see_other) unless @request.decidable_by?(current_user)

    @request.deny!(current_user, params[:decision_note].to_s.first(500))
    record(:access_request_denied, note: @request.decision_note)
    redirect_to access_requests_path, notice: "Demande de #{@request.requester.email} refusée.", status: :see_other
  end

  def cancel
    return redirect_to(access_requests_path, alert: "Vous ne pouvez pas annuler cette demande.", status: :see_other) unless @request.pending? && @request.requester == current_user

    @request.cancel!
    redirect_to access_requests_path, notice: "Demande annulée.", status: :see_other
  end

  private

  def expire_stale_requests = AccessRequest.expire_stale!

  def set_request
    @request = AccessRequest.find(params[:id])
  end

  def request_params
    params.expect(access_request: [ :server_id, :unix_user, :duration_minutes, :reason ])
  end

  def record(kind, **data)
    Activity.record!(kind, server: @request.server, profile: @request.profile, unix_user: @request.unix_user,
                           requester: @request.requester.email, duration_label: @request.duration_label, **data)
  end
end
