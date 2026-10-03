class ServerSshChecksController < ApplicationController
  include ActionView::RecordIdentifier

  def create
    @server = Server.find(params[:server_id])
    @result = SshCheck.call(@server)
    @server.record_ssh_status!(@result.success?) unless @result.reason == :missing_key

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(dom_id(@server, :ssh_check), partial: "servers/ssh_check_result", locals: { result: @result, server: @server })
      end
      format.html do
        redirect_to server_path(@server), flash: { (@result.success? ? :notice : :alert) => "#{@result.message} — #{@result.details}" }
      end
    end
  end
end
