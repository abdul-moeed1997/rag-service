# frozen_string_literal: true

class DocumentsController < ApplicationController
  def index
    scope = Document.for_tenant(current_tenant)
    scope = scope.in_namespace(params[:namespace]) if params[:namespace].present?

    result = Documents::Paginator.new(
      scope: scope,
      after: params[:after],
      limit: params[:limit]
    ).call

    render json: {
      documents: result[:records].map { |doc| serialize(doc) },
      pagination: result[:pagination]
    }
  rescue ArgumentError => e
    render json: { error: "invalid", message: e.message }, status: :unprocessable_entity
  end

  def show
    doc = Document.for_tenant(current_tenant).find(params[:id])
    render json: { document: serialize(doc) }
  end

  def create
    attrs = document_params
    result = Documents::Submit.call(
      tenant: current_tenant,
      attributes: attrs.except(:file),
      file: attrs[:file],
      idempotency_key: request.headers["Idempotency-Key"]
    )

    render json: { document: serialize(result.document) }, status: result.replayed? ? :ok : :accepted
  end

  def reindex
    doc = Document.for_tenant(current_tenant).find(params[:id])

    unless doc.request_reindex!
      return render json: {
        error: "conflict",
        message: "Document is already processing"
      }, status: :conflict
    end

    IngestDocumentJob.perform_later(doc.id)
    render json: { document: serialize(doc) }, status: :accepted
  end

  def destroy
    doc = Document.for_tenant(current_tenant).find(params[:id])
    doc.destroy!
    head :no_content
  end

  private

  def document_params
    params.require(:document).permit(:title, :content, :source_type, :namespace, :file)
  end

  def serialize(doc)
    {
      id: doc.id,
      title: doc.title,
      source_type: doc.source_type,
      namespace: doc.namespace,
      status: doc.status,
      error_message: doc.error_message,
      idempotency_key: doc.idempotency_key,
      filename: doc.file.attached? ? doc.file.filename.to_s : nil,
      created_at: doc.created_at,
      updated_at: doc.updated_at
    }
  end
end
