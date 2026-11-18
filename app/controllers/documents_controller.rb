# frozen_string_literal: true

class DocumentsController < ApplicationController
  def index
    result = Documents::Paginator.new(
      scope: Document.for_tenant(current_tenant),
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
    idempotency_key = request.headers["Idempotency-Key"].presence

    if idempotency_key
      existing = Document.for_tenant(current_tenant).find_by(idempotency_key: idempotency_key)
      if existing
        return render json: { document: serialize(existing) }, status: :ok
      end
    end

    attrs = document_params
    file = attrs.delete(:file)

    doc = Document.for_tenant(current_tenant).new(attrs.except(:source_type))
    doc.file.attach(file) if file.present?
    doc.source_type = inferred_source_type(file, attrs[:source_type])
    doc.title = doc.title.presence || file&.original_filename
    doc.status = "pending"
    doc.idempotency_key = idempotency_key
    doc.save!
    IngestDocumentJob.perform_later(doc.id)
    render json: { document: serialize(doc) }, status: :accepted
  end

  def reindex
    doc = Document.for_tenant(current_tenant).find(params[:id])

    if doc.status == "processing"
      return render json: {
        error: "conflict",
        message: "Document is already processing"
      }, status: :conflict
    end

    doc.update!(status: "pending", error_message: nil)
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
    params.require(:document).permit(:title, :content, :source_type, :file)
  end

  def inferred_source_type(file, requested)
    if file.present?
      return "pdf" if Ingest::TextExtractor.pdf?(file.content_type, file.original_filename)
      return "html" if Ingest::TextExtractor.html?(file.content_type, file.original_filename)
    end

    requested.presence || "text"
  end

  def serialize(doc)
    {
      id: doc.id,
      title: doc.title,
      source_type: doc.source_type,
      status: doc.status,
      error_message: doc.error_message,
      idempotency_key: doc.idempotency_key,
      filename: doc.file.attached? ? doc.file.filename.to_s : nil,
      created_at: doc.created_at,
      updated_at: doc.updated_at
    }
  end
end
