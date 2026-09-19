# frozen_string_literal: true

class DocumentsController < ApplicationController
  def index
    docs = Document.for_tenant(current_tenant).order(created_at: :desc)
    render json: { documents: docs.map { |d| serialize(d) } }
  end

  def show
    doc = Document.for_tenant(current_tenant).find(params[:id])
    render json: { document: serialize(doc) }
  end

  def create
    attrs = document_params
    file = attrs.delete(:file)

    doc = Document.for_tenant(current_tenant).new(attrs.except(:source_type))
    doc.file.attach(file) if file.present?
    doc.source_type = inferred_source_type(file, attrs[:source_type])
    doc.title = doc.title.presence || file&.original_filename
    doc.status = "pending"
    doc.save!
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
    return "pdf" if file.present? && Ingest::TextExtractor.pdf?(file.content_type, file.original_filename)

    requested.presence || "text"
  end

  def serialize(doc)
    {
      id: doc.id,
      title: doc.title,
      source_type: doc.source_type,
      status: doc.status,
      error_message: doc.error_message,
      filename: doc.file.attached? ? doc.file.filename.to_s : nil,
      created_at: doc.created_at,
      updated_at: doc.updated_at
    }
  end
end
