class PublicKeysController < ApplicationController
  require_permission :operate, only: %i[new create edit update destroy]

  before_action :set_public_key, only: %i[show edit update destroy]

  # Optional filter: ?kind=person|server.
  def index
    @kind = params[:kind].presence_in(PublicKey::KINDS.keys)
    @public_keys = PublicKey.order(:name)
    @public_keys = @public_keys.of_kind(@kind) if @kind
  end

  def show
  end

  # Can be prefilled (e.g. from an unknown key of a server) with `content`,
  # `name`, `kind` and a local `return_to` path.
  def new
    @public_key = PublicKey.new(name: params[:name], content: params[:content], kind: params[:kind].presence_in(PublicKey::KINDS.keys) || "person")
    @return_to = safe_return_to
  end

  def create
    @public_key = PublicKey.new(public_key_params)

    @return_to = safe_return_to

    if @public_key.save
      Activity.record!(:public_key_created, public_key: @public_key, fingerprint: @public_key.fingerprint)
      redirect_to @return_to || public_key_path(@public_key), notice: "La clé « #{@public_key.name} » a été ajoutée au trousseau."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @public_key.update(public_key_params)
      redirect_to public_key_path(@public_key), notice: "La clé « #{@public_key.name} » a été modifiée."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @public_key.destroy!
    Activity.record!(:public_key_deleted, public_key_name: @public_key.name, fingerprint: @public_key.fingerprint)
    redirect_to public_keys_path, notice: "La clé « #{@public_key.name} » a été retirée du trousseau.", status: :see_other
  end

  private

  # Only local paths, to avoid redirecting to another site.
  def safe_return_to
    path = params[:return_to].to_s
    path if path.start_with?("/") && !path.start_with?("//") && !path.include?("\\")
  end

  def set_public_key
    @public_key = PublicKey.find(params[:id])
  end

  def public_key_params
    params.expect(public_key: [ :name, :kind, :content, :description ])
  end
end
