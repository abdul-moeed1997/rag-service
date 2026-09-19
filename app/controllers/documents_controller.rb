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
    doc = Document.for_tenant(current_tenant).new(document_params)
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
    params.require(:document).permit(:title, :content, :source_type)
  end

  def serialize(doc)
    {
      id: doc.id,
      title: doc.title,
      source_type: doc.source_type,
      status: doc.status,
      error_message: doc.error_message,
      created_at: doc.created_at,
      updated_at: doc.updated_at
    }
  end
end
